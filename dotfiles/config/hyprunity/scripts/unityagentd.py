#!/usr/bin/env python3
"""UnityAgent daemon.

Bridges two FIFOs to the Quickshell window:

  /tmp/unityagent_ipc.fifo        daemon -> UI   (one JSON object per line)
  /tmp/unityagent_user_input.fifo UI -> daemon  (one JSON object per line)

Requests
  {"type": "chat", "id", "provider", "kind", "baseUrl", "apiKey", "model",
   "temperature", "systemPrompt", "messages": [{"role", "content"}]}
  {"type": "agent", ...same fields...}    tool-calling loop (the UI path)
  {"type": "approve", "callId", "approved"}
  {"type": "input-result", "callId", "value", "cancelled"}
  {"type": "run",  "id", "command"}
  {"type": "stop", "id"}
  {"type": "ping"}

Responses
  {"type": "ready"}
  {"type": "done", "id", "text"}
  {"type": "error", "id", "message"}
  {"type": "approval", "id", "callId", "name", "args"}
  {"type": "input", "id", "callId", "name", "args", "prompt", "secret"}
  {"type": "tool", "id", "callId", "name", "args", "pending"?}
  {"type": "tool", "id", "callId", "name", "args", "output", "ok", "denied"?}
  {"type": "run-result", "id", "command", "title", "output", "exitCode", "error"}
  {"type": "proposal", "title", "message", "code"}      (legacy path)

The agent loop calls the provider with native tools. Read-only tools run at
once; create_project/write_file/edit_file/run_command send an `approval` event
and block until the UI answers with `approve` (or the request is stopped).
Coding projects live under ~/Projects/UnityAgent; run_command takes an optional
`cwd` (a project name or absolute path) so builds and tests run there.

Settings > UnityAgent policy arrives in each `agent` request as `enabled` and
`features`. Disabled tools are removed from the model's tool list and refused
if the model asks anyway; package commands are refused when package management
is off.

Commands run on a pseudo-terminal, so sudo and other interactive programs can
prompt. When a command waits for input the daemon sends an `input` event and
blocks until the UI answers with `input-result`. Input values never enter the
captured output, the chat history, or the model's context: echo is disabled on
the pty and every value is scrubbed from the output before it is sent.

The UI feeds a run-result back to the model as a "[tool result]" user turn so the
assistant can explain the output in plain language or propose the next action.

Anything that is not JSON is treated as the old plain-text protocol, so an
older UI build keeps working.

The input FIFO is read with blocking I/O: the reader waits in open() until a
writer connects and then waits in read() for its bytes, so an idle daemon uses
no CPU. The UI writes each request with a short-lived `printf > fifo` writer,
which closes the pipe right after the write, so every message is followed by
EOF; the reader closes and reopens then, after a short sleep, and keeps
running. API work happens on threads, so the reader never blocks on HTTP.
"""

import base64
import fcntl
import fnmatch
import hashlib
import html as html_module
import json
import os
import pty
import re
import select
import shlex
import signal
import struct
import subprocess
import sys
import termios
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

IPC_IN = "/tmp/unityagent_ipc.fifo"
IPC_OUT = "/tmp/unityagent_user_input.fifo"

REVIEW_COMMANDS = {"sudo", "pacman", "yay", "paru", "systemctl", "rm", "mkfs", "dd", "mount", "umount"}

_send_lock = threading.Lock()
_cancelled = set()
_cancel_lock = threading.Lock()

MAX_OUTPUT = 4000
MAX_TOOL_OUTPUT = 12000
MAX_READ_BYTES = 200000
MAX_AGENT_STEPS = 24
APPROVAL_TIMEOUT = 600
INPUT_TIMEOUT = 600
# How long the pty has to stay quiet before its tail is treated as a prompt.
PROMPT_QUIET = 0.45
# Live terminal output: how often a running command pushes a snapshot to the
# UI, and how much of it to send (the card tails the last lines).
STREAM_INTERVAL = 0.15
STREAM_MAX_CHARS = 12000
MAX_IMAGE_DIM = 1600
MAX_IMAGE_BYTES = 8 * 1024 * 1024


def screenshot_dir():
    base = os.environ.get("XDG_CACHE_HOME") or os.path.join(os.path.expanduser("~"), ".cache")
    return os.path.join(base, "hyprunity", "unityagent", "screenshots")


# Coding projects the agent creates live here. Relative `cwd` values passed to
# run_command resolve against this root, so `cwd: "my-app"` means
# ~/Projects/UnityAgent/my-app.
PROJECT_ROOT = os.path.expanduser("~/Projects/UnityAgent")
_PROJECT_NAME_RX = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$")


def project_path(name):
    """Return the absolute directory for a project name, validating the name."""
    raw = (name or "").strip()
    if not raw:
        raise ValueError("a project name is required")
    if raw in (".", "..") or raw.startswith(".") or "/" in raw or "\\" in raw:
        raise ValueError(
            "invalid project name `%s`: use letters, digits, dots, dashes and "
            "underscores" % raw
        )
    if not _PROJECT_NAME_RX.fullmatch(raw):
        raise ValueError(
            "invalid project name `%s`: use letters, digits, dots, dashes and "
            "underscores (max 64 characters)" % raw
        )
    return os.path.join(PROJECT_ROOT, raw)


def resolve_cwd(cwd):
    """Resolve run_command's optional working directory.

    Relative paths (including a bare project name) are relative to
    ~/Projects/UnityAgent. Absolute paths are accepted so the agent can work in
    an existing repository too. The directory must already exist.
    """
    raw = (cwd or "").strip()
    if not raw:
        return None
    path = os.path.expanduser(raw)
    relative = not os.path.isabs(path)
    if relative:
        path = os.path.join(PROJECT_ROOT, path)
    path = os.path.realpath(path)
    root = os.path.realpath(PROJECT_ROOT)
    if relative and os.path.commonpath([path, root]) != root:
        raise ValueError(
            "relative cwd must stay inside %s; use an absolute path for anything "
            "else" % PROJECT_ROOT
        )
    if not os.path.isdir(path):
        raise ValueError("working directory does not exist: %s" % path)
    return path

# Tools that change the machine. The daemon asks the UI before running one and
# waits for the user; read-only tools run immediately.
APPROVAL_TOOLS = {"run_command", "write_file", "edit_file", "create_project"}

_approvals = {}
_approval_lock = threading.Lock()

# Interactive prompts (sudo passwords, "continue? [y/N]", ...). Keyed by call id
# so the UI can answer the exact command that is waiting.
_inputs = {}
_input_lock = threading.Lock()

# The tool call currently running on this thread. exec_command() reads it to
# know which request/call id an input prompt belongs to.
_tool_ctx = threading.local()


# ───────────────────────────── plumbing ─────────────────────────────


def ensure_fifos():
    import stat

    for path in (IPC_IN, IPC_OUT):
        try:
            if stat.S_ISFIFO(os.stat(path).st_mode):
                continue
            os.unlink(path)
        except FileNotFoundError:
            pass
        except OSError:
            pass
        try:
            os.mkfifo(path, 0o600)
        except FileExistsError:
            pass
        except OSError:
            pass


def send(obj):
    """Push one JSON line to the UI. Never blocks."""
    if not isinstance(obj, dict):
        obj = {"type": "done", "text": str(obj)}
    payload = (json.dumps(obj, ensure_ascii=False) + "\n").encode()
    with _send_lock:
        try:
            fd = os.open(IPC_IN, os.O_WRONLY | os.O_NONBLOCK)
        except OSError:
            return False
        try:
            # os.write() may take only part of the payload on a pipe; keep
            # pushing the remainder while the reader drains it.
            view = memoryview(payload)
            while view:
                try:
                    written = os.write(fd, view)
                except BlockingIOError:
                    # Pipe buffer is full: wait for the reader to drain it.
                    if not select.select([], [fd], [], 1.0)[1]:
                        return False
                    continue
                if written <= 0:
                    return False
                view = view[written:]
            return True
        except OSError:
            return False
        finally:
            os.close(fd)


def is_cancelled(request_id):
    with _cancel_lock:
        return request_id in _cancelled


def mark_cancelled(request_id):
    with _cancel_lock:
        _cancelled.add(request_id)


def clear_cancelled(request_id):
    with _cancel_lock:
        _cancelled.discard(request_id)


# ───────────────────────────── HTTP ─────────────────────────────

# Rate limits and short outages are worth a quiet retry; anything longer than
# this would block the request past the UI's watchdog, so fail with advice.
MAX_HTTP_RETRIES = 2
RETRY_MAX_WAIT = 20.0


def _json_object(body):
    try:
        parsed = json.loads(body)
    except Exception:
        return {}
    return parsed if isinstance(parsed, dict) else {}


def _error_text(body, parsed):
    err = parsed.get("error") if isinstance(parsed, dict) else None
    if isinstance(err, dict):
        return str(err.get("message") or "")
    if isinstance(err, str):
        return err
    return ""


def _retry_delay(headers, parsed):
    """Seconds the provider asked us to wait, or None."""
    value = ""
    try:
        value = headers.get("Retry-After") or headers.get("retry-after") or ""
    except Exception:  # noqa: BLE001
        value = ""
    value = str(value).strip()
    if value:
        try:
            return max(0.0, float(value))
        except ValueError:
            pass
    # Google puts the wait in error.details[].retryDelay ("31s").
    err = parsed.get("error") if isinstance(parsed, dict) else None
    if isinstance(err, dict):
        for detail in err.get("details") or []:
            if not isinstance(detail, dict):
                continue
            delay = detail.get("retryDelay")
            if isinstance(delay, str) and delay.endswith("s"):
                try:
                    return max(0.0, float(delay[:-1]))
                except ValueError:
                    continue
    return None


def _http_error_message(code, body, parsed, wait=None):
    text = _error_text(body, parsed).strip()
    extra = ("\n\n" + text[:300]) if text else ""
    if code == 429:
        if wait is None:
            wait = _retry_delay(None, parsed)
        if wait:
            return (
                "Rate limit reached (HTTP 429). Retry in about %ds, or switch "
                "model/provider in Settings.%s"
                % (max(1, int(round(wait))), extra)
            )
        return (
            "Rate limit reached (HTTP 429). Wait a moment and try again, or "
            "switch model/provider in Settings.%s" % extra
        )
    if code == 503:
        return (
            "The provider is temporarily unavailable (HTTP 503). Try again in "
            "a moment, or switch model/provider in Settings.%s" % extra
        )
    return "HTTP %s: %s" % (code, (text or body.strip())[:600] or str(code))


def http_json(url, headers, payload, timeout=150):
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers=headers,
        method="POST",
    )
    attempt = 0
    while True:
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                return json.loads(resp.read().decode("utf-8", "replace"))
        except urllib.error.HTTPError as exc:
            body = ""
            try:
                body = exc.read().decode("utf-8", "replace")
            except Exception:  # noqa: BLE001
                pass
            parsed = _json_object(body)
            wait = _retry_delay(exc.headers, parsed)
            if exc.code in (429, 503) and attempt < MAX_HTTP_RETRIES:
                delay = wait if wait is not None else (2.0 * (2 ** attempt))
                if delay <= RETRY_MAX_WAIT:
                    attempt += 1
                    time.sleep(delay)
                    continue
            raise RuntimeError(_http_error_message(exc.code, body, parsed, wait))
        except urllib.error.URLError as exc:
            raise RuntimeError("Cannot reach %s — %s" % (url, exc.reason))
        except TimeoutError:
            raise RuntimeError("The provider timed out.")


def openai_url(base):
    base = (base or "https://api.openai.com/v1").rstrip("/")
    if base.endswith("/chat/completions"):
        return base
    return base + "/chat/completions"


def anthropic_url(base):
    base = (base or "https://api.anthropic.com/v1").rstrip("/")
    if base.endswith("/messages"):
        return base
    return base + "/messages"


def openai_chat(req):
    base = req.get("baseUrl") or ""
    model = req.get("model") or ""
    key = req.get("apiKey") or ""
    messages = []
    system = req.get("systemPrompt") or ""
    if system:
        messages.append({"role": "system", "content": system})
    messages.extend(req.get("messages") or [])

    payload = {"model": model, "messages": messages}
    temp = req.get("temperature")
    # The o-series rejects temperature and system messages in some versions;
    # leaving it out is the compatible choice for those ids.
    if temp is not None and not model.startswith(("o1", "o3", "o4")):
        payload["temperature"] = max(0.0, min(2.0, float(temp)))

    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "User-Agent": "hyprunity-unityagent/1.0",
    }
    if key:
        headers["Authorization"] = "Bearer " + key
    # OpenRouter likes these but they are harmless elsewhere.
    headers["HTTP-Referer"] = "https://github.com/hyprunity"
    headers["X-Title"] = "UnityAgent"

    data = http_json(openai_url(base), headers, payload)
    choices = data.get("choices") or []
    if not choices:
        raise RuntimeError("The provider returned no choices.")
    content = (choices[0].get("message") or {}).get("content")
    if isinstance(content, list):
        content = "".join(part.get("text", "") for part in content if isinstance(part, dict))
    if not content:
        content = choices[0].get("text") or ""
    if not content:
        raise RuntimeError("The provider returned an empty message.")
    return content


def anthropic_chat(req):
    base = req.get("baseUrl") or ""
    model = req.get("model") or ""
    key = req.get("apiKey") or ""
    messages = [m for m in (req.get("messages") or []) if m.get("role") in ("user", "assistant")]
    payload = {
        "model": model,
        "max_tokens": 4096,
        "messages": messages,
    }
    system = req.get("systemPrompt") or ""
    if system:
        payload["system"] = system
    temp = req.get("temperature")
    if temp is not None:
        payload["temperature"] = max(0.0, min(1.0, float(temp)))

    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "anthropic-version": "2023-06-01",
        "User-Agent": "hyprunity-unityagent/1.0",
    }
    if key:
        headers["x-api-key"] = key

    data = http_json(anthropic_url(base), headers, payload)
    blocks = data.get("content") or []
    text = "".join(b.get("text", "") for b in blocks if isinstance(b, dict) and b.get("type") == "text")
    if not text:
        raise RuntimeError("The provider returned an empty message.")
    return text


def handle_chat(req):
    request_id = req.get("id") or ""
    try:
        if req.get("kind") == "anthropic":
            text = anthropic_chat(req)
        else:
            text = openai_chat(req)
        if is_cancelled(request_id):
            return
        send({"type": "done", "id": request_id, "text": text})
    except Exception as exc:  # noqa: BLE001
        if is_cancelled(request_id):
            return
        send({"type": "error", "id": request_id, "message": str(exc)})
    finally:
        clear_cancelled(request_id)


# ───────────────────────────── commands ─────────────────────────────


def run_command(request_id, command):
    # The legacy `run` request has no tool call id; give it one so an
    # interactive prompt can be matched back to the card in the UI.
    _tool_ctx.request_id = request_id
    _tool_ctx.call_id = (request_id or "run") + ":run"
    result = exec_command(command, 300)
    send({
        "type": "run-result",
        "id": request_id,
        "command": command,
        "title": "Done" if result["ok"] else "Failed",
        "output": result["output"],
        "exitCode": result["exitCode"],
        "error": not result["ok"],
    })


def handle_run(req):
    command = (req.get("command") or "").strip()
    if not command:
        send({"type": "error", "id": req.get("id") or "", "message": "Empty command."})
        return
    run_command(req.get("id") or "", command)


# ───────────────────────────── tools ─────────────────────────────
#
# The agent calls these natively. Read-only tools run as soon as the model asks;
# the three in APPROVAL_TOOLS are held until the UI answers an approval card.

TOOL_SPECS = [
    {
        "name": "read_file",
        "description": "Read a text file from disk. Returns the file's contents. Use start_line/end_line for large files instead of reading everything.",
        "parameters": {
            "type": "object",
            "properties": {
                "path": {"type": "string", "description": "Absolute path, or ~/relative to the home directory."},
                "start_line": {"type": "integer", "description": "First line to return (1-based). Optional."},
                "end_line": {"type": "integer", "description": "Last line to return (inclusive). Optional."},
            },
            "required": ["path"],
        },
    },
    {
        "name": "list_dir",
        "description": "List the entries of a directory. Directories end in /; files show their size.",
        "parameters": {
            "type": "object",
            "properties": {
                "path": {"type": "string", "description": "Directory to list. Defaults to the home directory."},
            },
            "required": [],
        },
    },
    {
        "name": "search_files",
        "description": "Search file contents under a directory with a regular expression. Skips .git, node_modules and cache directories.",
        "parameters": {
            "type": "object",
            "properties": {
                "pattern": {"type": "string", "description": "Regular expression to look for."},
                "path": {"type": "string", "description": "Directory to search. Defaults to the home directory."},
                "glob": {"type": "string", "description": "Only search files matching this glob, e.g. *.qml or *.lua."},
            },
            "required": ["pattern"],
        },
    },
    {
        "name": "fetch_url",
        "description": "Fetch a web page or text file over HTTP(S) and return it as readable text (HTML is stripped to plain text).",
        "parameters": {
            "type": "object",
            "properties": {
                "url": {"type": "string", "description": "Full http:// or https:// URL."},
            },
            "required": ["url"],
        },
    },
    {
        "name": "web_search",
        "description": "Search the web and return result titles, URLs and snippets. Use this when you need current information you cannot get from local files.",
        "parameters": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "Search query."},
            },
            "required": ["query"],
        },
    },
    {
        "name": "screenshot",
        "description": "Capture the screen and return it as an image you can see. Read-only and runs immediately. Captures the whole desktop by default; use `region` or `monitor` to narrow it. Use this when the user asks what is on screen or when a visual check helps.",
        "parameters": {
            "type": "object",
            "properties": {
                "region": {"type": "string", "description": "Optional grim geometry, e.g. `100,100 800x600`."},
                "monitor": {"type": "string", "description": "Optional output name, e.g. eDP-1."},
                "cursor": {"type": "boolean", "description": "Include the mouse cursor. Defaults to false."},
            },
            "required": [],
        },
    },
    {
        "name": "create_project",
        "description": "Create a coding project directory under ~/Projects/UnityAgent/<name> and return its path. All coding projects you make must live there. Call this first, then add files with write_file and build/test with run_command using that path as `cwd`. This needs the user's approval.",
        "parameters": {
            "type": "object",
            "properties": {
                "name": {"type": "string", "description": "Project folder name, e.g. `tic-tac-toe`. Letters, digits, dots, dashes and underscores only; no slashes."},
            },
            "required": ["name"],
        },
    },
    {
        "name": "write_file",
        "description": "Create or overwrite a file with the given content. Parent directories are created. This needs the user's approval.",
        "parameters": {
            "type": "object",
            "properties": {
                "path": {"type": "string", "description": "File to write."},
                "content": {"type": "string", "description": "Full new contents of the file."},
            },
            "required": ["path", "content"],
        },
    },
    {
        "name": "edit_file",
        "description": "Replace one exact string in an existing file. old_string must occur exactly once. This needs the user's approval.",
        "parameters": {
            "type": "object",
            "properties": {
                "path": {"type": "string", "description": "File to edit."},
                "old_string": {"type": "string", "description": "Exact text to replace, including indentation."},
                "new_string": {"type": "string", "description": "Replacement text."},
            },
            "required": ["path", "old_string", "new_string"],
        },
    },
    {
        "name": "run_command",
        "description": "Run a shell command and return its combined stdout/stderr and exit code. This needs the user's approval. Desktop actions go through `qs ipc -c hyprunity call ...`. Hyprland actions use the Lua dispatchers, e.g. `hyprctl dispatch 'hl.dsp.focus({workspace = 3})'`; legacy words like `workspace 3` fail on Hyprland 0.57. To install packages, prefer the official repos: `sudo pacman -S --needed <pkg>`. Only if the package is not in the repos and is available on the AUR, use `yay -S --needed <pkg>`. For coding projects, pass `cwd` (a project name like `my-app` resolves under ~/Projects/UnityAgent) and run the project's real build/test command there.",
        "parameters": {
            "type": "object",
            "properties": {
                "command": {"type": "string", "description": "Shell command to run."},
                "cwd": {"type": "string", "description": "Working directory. A relative value (e.g. `my-app`) is resolved under ~/Projects/UnityAgent; an absolute path is used as-is. Defaults to the daemon's directory."},
                "timeout": {"type": "integer", "description": "Seconds before giving up. Defaults to 300."},
            },
            "required": ["command"],
        },
    },
]


# Which Settings > UnityAgent switch owns each tool. A missing feature key
# means "always available" (the read-only tools). The UI sends this map with
# every agent request; the daemon removes disabled tools from the model's tool
# list *and* refuses them if the model asks anyway.
FEATURE_TOOLS = {
    "create_project": "projects",
    "run_command": "commands",
    "write_file": "files",
    "edit_file": "files",
    "fetch_url": "web",
    "web_search": "web",
    "screenshot": "screenshots",
}

FEATURE_LABELS = {
    "projects": "coding projects",
    "commands": "running shell commands",
    "files": "writing or editing files",
    "packages": "package management",
    "web": "web access",
    "screenshots": "screen capture",
}


def tool_enabled(name, features):
    feature = FEATURE_TOOLS.get(name)
    if not feature:
        return True
    return (features or {}).get(feature, True) is not False


def enabled_tools(features):
    return [t for t in TOOL_SPECS if tool_enabled(t["name"], features)]


def openai_tools(features=None):
    return [
        {
            "type": "function",
            "function": {
                "name": t["name"],
                "description": t["description"],
                "parameters": t["parameters"],
            },
        }
        for t in enabled_tools(features)
    ]


def anthropic_tools(features=None):
    return [
        {
            "name": t["name"],
            "description": t["description"],
            "input_schema": t["parameters"],
        }
        for t in enabled_tools(features)
    ]


_PACKAGE_MANAGERS = {
    "pacman", "yay", "paru", "pikaur", "trizen", "pamac",
    "flatpak", "snap", "apt", "apt-get", "dnf", "zypper", "nix-env",
}
_PACKAGE_WRAPPERS = {"sudo", "doas", "env", "nohup", "time", "command", "exec", "xargs"}
_SHELLS = {"sh", "bash", "zsh", "dash", "fish", "ksh"}
_PACKAGE_SPLIT_RX = re.compile(r"(?:\|\||&&|[;|\n])")


def _skip_wrappers(words):
    """Index of the real command after env assignments, sudo, env, …"""
    i = 0
    while i < len(words):
        word = words[i]
        if re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", word):
            i += 1
            continue
        base = os.path.basename(word)
        if base not in _PACKAGE_WRAPPERS:
            break
        i += 1
        while i < len(words) and words[i].startswith("-"):
            flag = words[i]
            if flag == "--":
                i += 1
                break
            i += 1
            # These flags consume the next word (sudo -u user ...).
            if flag in ("-u", "-g", "-p", "-C", "-h", "-r", "-t", "-U"):
                i += 1
    return i


def _iter_commands(command, _depth=0):
    """Yield (executable, args) for each command in a shell string.

    Env assignments and wrappers (`sudo`, `doas`, `env`, `nohup`, `xargs`, …)
    are stripped, and `sh -c '…'` is followed into the inner command. Yields
    nothing for a segment with no command.
    """
    if _depth > 4:
        return
    for part in _PACKAGE_SPLIT_RX.split(command or ""):
        try:
            words = shlex.split(part, comments=False, posix=True)
        except ValueError:
            words = part.split()
        i = _skip_wrappers(words)
        if i >= len(words):
            continue
        base = os.path.basename(words[i])
        if base in _SHELLS:
            # bash -lc 'pacman -S …' — the flag is a cluster like -lc or -ec.
            for j in range(i + 1, len(words)):
                flag = words[j]
                if flag.startswith("-") and not flag.startswith("--") and "c" in flag[1:]:
                    yield from _iter_commands(" ".join(words[j + 1:]), _depth + 1)
                    break
            continue
        yield base, words[i + 1:]


def package_manager_in(command):
    """Return a package manager used by a shell command, or "".

    `grep pacman file` is not a package operation; a real invocation is.
    """
    for base, _args in _iter_commands(command):
        if base in _PACKAGE_MANAGERS:
            return base
    return ""


# pacman-style operations that only read state. `-Si`, `-Ss`, `-Qu`, `-Ql`, …
_PACMAN_QUERY_MODS = set("isglp")


def _pacman_changes(args):
    """True for a pacman/yay/paru invocation that installs, removes or upgrades."""
    for arg in args:
        if arg == "--":
            break
        if arg.startswith("--"):
            if arg in ("--sync", "--remove", "--upgrade", "--database"):
                return True
            continue
        if not arg.startswith("-") or len(arg) < 2:
            continue
        op = arg[1]
        if op in ("R", "U"):
            return True
        if op == "S":
            mods = arg[2:]
            # `-S` installs; `-Sy`/`-Su`/`-Sc`/`-Sw` change state. Modifiers
            # like `-Si`, `-Ss`, `-Sg`, `-Sl` and `-Sp` only query.
            if not mods or any(ch not in _PACMAN_QUERY_MODS for ch in mods):
                return True
    return False


_PACKAGE_ACTIONS = {
    "flatpak": {"install", "uninstall", "update", "remove", "upgrade", "repair"},
    "snap": {"install", "remove", "refresh", "revert"},
    "apt": {"install", "remove", "purge", "upgrade", "dist-upgrade", "autoremove"},
    "apt-get": {"install", "remove", "purge", "upgrade", "dist-upgrade", "autoremove"},
    "dnf": {"install", "remove", "upgrade", "erase", "update", "downgrade"},
    "zypper": {"install", "remove", "update", "dup", "in", "rm", "patch"},
    "pamac": {"install", "remove", "update", "build", "reinstall", "upgrade"},
    "nix-env": {"-i", "--install", "-e", "--uninstall", "--upgrade"},
}


def package_change_in(command):
    """Return the package manager if the command would change packages.

    Read-only queries (`pacman -Qu`, `pacman -Si`, `flatpak list`, `apt list`)
    are allowed while package management is off; installs, removals and
    upgrades are not.
    """
    for base, args in _iter_commands(command):
        if base not in _PACKAGE_MANAGERS:
            continue
        if base in ("pacman", "yay", "paru", "pikaur", "trizen"):
            if _pacman_changes(args):
                return base
        elif any(arg in _PACKAGE_ACTIONS.get(base, ()) for arg in args):
            return base
    return ""


def _resolve(path, default="~"):
    raw = (path or default or "").strip()
    if not raw:
        raise ValueError("a path is required")
    return os.path.expanduser(raw)


def _clip(text):
    if len(text) > MAX_TOOL_OUTPUT:
        return text[:MAX_TOOL_OUTPUT] + "\n… (truncated)"
    return text


def exec_command(command, timeout=300, cwd=None):
    """Run a shell command on a pty and return {ok, output, exitCode}.

    A pty (rather than a plain pipe) lets sudo, ssh, pacman and friends show
    their prompts. Prompt text is forwarded to the UI, the answer is written
    back to the terminal, and the answer itself is scrubbed from the output so
    it can never reach the model or the chat history.
    """
    request_id = getattr(_tool_ctx, "request_id", "") or ""
    call_id = getattr(_tool_ctx, "call_id", "") or (
        "cmd" + str(int(time.time() * 1000))
    )
    return _run_pty(command, timeout, request_id, call_id, cwd)


_ANSI_RX = re.compile(
    r"\x1b\[[0-?]*[ -/]*[@-~]"
    r"|\x1b\][^\x07]*(?:\x07|\x1b\\)"
    r"|\x1b[@-_]"
)

# A prompt is only considered after the terminal has been quiet for a moment,
# so ordinary output that happens to end with a colon is not mistaken for one.
_PASSWORD_RX = re.compile(
    r"(?i)(?:^|\n)\s*(?:\[sudo\]\s*)?(?:enter\s+(?:the\s+)?)?"
    r"(?:password|passphrase|passcode|pin|verification\s+code)"
    r"(?:\s+for\s+[^:\n]+)?\s*[:?]\s*$"
)
_SECRET_RX = re.compile(
    r"(?i)(?:^|\n)\s*[^\n]{0,160}\b(?:"
    r"secret|token|api[\s_-]?key|access[\s_-]?key|private[\s_-]?key|"
    r"auth(?:entication)?\s+code|otp|2fa|verification\s+code|"
    r"recovery\s+code|credential|passphrase|password|passcode|pin"
    r")\b[^\n]{0,120}[:?]\s*$"
)
_CONFIRM_RX = re.compile(
    r"(?i)(?:^|\n)[^\n]{0,200}(?:"
    r"\[(?:y/n|yes/no)\]|\((?:yes/no|y/n)\)|"
    r"are you sure|do you want to continue|continue\?|proceed\?|overwrite\?"
    r")\s*[:?]?\s*$"
)
_GENERIC_RX = re.compile(
    r"(?i)(?:^|\n)\s*[^\n]{0,200}\b(?:"
    r"enter|input|type|choose|select|provide|specify|answer|confirm|continue|"
    r"proceed|name|username|user|email|url|code|number|amount|path|value|"
    r"token|key|password|passphrase|pin"
    r")\b[^\n]{0,120}[:?]\s*$"
)
_PRESS_RX = re.compile(
    r"(?i)(?:^|\n)[^\n]{0,160}(?:press\s+any\s+key|hit\s+any\s+key)[^\n]{0,40}$"
)
# A generic prompt is just a short line that ends like one. It is only trusted
# when the process is actually blocked reading the terminal.
_PROMPT_END_RX = re.compile(
    r"(?i)(?:^|\n)\s*[^\n]{0,200}(?:[:?]|[\]\)])\s*$"
)

_TTY_WAIT_CHANNELS = {
    "wait_woken",
    "n_tty_read",
    "tty_read",
    "do_select",
    "core_sys_select",
    "poll_schedule_timeout",
    "do_poll",
    "ep_poll",
    "do_epoll_wait",
}


def _strip_ansi(text):
    return _ANSI_RX.sub("", text)


def _echo_off(master):
    """True when the terminal is not echoing input (sudo, read -s, ...)."""
    try:
        attrs = termios.tcgetattr(master)
    except Exception:  # noqa: BLE001
        return False
    return not (attrs[3] & termios.ECHO)


def _tty_waiting(master, pid):
    """True when a process in the pty's foreground group is blocked on it.

    This is what separates a real prompt from ordinary output that happens to
    end with a colon while the command is busy doing something else.
    """
    try:
        pgrp = os.tcgetpgrp(master)
    except OSError:
        pgrp = pid
    try:
        entries = os.listdir("/proc")
    except OSError:
        return False
    for entry in entries:
        if not entry.isdigit():
            continue
        base = "/proc/" + entry
        try:
            with open(base + "/stat", "r") as f:
                stat = f.read()
            # The comm field can contain spaces and brackets, so split after
            # the last ')' instead of on whitespace.
            close = stat.rfind(")")
            if close < 0:
                continue
            rest = stat[close + 2:].split()
            if len(rest) < 3 or int(rest[2]) != pgrp:
                continue
            with open(base + "/wchan", "r") as f:
                wchan = f.read().strip()
            if not any(ch in wchan for ch in _TTY_WAIT_CHANNELS):
                continue
            fd_dir = base + "/fd"
            for fd in os.listdir(fd_dir):
                try:
                    target = os.readlink(os.path.join(fd_dir, fd))
                except OSError:
                    continue
                if target.startswith("/dev/pts/") or target == "/dev/tty":
                    return True
        except OSError:
            continue
    return False


def _scrub_private(text, private):
    """Remove every answer the user typed from the captured output.

    Long and secret values are removed wherever they appear; short answers
    (``y``, ``no``) are only removed when they are a whole line, so ordinary
    output is not mangled.
    """
    for value, secret in private:
        if not value:
            continue
        if secret or len(value) >= 3:
            text = text.replace(value, "[hidden]")
        else:
            text = re.sub(
                r"(?m)^" + re.escape(value) + r"[ \t]*$", "[hidden]", text
            )
    return text


def detect_prompt(text):
    """Return (prompt, secret, strong) when the tail is waiting for input.

    `strong` prompts are recognised by their wording and can be shown at once.
    Weak prompts (any short line ending in :, ? or a bracket) are only used
    after confirming the process is blocked on the terminal.
    """
    tail = _strip_ansi(text)[-800:]
    if not tail.strip():
        return None
    line = tail.rstrip("\r\n").split("\n")[-1].strip()
    if not line:
        return None
    if _PASSWORD_RX.search(tail) or _SECRET_RX.search(tail):
        return line, True, True
    if _CONFIRM_RX.search(tail):
        return line, False, True
    if _PRESS_RX.search(tail):
        return line, False, True
    if _GENERIC_RX.search(tail):
        return line, False, True
    if _PROMPT_END_RX.search(tail):
        return line, False, False
    return None


def _poll_child(pid):
    """Reap a child if it has exited: (done, exit_code)."""
    try:
        got, status = os.waitpid(pid, os.WNOHANG)
    except ChildProcessError:
        return True, None
    except OSError:
        return True, None
    if got == 0:
        return False, None
    try:
        return True, os.waitstatus_to_exitcode(status)
    except Exception:  # noqa: BLE001
        return True, None


def _wait_child(pid, timeout):
    deadline = time.time() + max(0.0, timeout)
    while time.time() < deadline:
        done, code = _poll_child(pid)
        if done:
            return True, code
        time.sleep(0.05)
    return False, None


def _kill_child(pid):
    for sig in (signal.SIGTERM, signal.SIGKILL):
        try:
            os.killpg(pid, sig)
        except OSError:
            try:
                os.kill(pid, sig)
            except OSError:
                pass
        if _wait_child(pid, 1.0)[0]:
            return


def _run_pty(command, timeout, request_id, call_id, cwd=None):
    timeout = max(1, int(timeout or 300))

    env = os.environ.copy()
    env.setdefault("TERM", "xterm-256color")
    # Keep pagers from swallowing the command behind an interactive view.
    for name in ("PAGER", "GIT_PAGER", "SYSTEMD_PAGER", "MANPAGER"):
        env[name] = "cat"
    env["LESS"] = "FRX"
    # A stale askpass helper would bypass the prompt we want to show.
    env.pop("SUDO_ASKPASS", None)

    try:
        pid, master = pty.fork()
    except OSError as exc:
        return {"ok": False, "output": "Failed to start: %s" % exc, "exitCode": None}

    if pid == 0:
        # Child: pty.fork() has already made the slave our stdin/stdout/stderr
        # and our controlling terminal, so sudo can prompt normally.
        try:
            if cwd:
                os.chdir(cwd)
            os.execvpe("/bin/sh", ["sh", "-c", command], env)
        except Exception:  # noqa: BLE001
            os._exit(127)

    # Do not echo typed answers back into the captured stream.
    # (The terminal's echo flag is checked per prompt below: sudo and read -s
    # turn it off themselves, which is how we know to mask the input.)

    text = ""
    private = []
    deadline = time.time() + timeout
    scan_from = 0
    last_data = time.time()
    timed_out = False
    cancelled = False
    done = False
    exit_code = None
    tty_waiting = False
    tty_checked_at = 0.0
    last_stream = 0.0
    stream_len = 0

    def stream(force=False):
        """Push the output so far to the UI while the command is still running."""
        nonlocal last_stream, stream_len
        if not force and len(text) == stream_len:
            return
        now = time.time()
        if not force and now - last_stream < STREAM_INTERVAL:
            return
        last_stream = now
        stream_len = len(text)
        # Only the tail can reach the card, so do not re-render megabytes.
        tail = text[-(STREAM_MAX_CHARS * 2):]
        body = _strip_ansi(tail).replace("\r\n", "\n").replace("\r", "\n")
        body = _scrub_private(body, private)
        if len(body) > STREAM_MAX_CHARS:
            body = "…\n" + body[-STREAM_MAX_CHARS:]
        send({
            "type": "tool-output",
            "id": request_id,
            "callId": call_id,
            "output": body,
        })

    try:
        while True:
            if is_cancelled(request_id):
                cancelled = True
                _kill_child(pid)
                done, exit_code = _poll_child(pid)
                break

            now = time.time()
            if now > deadline:
                timed_out = True
                _kill_child(pid)
                done, exit_code = _poll_child(pid)
                break

            try:
                ready, _, _ = select.select([master], [], [], 0.1)
            except (InterruptedError, OSError):
                ready = []

            if ready:
                try:
                    chunk = os.read(master, 4096)
                except OSError:
                    chunk = b""
                if chunk:
                    text += chunk.decode("utf-8", "replace")
                    last_data = time.time()
                    stream()
                    continue
                # EOF on the slave: the command closed the terminal.
                done, exit_code = _poll_child(pid)
                if not done:
                    done, exit_code = _wait_child(pid, 1.0)
                break

            done, exit_code = _poll_child(pid)
            if done:
                # Drain whatever is still buffered before the pty goes away.
                while True:
                    try:
                        ready, _, _ = select.select([master], [], [], 0)
                    except (InterruptedError, OSError):
                        break
                    if not ready:
                        break
                    try:
                        more = os.read(master, 4096)
                    except OSError:
                        break
                    if not more:
                        break
                    text += more.decode("utf-8", "replace")
                break

            quiet = time.time() - last_data
            if quiet < PROMPT_QUIET:
                continue

            # Flush the tail of the output before deciding whether the command
            # is waiting for input, so the user sees the prompt in context.
            stream()

            found = detect_prompt(text[scan_from:])
            if found and found[2]:
                prompt, secret, _ = found
            else:
                # Weak or missing prompt text: only trust it once the process
                # is genuinely blocked on the terminal. The check is cached so
                # an idle wait does not scan /proc ten times a second.
                if time.time() - tty_checked_at >= 0.5:
                    tty_waiting = _tty_waiting(master, pid)
                    tty_checked_at = time.time()
                if not tty_waiting:
                    continue
                if found:
                    prompt, secret, _ = found
                else:
                    prompt, secret = "The command is waiting for input.", False

            # sudo, read -s and anything else that turned echo off is asking
            # for something private even if its prompt text is not obvious.
            if _echo_off(master):
                secret = True

            stream(force=True)
            value, user_cancelled = await_input(
                request_id, call_id, prompt, secret, command
            )
            waited = time.time() - now
            if user_cancelled:
                cancelled = True
                try:
                    os.write(master, b"\x03")
                except OSError:
                    pass
                _kill_child(pid)
                done, exit_code = _poll_child(pid)
                break

            if value:
                private.append((value, secret))
            try:
                os.write(master, (value + "\n").encode("utf-8", "replace"))
            except OSError:
                pass
            scan_from = len(text)
            last_data = time.time()
            # Time spent waiting for the user does not count against the
            # command's own timeout.
            deadline += waited

        if not done:
            _kill_child(pid)
            done, exit_code = _poll_child(pid)
    finally:
        try:
            os.close(master)
        except OSError:
            pass

    body = _strip_ansi(text).replace("\r\n", "\n").replace("\r", "\n")
    body = _scrub_private(body, private).strip()
    if timed_out:
        note = "Timed out after %ss." % timeout
        body = note + ("\n" + body if body else "")
    elif cancelled:
        note = "Cancelled by the user."
        body = note + ("\n" + body if body else "")
    if len(body) > MAX_OUTPUT:
        body = body[:MAX_OUTPUT] + "\n…"
    ok = not timed_out and not cancelled and exit_code == 0
    return {
        "ok": ok,
        "output": body or "(no output)",
        "exitCode": exit_code,
    }


def tool_read_file(args):
    path = _resolve(args.get("path"))
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        data = f.read(MAX_READ_BYTES + 1)
    truncated = len(data) > MAX_READ_BYTES
    if truncated:
        data = data[:MAX_READ_BYTES]
    lines = data.splitlines()
    try:
        start = max(1, int(args.get("start_line") or 1))
        end = int(args.get("end_line") or len(lines))
    except (TypeError, ValueError):
        start, end = 1, len(lines)
    end = min(max(start, end), len(lines))
    body = "\n".join(lines[start - 1:end])
    note = ""
    if truncated:
        note = "\n… (file truncated at %d bytes)" % MAX_READ_BYTES
    if not body:
        body = "(empty file)"
    return True, _clip("File: %s (lines %d-%d of %d)\n%s%s" % (path, start, end, len(lines), body, note))


def tool_list_dir(args):
    path = _resolve(args.get("path"))
    rows = []
    with os.scandir(path) as it:
        entries = sorted(it, key=lambda e: (not e.is_dir(), e.name.lower()))
        for entry in entries[:400]:
            try:
                if entry.is_dir():
                    rows.append("d  %s/" % entry.name)
                else:
                    rows.append("-  %s  (%d B)" % (entry.name, entry.stat().st_size))
            except OSError:
                rows.append("?  %s" % entry.name)
    if not rows:
        return True, "%s is empty." % path
    more = "" if len(rows) < 400 else "\n… (more entries not shown)"
    return True, _clip("Directory: %s\n%s%s" % (path, "\n".join(rows), more))


SKIP_DIRS = {".git", "node_modules", "__pycache__", ".cache", ".local/share/Trash", ".npm", ".cargo/registry"}


def tool_search_files(args):
    pattern = args.get("pattern") or ""
    if not pattern:
        return False, "pattern is required"
    root = _resolve(args.get("path"), "~")
    glob = args.get("glob") or "*"
    try:
        rx = re.compile(pattern)
    except re.error as exc:
        return False, "Invalid regular expression: %s" % exc

    hits = []
    scanned = 0
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS and not d.startswith(".git")]
        for name in filenames:
            if not fnmatch.fnmatch(name, glob):
                continue
            full = os.path.join(dirpath, name)
            try:
                if os.path.getsize(full) > 2_000_000:
                    continue
                with open(full, "r", encoding="utf-8", errors="ignore") as f:
                    for lineno, line in enumerate(f, 1):
                        scanned += 1
                        if rx.search(line):
                            hits.append("%s:%d: %s" % (full, lineno, line.rstrip()[:240]))
                            if len(hits) >= 200:
                                break
            except (OSError, UnicodeError):
                continue
            if len(hits) >= 200:
                break
        if len(hits) >= 200:
            break

    if not hits:
        return True, "No matches for %r under %s (glob %s)." % (pattern, root, glob)
    return True, _clip("Matches for %r under %s:\n%s" % (pattern, root, "\n".join(hits)))


def _http_get(url, timeout=30):
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36",
            "Accept": "text/html,application/xhtml+xml,text/plain;q=0.9,*/*;q=0.8",
        },
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read(4_000_000), resp.headers.get("Content-Type", "")


def html_to_text(markup):
    text = re.sub(r"(?is)<(script|style|noscript|svg|template)[^>]*>.*?</\1>", " ", markup)
    text = re.sub(r"(?is)<!--.*?-->", " ", text)
    text = re.sub(r"(?i)<br\s*/?>", "\n", text)
    text = re.sub(r"(?i)</(p|div|li|tr|h[1-6]|section|article|header|footer|blockquote|pre)>", "\n", text)
    text = re.sub(r"(?s)<[^>]+>", " ", text)
    text = html_module.unescape(text)
    out = []
    blanks = 0
    for line in text.splitlines():
        line = re.sub(r"[ \t]+", " ", line).strip()
        if not line:
            blanks += 1
            if blanks > 1:
                continue
        else:
            blanks = 0
        out.append(line)
    return "\n".join(out).strip()


def tool_fetch_url(args):
    url = (args.get("url") or "").strip()
    if not url:
        return False, "url is required"
    if not re.match(r"^https?://", url):
        return False, "Only http:// and https:// URLs are supported."
    raw, ctype = _http_get(url, timeout=30)
    charset = "utf-8"
    m = re.search(r"charset=([\w-]+)", ctype or "", re.I)
    if m:
        charset = m.group(1)
    try:
        text = raw.decode(charset, "replace")
    except LookupError:
        text = raw.decode("utf-8", "replace")
    if "html" in (ctype or "").lower() or re.search(r"(?i)<(html|body|div|p)\b", text[:2000]):
        text = html_to_text(text)
    return True, _clip("Fetched %s\n\n%s" % (url, text or "(empty page)"))


def tool_web_search(args):
    query = (args.get("query") or "").strip()
    if not query:
        return False, "query is required"
    url = "https://html.duckduckgo.com/html/?q=" + urllib.parse.quote_plus(query)
    try:
        raw, _ = _http_get(url, timeout=25)
    except Exception as exc:  # noqa: BLE001
        return False, "Search failed: %s" % exc
    page = raw.decode("utf-8", "replace")

    snippets = re.findall(r'class="result__snippet"[^>]*>(.*?)</a>', page, re.S)
    results = []
    for i, m in enumerate(re.finditer(r'<a\b([^>]*class="result__a"[^>]*)>(.*?)</a>', page, re.S)):
        attrs, inner = m.group(1), m.group(2)
        hm = re.search(r'href="([^"]+)"', attrs)
        if not hm:
            continue
        href = html_module.unescape(hm.group(1))
        if href.startswith("//"):
            href = "https:" + href
        parsed = urllib.parse.urlparse(href)
        qs = urllib.parse.parse_qs(parsed.query)
        if "uddg" in qs:
            href = qs["uddg"][0]
        title = html_to_text(inner) or href
        snippet = ""
        if i < len(snippets):
            snippet = html_to_text(snippets[i])
        results.append("%d. %s\n   %s\n   %s" % (len(results) + 1, title, href, snippet))

    if not results:
        return True, "No results for %r (the search provider may be blocking requests)." % query
    return True, _clip("Search: %s\n\n%s" % (query, "\n\n".join(results[:8])))


def _png_size(path):
    try:
        with open(path, "rb") as f:
            head = f.read(24)
        if len(head) >= 24 and head[:8] == b"\x89PNG\r\n\x1a\n":
            return struct.unpack(">II", head[16:24])
    except OSError:
        pass
    return None


def _image_media(path):
    ext = os.path.splitext(path)[1].lower()
    if ext in (".jpg", ".jpeg"):
        return "image/jpeg"
    if ext == ".webp":
        return "image/webp"
    return "image/png"


def _cleanup_screenshots(folder):
    cutoff = time.time() - 7 * 24 * 3600
    try:
        with os.scandir(folder) as entries:
            for entry in entries:
                if not entry.name.startswith("shot-") or not entry.is_file():
                    continue
                try:
                    if entry.stat().st_mtime < cutoff:
                        os.remove(entry.path)
                except OSError:
                    pass
    except OSError:
        pass


def tool_screenshot(args):
    """Capture the screen with grim and return the image for the model."""
    region = (args.get("region") or "").strip()
    monitor = (args.get("monitor") or "").strip()
    cursor = args.get("cursor") is True
    if region and not re.fullmatch(r"\d+,\d+ \d+x\d+", region):
        return False, "region must look like `100,100 800x600`"
    if monitor and not re.fullmatch(r"[A-Za-z0-9._:-]+", monitor):
        return False, "monitor contains invalid characters"

    folder = screenshot_dir()
    try:
        os.makedirs(folder, mode=0o700, exist_ok=True)
        os.chmod(folder, 0o700)
    except OSError as exc:
        return False, "Cannot create the screenshot folder: %s" % exc

    path = os.path.join(folder, "shot-%d.png" % time.time_ns())
    cmd = ["grim", "-t", "png"]
    if cursor:
        cmd.append("-c")
    if region:
        cmd.extend(["-g", region])
    if monitor:
        cmd.extend(["-o", monitor])
    cmd.append(path)
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=20)
    except FileNotFoundError:
        return False, "grim is not installed"
    except subprocess.TimeoutExpired:
        return False, "grim timed out"
    except OSError as exc:
        return False, "grim failed: %s" % exc
    if proc.returncode != 0 or not os.path.isfile(path):
        detail = (proc.stderr or proc.stdout or "").strip()
        return False, "grim failed: %s" % (detail or "no output")

    try:
        os.chmod(path, 0o600)
    except OSError:
        pass

    # Keep the image small enough to send inline; grim can produce multi-MB
    # PNGs on HiDPI outputs.
    size = _png_size(path)
    if size and max(size) > MAX_IMAGE_DIM:
        try:
            subprocess.run(
                ["magick", path, "-resize", "%dx%d>" % (MAX_IMAGE_DIM, MAX_IMAGE_DIM),
                 "-strip", path],
                capture_output=True, text=True, timeout=30,
            )
        except (OSError, subprocess.TimeoutExpired):
            pass
        size = _png_size(path)

    try:
        with open(path, "rb") as f:
            data = f.read()
    except OSError as exc:
        return False, "Cannot read the screenshot: %s" % exc
    if len(data) > MAX_IMAGE_BYTES:
        return False, "screenshot is too large (%d bytes); capture a smaller region" % len(data)

    _cleanup_screenshots(folder)
    dims = "%dx%d" % size if size else "unknown size"
    target = "region %s" % region if region else ("monitor %s" % monitor if monitor else "whole screen")
    image = {
        "path": path,
        "media": _image_media(path),
        "data": base64.b64encode(data).decode("ascii"),
        "width": size[0] if size else None,
        "height": size[1] if size else None,
    }
    return True, "Screenshot captured (%s, %s): %s" % (target, dims, path), image


def tool_write_file(args):
    path = _resolve(args.get("path"))
    content = args.get("content")
    if content is None:
        return False, "content is required"
    if not isinstance(content, str):
        content = str(content)
    parent = os.path.dirname(path)
    if parent:
        os.makedirs(parent, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    return True, "Wrote %d bytes to %s" % (len(content.encode("utf-8")), path)


def tool_edit_file(args):
    path = _resolve(args.get("path"))
    old = args.get("old_string")
    new = args.get("new_string")
    if old is None or new is None:
        return False, "old_string and new_string are required"
    old = old if isinstance(old, str) else str(old)
    new = new if isinstance(new, str) else str(new)
    if not old:
        return False, "old_string must not be empty"
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        data = f.read()
    count = data.count(old)
    if count == 0:
        return False, "old_string was not found in %s. Read the file and copy the exact text." % path
    if count > 1:
        return False, "old_string occurs %d times in %s. Include more surrounding text so it is unique." % (count, path)
    line_no = data[:data.find(old)].count("\n") + 1
    data = data.replace(old, new, 1)
    with open(path, "w", encoding="utf-8") as f:
        f.write(data)
    # Show the model exactly what changed. Without this it has to remember the
    # whole file, and on a revert it can drift into undoing the same line twice.
    diff_lines = ["- " + line for line in old.splitlines()]
    diff_lines += ["+ " + line for line in new.splitlines()]
    diff = "\n".join(diff_lines[:40])
    if len(diff_lines) > 40:
        diff += "\n… (diff truncated)"
    return True, "Edited %s at line %d (1 replacement).\n%s" % (path, line_no, diff)


def tool_create_project(args):
    path = project_path(args.get("name"))
    existed = os.path.isdir(path)
    if existed:
        return True, "Project already exists: %s" % path
    if os.path.exists(path):
        return False, "%s exists but is not a directory." % path
    os.makedirs(path, exist_ok=True)
    return True, "Created project: %s" % path


def tool_run_command(args):
    command = (args.get("command") or "").strip()
    if not command:
        return False, "command is required"
    try:
        cwd = resolve_cwd(args.get("cwd"))
    except ValueError as exc:
        return False, str(exc)
    result = exec_command(command, args.get("timeout") or 300, cwd=cwd)
    body = result["output"]
    if cwd:
        body = "Working directory: %s\n%s" % (cwd, body)
    if result["exitCode"] is not None:
        body = "Exit code: %s\n%s" % (result["exitCode"], body)
    return result["ok"], body


def preflight_change(name, args):
    """Validate a write/edit before asking the user to approve it.

    Returns (ok, message, path, result_hash). A failure here is fed straight
    back to the model: an edit that cannot apply (stale old_string, duplicate
    match, no change) must not produce an approval card the user has to reject.
    """
    if name == "create_project":
        try:
            path = project_path(args.get("name"))
        except ValueError as exc:
            return False, str(exc), None, None
        if os.path.exists(path) and not os.path.isdir(path):
            return False, "%s exists but is not a directory." % path, path, None
        return True, "", path, None

    try:
        path = _resolve(args.get("path"))
    except Exception as exc:  # noqa: BLE001
        return False, str(exc), None, None

    if name == "write_file":
        content = args.get("content")
        if content is None:
            return False, "content is required", path, None
        if not isinstance(content, str):
            content = str(content)
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as f:
                current = f.read()
        except OSError:
            current = None
        if current == content:
            return False, "No change: %s already has exactly this content." % path, path, None
        return True, "", path, hashlib.sha256(content.encode("utf-8")).hexdigest()

    if name == "edit_file":
        old = args.get("old_string")
        new = args.get("new_string")
        if old is None or new is None:
            return False, "old_string and new_string are required", path, None
        old = old if isinstance(old, str) else str(old)
        new = new if isinstance(new, str) else str(new)
        if not old:
            return False, "old_string must not be empty", path, None
        if old == new:
            return False, "old_string and new_string are identical; nothing to change.", path, None
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as f:
                data = f.read()
        except OSError as exc:
            return False, "Cannot read %s: %s" % (path, exc), path, None
        count = data.count(old)
        if count == 0:
            return False, "old_string was not found in %s. Read the file and copy the exact text." % path, path, None
        if count > 1:
            return False, "old_string occurs %d times in %s. Include more surrounding text so it is unique." % (count, path), path, None
        return True, "", path, hashlib.sha256(data.replace(old, new, 1).encode("utf-8")).hexdigest()

    return True, "", None, None


# ───────────────── Hyprland 0.57 dispatcher guard ─────────────────
#
# Hyprland 0.57 parses `hyprctl dispatch` as a Lua expression. Legacy words
# (`workspace 3`, `killactive`, `exec kitty`, ...) now fail with a syntax error.
# The machine context tells the model to use `hl.dsp.*`, but a model can still
# forget. Rewrite the common legacy forms before the approval card, and refuse
# the rest instead of running a command that cannot work.

_LUA_DIRECTIONS = {
    "l": "left", "r": "right", "u": "up", "d": "down",
    "left": "left", "right": "right", "up": "up", "down": "down",
}


def _lua_str(value):
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def _lua_workspace(value):
    value = value.strip()
    if re.fullmatch(r"-?\d+", value):
        return value
    if re.fullmatch(r"e[+-]\d+", value):
        return _lua_str(value)
    if value.startswith(("special:", "name:")):
        return _lua_str(value)
    raise ValueError(
        "unsupported workspace `%s`; use a number, e+1/e-1, special:NAME or "
        "name:NAME" % value
    )


def _legacy_dispatch_to_lua(expr):
    """Map one legacy dispatcher expression to the Hyprland 0.57 Lua API."""
    try:
        parts = shlex.split(expr)
    except ValueError as exc:
        raise ValueError("could not parse the legacy dispatcher (%s)" % exc)
    if not parts:
        raise ValueError("Empty dispatch expression.")
    name, rest = parts[0], parts[1:]

    # `hyprctl dispatch workspace 3 && echo done` must not be read as workspace
    # "3 && echo done". Refuse anything that is really a compound shell command;
    # `exec` is the exception because its argument is itself a shell command.
    if name != "exec" and re.search(r"[;&|`]|\$\(", " ".join(rest)):
        raise ValueError(
            "the dispatch is part of a larger shell command; run the dispatch as "
            "its own command"
        )

    if name == "workspace":
        if not rest:
            raise ValueError("`workspace` needs a workspace argument.")
        return "hl.dsp.focus({workspace = %s})" % _lua_workspace(" ".join(rest))
    if name == "movetoworkspace":
        if not rest:
            raise ValueError("`movetoworkspace` needs a workspace argument.")
        return "hl.dsp.window.move({workspace = %s})" % _lua_workspace(" ".join(rest))
    if name in ("killactive", "closewindow"):
        return "hl.dsp.window.close()"
    if name == "fullscreen":
        arg = rest[0] if rest else "0"
        if arg == "0":
            return "hl.dsp.window.fullscreen()"
        if arg == "1":
            return 'hl.dsp.window.fullscreen({action = "toggle", mode = "maximized"})'
        raise ValueError("`fullscreen %s` is not a known legacy mode (use 0 or 1)." % arg)
    if name == "togglefloating":
        return 'hl.dsp.window.float({action = "toggle"})'
    if name == "pseudo":
        return "hl.dsp.window.pseudo()"
    if name in ("movewindow", "movefocus"):
        if not rest or rest[0] not in _LUA_DIRECTIONS:
            raise ValueError("`%s` needs a direction (l, r, u, d)." % name)
        direction = _LUA_DIRECTIONS[rest[0]]
        if name == "movewindow":
            return 'hl.dsp.window.move({direction = "%s"})' % direction
        return 'hl.dsp.focus({direction = "%s"})' % direction
    if name == "resizeactive":
        if len(rest) < 2 or not re.fullmatch(r"-?\d+", rest[0]) or not re.fullmatch(r"-?\d+", rest[1]):
            raise ValueError("`resizeactive` needs numeric x and y offsets.")
        return "hl.dsp.window.resize({x = %s, y = %s, relative = true})" % (rest[0], rest[1])
    if name == "exec":
        if not rest:
            raise ValueError("`exec` needs a command.")
        return "hl.dsp.exec_cmd(%s)" % _lua_str(" ".join(rest))
    if name == "togglespecialworkspace":
        special = rest[0] if rest else "special"
        return "hl.dsp.workspace.toggle_special(%s)" % _lua_str(special)
    if name == "togglesplit":
        return 'hl.dsp.layout("togglesplit")'
    if name == "global":
        if not rest:
            raise ValueError("`global` needs a name.")
        return "hl.dsp.global(%s)" % _lua_str(" ".join(rest))
    if name == "exit":
        return "hl.dsp.exit()"

    raise ValueError(
        "cannot map legacy dispatcher `%s` to the Hyprland 0.57 Lua API "
        "automatically" % name
    )


def normalize_hypr_dispatch(command):
    """Rewrite a legacy `hyprctl dispatch ...` command to the Lua form.

    Returns (command, note). The command is unchanged and note is empty when it
    is already Lua or not a Hyprland dispatch. Raises ValueError for a legacy
    dispatcher that cannot be mapped, so the caller refuses it before approval.
    """
    if "hyprctl" not in command:
        return command, ""

    match = re.match(
        r"^\s*(hyprctl(?:\s+(?:--instance\s+\S+|-\S+))*)\s+dispatch\s+(.+?)\s*$",
        command,
        re.S,
    )
    if not match:
        if re.search(
            r"\bhyprctl\s+(?:--instance\s+\S+\s+|-\S+\s+)*dispatch\b", command
        ):
            raise ValueError(
                "This shell command wraps a legacy `hyprctl dispatch` in a larger "
                "command. Run the dispatch as its own command with the Lua form, "
                "e.g. hyprctl dispatch 'hl.dsp.focus({workspace = 3})'."
            )
        return command, ""

    prefix, expr = match.group(1).strip(), match.group(2).strip()
    bare = expr
    if len(bare) >= 2 and bare[0] == bare[-1] and bare[0] in ("'", '"'):
        bare = bare[1:-1].strip()
    if bare.startswith(("hl.", "return ", "(")):
        return command, ""

    lua = _legacy_dispatch_to_lua(bare)
    return prefix + " dispatch " + shlex.quote(lua), "Rewrote legacy dispatcher to Lua: " + lua


TOOL_FUNCS = {
    "read_file": tool_read_file,
    "list_dir": tool_list_dir,
    "search_files": tool_search_files,
    "fetch_url": tool_fetch_url,
    "web_search": tool_web_search,
    "screenshot": tool_screenshot,
    "create_project": tool_create_project,
    "write_file": tool_write_file,
    "edit_file": tool_edit_file,
    "run_command": tool_run_command,
}


def run_tool(name, args):
    """Run a tool and return (ok, output, image).

    Most tools return a 2-tuple; screenshot adds an image dict that the agent
    loop attaches to the next model turn.
    """
    func = TOOL_FUNCS.get(name)
    if not func:
        return False, "Unknown tool: %s" % name, None
    if not isinstance(args, dict):
        args = {}
    try:
        result = func(args)
    except FileNotFoundError as exc:
        return False, "Not found: %s" % (exc.filename or exc), None
    except PermissionError as exc:
        return False, "Permission denied: %s" % (exc.filename or exc), None
    except IsADirectoryError:
        return False, "That path is a directory, not a file.", None
    except Exception as exc:  # noqa: BLE001
        return False, "%s: %s" % (type(exc).__name__, exc), None
    if isinstance(result, tuple) and len(result) == 3:
        return result
    if isinstance(result, tuple) and len(result) == 2:
        return result[0], result[1], None
    return False, "Tool returned an invalid result.", None


# ───────────────────────────── approvals ─────────────────────────────


def resolve_approval(call_id, approved):
    with _approval_lock:
        slot = _approvals.get(call_id)
    if not slot:
        return
    slot["approved"] = bool(approved)
    slot["event"].set()


def await_approval(request_id, call_id, name, args):
    """Ask the UI and block this request's thread until the user answers."""
    event = threading.Event()
    slot = {"event": event, "approved": False}
    with _approval_lock:
        _approvals[call_id] = slot
    send({
        "type": "approval",
        "id": request_id,
        "callId": call_id,
        "name": name,
        "args": args,
    })
    deadline = time.time() + APPROVAL_TIMEOUT
    while time.time() < deadline:
        if event.wait(0.25):
            break
        if is_cancelled(request_id):
            break
    with _approval_lock:
        _approvals.pop(call_id, None)
    return slot["approved"] and not is_cancelled(request_id)


# ───────────────────────────── interactive input ─────────────────────────────


def resolve_input(call_id, value, cancelled=False):
    with _input_lock:
        slot = _inputs.get(call_id)
    if not slot:
        return
    slot["value"] = value
    slot["cancelled"] = bool(cancelled)
    slot["event"].set()


def await_input(request_id, call_id, prompt, secret, command=""):
    """Ask the UI for the answer to a command's prompt.

    Returns (value, cancelled). The value is never logged and never included in
    the tool output; the caller scrubs it as a second line of defence.
    """
    event = threading.Event()
    slot = {"event": event, "value": "", "cancelled": False}
    with _input_lock:
        _inputs[call_id] = slot
    send({
        "type": "input",
        "id": request_id,
        "callId": call_id,
        "name": "run_command",
        "args": {"command": command},
        "prompt": prompt,
        "secret": bool(secret),
    })
    deadline = time.time() + INPUT_TIMEOUT
    while time.time() < deadline:
        if event.wait(0.25):
            break
        if is_cancelled(request_id):
            slot["cancelled"] = True
            break
    with _input_lock:
        _inputs.pop(call_id, None)
    if is_cancelled(request_id):
        return "", True
    if not event.is_set():
        return "", True
    return slot["value"], slot["cancelled"]


# ───────────────────────────── agent loop ─────────────────────────────


def openai_agent_turn(req, messages, system, features=None):
    base = req.get("baseUrl") or ""
    model = req.get("model") or ""
    key = req.get("apiKey") or ""
    wire = []
    if system:
        wire.append({"role": "system", "content": system})
    wire.extend(messages)

    payload = {
        "model": model,
        "messages": wire,
        "tools": openai_tools(features),
        "tool_choice": "auto",
    }
    temp = req.get("temperature")
    if temp is not None and not model.startswith(("o1", "o3", "o4")):
        payload["temperature"] = max(0.0, min(2.0, float(temp)))

    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "User-Agent": "hyprunity-unityagent/1.0",
    }
    if key:
        headers["Authorization"] = "Bearer " + key
    headers["HTTP-Referer"] = "https://github.com/hyprunity"
    headers["X-Title"] = "UnityAgent"

    data = http_json(openai_url(base), headers, payload)
    choices = data.get("choices") or []
    if not choices:
        raise RuntimeError("The provider returned no choices.")
    msg = choices[0].get("message") or {}
    content = msg.get("content")
    if isinstance(content, list):
        content = "".join(part.get("text", "") for part in content if isinstance(part, dict))
    text = content or choices[0].get("text") or ""
    calls = []
    for tc in msg.get("tool_calls") or []:
        fn = tc.get("function") or {}
        raw = fn.get("arguments") or "{}"
        try:
            args = json.loads(raw) if isinstance(raw, str) else raw
        except Exception:
            args = {}
        if not isinstance(args, dict):
            args = {}
        call = {
            "id": tc.get("id") or ("call_" + str(int(time.time() * 1000)) + str(len(calls))),
            "name": fn.get("name") or "",
            "args": args,
        }
        # Gemini 3 returns an opaque thought signature with every function call
        # and rejects the next turn if it is not sent back verbatim. Other
        # providers do not send extra_content, so this stays out of their wire
        # format.
        if tc.get("extra_content"):
            call["extra_content"] = tc["extra_content"]
        calls.append(call)
    return text, calls


def anthropic_agent_turn(req, messages, system, features=None):
    payload = {
        "model": req.get("model") or "",
        "max_tokens": 4096,
        "messages": messages,
        "tools": anthropic_tools(features),
    }
    if system:
        payload["system"] = system
    temp = req.get("temperature")
    if temp is not None:
        payload["temperature"] = max(0.0, min(1.0, float(temp)))

    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "anthropic-version": "2023-06-01",
        "User-Agent": "hyprunity-unityagent/1.0",
    }
    key = req.get("apiKey") or ""
    if key:
        headers["x-api-key"] = key

    data = http_json(anthropic_url(base), headers, payload)
    blocks = data.get("content") or []
    text = "".join(
        b.get("text", "") for b in blocks if isinstance(b, dict) and b.get("type") == "text"
    )
    calls = []
    for b in blocks:
        if not isinstance(b, dict) or b.get("type") != "tool_use":
            continue
        args = b.get("input")
        calls.append({
            "id": b.get("id") or ("call_" + str(int(time.time() * 1000)) + str(len(calls))),
            "name": b.get("name") or "",
            "args": args if isinstance(args, dict) else {},
        })
    return text, calls


def append_assistant(kind, messages, text, calls):
    if kind == "anthropic":
        blocks = []
        if text:
            blocks.append({"type": "text", "text": text})
        for call in calls:
            blocks.append({
                "type": "tool_use",
                "id": call["id"],
                "name": call["name"],
                "input": call["args"],
            })
        messages.append({"role": "assistant", "content": blocks})
    else:
        wire_calls = []
        for call in calls:
            entry = {
                "id": call["id"],
                "type": "function",
                "function": {
                    "name": call["name"],
                    "arguments": json.dumps(call["args"], ensure_ascii=False),
                },
            }
            if call.get("extra_content"):
                entry["extra_content"] = call["extra_content"]
            wire_calls.append(entry)
        messages.append({
            "role": "assistant",
            "content": text or None,
            "tool_calls": wire_calls,
        })


def append_tool_results(kind, messages, results):
    if kind == "anthropic":
        blocks = []
        for call, ok, output, image in results:
            content = [{"type": "text", "text": output}]
            if image:
                content.append({
                    "type": "image",
                    "source": {
                        "type": "base64",
                        "media_type": image["media"],
                        "data": image["data"],
                    },
                })
            blocks.append({
                "type": "tool_result",
                "tool_use_id": call["id"],
                "content": content,
                "is_error": not ok,
            })
        messages.append({"role": "user", "content": blocks})
    else:
        images = []
        for call, _ok, output, image in results:
            messages.append({
                "role": "tool",
                "tool_call_id": call["id"],
                "content": output,
            })
            if image:
                images.append(image)
        if images:
            # OpenAI-compatible providers take images on user messages. Keep
            # every tool message contiguous, then add the images in one user
            # turn: interleaving a user message between tool results is invalid.
            content = [{"type": "text", "text": "Screenshot from the tool call above:"}]
            for image in images:
                content.append({
                    "type": "image_url",
                    "image_url": {
                        "url": "data:%s;base64,%s" % (image["media"], image["data"]),
                    },
                })
            messages.append({"role": "user", "content": content})


# The provider call is not streamed, so the whole answer lands at once. Reveal
# it as `delta` events anyway: the bubble fills in smoothly and the neon frame
# switches from the "thinking" wave to the "responding" pulses while the text
# is arriving. Short and long answers both take roughly the same time.
STREAM_MIN_SECONDS = 1.2
STREAM_MAX_SECONDS = 2.8
STREAM_CHARS_PER_SECOND = 900.0


def send_text_stream(request_id, text):
    """Send `text` as a run of delta events, then let the caller send `done`.

    Returns False if the request was cancelled mid-reveal. A failed write means
    the UI is gone; the caller's `done` still carries the full text, so it is
    safe to continue.
    """
    text = text or ""
    if not text:
        return True
    steps = max(12, min(90, len(text) // 8))
    duration = min(
        STREAM_MAX_SECONDS,
        max(STREAM_MIN_SECONDS, len(text) / STREAM_CHARS_PER_SECOND),
    )
    delay = duration / steps
    size = max(1, -(-len(text) // steps))  # ceil division
    for start in range(0, len(text), size):
        if is_cancelled(request_id):
            return False
        if not send({"type": "delta", "id": request_id, "text": text[start:start + size]}):
            return True
        time.sleep(delay)
    return True


def handle_agent(req):
    request_id = req.get("id") or ""
    kind = "anthropic" if req.get("kind") == "anthropic" else "openai"
    system = req.get("systemPrompt") or ""
    messages = list(req.get("messages") or [])
    # Settings > UnityAgent policy. Missing keys default to on so an older UI
    # build keeps working.
    if req.get("enabled") is False:
        send({
            "type": "error",
            "id": request_id,
            "message": "UnityAgent is turned off in Settings > UnityAgent.",
        })
        return
    features = req.get("features")
    if not isinstance(features, dict):
        features = {}
    # Content hashes this request has already produced per file. If a later edit
    # would reproduce one, the model is undoing and redoing the same change;
    # refuse it before it reaches an approval card.
    seen_states = {}
    try:
        for _step in range(MAX_AGENT_STEPS):
            if is_cancelled(request_id):
                return
            if kind == "anthropic":
                text, calls = anthropic_agent_turn(req, messages, system, features)
            else:
                text, calls = openai_agent_turn(req, messages, system, features)

            if not calls:
                if is_cancelled(request_id):
                    return
                final_text = text or "(empty response)"
                if not send_text_stream(request_id, final_text):
                    return
                if is_cancelled(request_id):
                    return
                send({"type": "done", "id": request_id, "text": final_text})
                return

            append_assistant(kind, messages, text, calls)

            results = []
            for call in calls:
                if is_cancelled(request_id):
                    return
                name = call["name"]
                args = call["args"]
                dispatch_note = ""
                path = None
                new_hash = None

                if not tool_enabled(name, features):
                    feature = FEATURE_TOOLS.get(name, "")
                    label = FEATURE_LABELS.get(feature, feature or name)
                    reason = (
                        "Refused: %s is turned off in Settings > UnityAgent. "
                        "Tell the user to enable it there if they want this action."
                        % label
                    )
                    send({
                        "type": "tool",
                        "id": request_id,
                        "callId": call["id"],
                        "name": name,
                        "args": args,
                        "output": reason,
                        "ok": False,
                    })
                    results.append((call, False, reason, None))
                    continue

                if name in APPROVAL_TOOLS:
                    if name == "run_command":
                        if features.get("packages", True) is False:
                            pm = package_change_in(args.get("command") or "")
                            if pm:
                                reason = (
                                    "Refused: package management is turned off in "
                                    "Settings > UnityAgent, so `%s` may not install, "
                                    "remove or upgrade packages. Read-only queries and "
                                    "other commands still work." % pm
                                )
                                send({
                                    "type": "tool",
                                    "id": request_id,
                                    "callId": call["id"],
                                    "name": name,
                                    "args": args,
                                    "output": reason,
                                    "ok": False,
                                })
                                results.append((call, False, reason, None))
                                continue
                        try:
                            new_command, dispatch_note = normalize_hypr_dispatch(
                                args.get("command") or ""
                            )
                        except ValueError as exc:
                            reason = "Refused: %s. Use the Lua dispatcher form, e.g. " \
                                     "hyprctl dispatch 'hl.dsp.focus({workspace = 3})'." % exc
                            send({
                                "type": "tool",
                                "id": request_id,
                                "callId": call["id"],
                                "name": name,
                                "args": args,
                                "output": reason,
                                "ok": False,
                            })
                            results.append((call, False, reason, None))
                            continue
                        if new_command != args.get("command"):
                            args = dict(args)
                            args["command"] = new_command
                            call["args"] = args
                        try:
                            cwd = resolve_cwd(args.get("cwd"))
                        except ValueError as exc:
                            reason = "Refused: %s." % exc
                            send({
                                "type": "tool",
                                "id": request_id,
                                "callId": call["id"],
                                "name": name,
                                "args": args,
                                "output": reason,
                                "ok": False,
                            })
                            results.append((call, False, reason, None))
                            continue
                        if cwd and cwd != args.get("cwd"):
                            args = dict(args)
                            args["cwd"] = cwd
                            call["args"] = args
                    if name in ("write_file", "edit_file", "create_project"):
                        ok_pre, reason, path, new_hash = preflight_change(name, args)
                        if not ok_pre:
                            send({
                                "type": "tool",
                                "id": request_id,
                                "callId": call["id"],
                                "name": name,
                                "args": args,
                                "output": reason,
                                "ok": False,
                            })
                            results.append((call, False, reason, None))
                            continue
                        if path and new_hash and new_hash in seen_states.get(path, set()):
                            reason = (
                                "Refused: this edit would return %s to a state it already "
                                "had earlier in this request. You are undoing and redoing "
                                "the same change. Re-read the file, decide the final "
                                "content, then make one edit." % path
                            )
                            send({
                                "type": "tool",
                                "id": request_id,
                                "callId": call["id"],
                                "name": name,
                                "args": args,
                                "output": reason,
                                "ok": False,
                            })
                            results.append((call, False, reason, None))
                            continue

                    approved = await_approval(request_id, call["id"], name, args)
                    if is_cancelled(request_id):
                        return
                    if not approved:
                        send({
                            "type": "tool",
                            "id": request_id,
                            "callId": call["id"],
                            "name": name,
                            "args": args,
                            "output": "The user denied this action.",
                            "ok": False,
                            "denied": True,
                        })
                        results.append((
                            call,
                            False,
                            "Denied by the user. Do not retry it. Explain what you would "
                            "have done, or ask how they want to proceed.",
                            None,
                        ))
                        continue

                send({
                    "type": "tool",
                    "id": request_id,
                    "callId": call["id"],
                    "name": name,
                    "args": args,
                    "pending": True,
                })
                # exec_command() reads this to attach an interactive prompt to
                # the right request and card.
                _tool_ctx.request_id = request_id
                _tool_ctx.call_id = call["id"]
                ok, output, image = run_tool(name, args)
                if dispatch_note:
                    output = dispatch_note + "\n" + output
                if ok and path and new_hash:
                    seen_states.setdefault(path, set()).add(new_hash)
                send({
                    "type": "tool",
                    "id": request_id,
                    "callId": call["id"],
                    "name": name,
                    "args": args,
                    "output": output,
                    "ok": ok,
                    "imagePath": image["path"] if image else "",
                })
                results.append((call, ok, output, image))

            if is_cancelled(request_id):
                return
            append_tool_results(kind, messages, results)

        send({
            "type": "done",
            "id": request_id,
            "text": "Stopped after %d tool steps. Ask me to continue if you want me to keep going."
                    % MAX_AGENT_STEPS,
        })
    except Exception as exc:  # noqa: BLE001
        if is_cancelled(request_id):
            return
        send({"type": "error", "id": request_id, "message": str(exc)})
    finally:
        clear_cancelled(request_id)


# ───────────────────────────── legacy ─────────────────────────────


def handle_legacy(line):
    cmd = line.strip()
    if not cmd:
        return
    first = cmd.split()[0] if cmd.split() else ""
    if first in REVIEW_COMMANDS:
        send({
            "type": "proposal",
            "title": "Action Proposal",
            "message": "Review this command before approving:",
            "code": cmd,
        })
    else:
        send({"type": "note", "title": "UnityAgent", "message": "Received: " + cmd})


def dispatch(line):
    line = line.strip()
    if not line:
        return
    try:
        req = json.loads(line)
    except Exception:
        handle_legacy(line)
        return
    if not isinstance(req, dict):
        return

    kind = req.get("type")
    if kind == "chat":
        threading.Thread(target=handle_chat, args=(req,), daemon=True).start()
    elif kind == "agent":
        threading.Thread(target=handle_agent, args=(req,), daemon=True).start()
    elif kind == "approve":
        resolve_approval(req.get("callId") or "", req.get("approved") is True)
    elif kind == "input-result":
        resolve_input(
            req.get("callId") or "",
            req.get("value") or "",
            req.get("cancelled") is True,
        )
    elif kind == "run":
        threading.Thread(target=handle_run, args=(req,), daemon=True).start()
    elif kind == "stop":
        mark_cancelled(req.get("id") or "")
    elif kind == "ping":
        send({"type": "ready"})
    elif kind:
        send({"type": "note", "title": "UnityAgent", "message": "Unknown request: " + str(kind)})
    else:
        handle_legacy(line)


# ───────────────────────────── main ─────────────────────────────


def evict_other_daemons():
    """Only one daemon may read the input FIFO; later ones take over."""
    import signal

    me = os.getpid()
    for entry in os.listdir("/proc"):
        if not entry.isdigit() or int(entry) == me:
            continue
        pid = int(entry)
        try:
            with open("/proc/%d/cmdline" % pid, "rb") as f:
                argv = f.read().split(b"\0")
        except OSError:
            continue
        if not argv or not argv[0]:
            continue
        exe = os.path.basename(argv[0].decode("utf-8", "replace"))
        if "python" not in exe:
            continue
        script = [a.decode("utf-8", "replace") for a in argv[1:3] if a]
        if any(os.path.basename(s) == "unityagentd.py" for s in script):
            try:
                os.kill(pid, signal.SIGTERM)
            except OSError:
                pass


def open_input():
    """Open the request FIFO for reading.

    A blocking open() is the whole point: it parks the daemon in the kernel
    until Quickshell (or any other writer) connects, instead of polling a
    reader that has no writer. A FIFO opened O_RDONLY|O_NONBLOCK with no
    writer is *permanently* readable and read() returns b"" — that is the EOF
    busy-loop that used to burn a core.
    """
    return os.open(IPC_OUT, os.O_RDONLY)


def read_pipe():
    """Block on the request FIFO, dispatching every complete line.

    Returns when the writer closes its end (read() gives EOF), so the caller
    can reopen. Data already written is drained before EOF is seen, because
    read() hands back the buffered bytes first and only then reports b"".
    """
    fd = open_input()
    buf = b""
    try:
        while True:
            try:
                chunk = os.read(fd, 4096)
            except InterruptedError:
                continue
            except OSError as exc:  # noqa: BLE001
                sys.stderr.write("unityagentd: read error: %s\n" % exc)
                return

            if not chunk:
                # Every writer closed. A trailing line without a newline is
                # dropped: the protocol always terminates a request with one.
                if buf.strip():
                    sys.stderr.write("unityagentd: discarding a partial request\n")
                return

            buf += chunk
            while b"\n" in buf:
                raw, buf = buf.split(b"\n", 1)
                try:
                    dispatch(raw.decode("utf-8", "replace"))
                except Exception as exc:  # noqa: BLE001
                    sys.stderr.write("unityagentd: dispatch error: %s\n" % exc)
                    sys.stderr.flush()
    finally:
        try:
            os.close(fd)
        except OSError:
            pass


def main():
    ensure_fifos()
    evict_other_daemons()

    sys.stderr.write("unityagentd: listening\n")
    sys.stderr.flush()
    send({"type": "ready"})

    while True:
        try:
            # Blocks here until a writer connects, then until it writes.
            read_pipe()
        except InterruptedError:
            continue
        except OSError as exc:  # noqa: BLE001
            # The FIFO is gone (tmp cleaner, manual rm) — put it back.
            sys.stderr.write("unityagentd: cannot open input fifo: %s\n" % exc)
            ensure_fifos()

        # The writer went away, or the open failed. Never spin: a closed or
        # missing FIFO would otherwise be "readable" forever and eat a core.
        time.sleep(0.01)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
