pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// UnityAgent state.
//
//   visible        the chat window is open
//   view           "chat" | "settings"
//   conversations  persistent chat history (state dir, not shell settings)
//   settings/keys  BYOK model configuration
//
// The daemon talks JSON over two FIFOs:
//   ~ -> daemon : /tmp/unityagent_user_input.fifo
//   daemon -> ~ : /tmp/unityagent_ipc.fifo
//
// Keys live in ~/.local/state/hexin/unityagent/settings.json (chmod 600),
// never in ~/.config/hexin/settings.json.
Singleton {
    id: root

    readonly property string stateDir: {
        const base = Quickshell.env("XDG_STATE_HOME")
        const home = Quickshell.env("HOME") || ""
        return (base && base.length ? base : home + "/.local/state") + "/hexin/unityagent"
    }
    readonly property string settingsPath: stateDir + "/settings.json"
    readonly property string historyPath: stateDir + "/history.json"
    readonly property string inputFifo: "/tmp/unityagent_user_input.fifo"
    readonly property string ipcFifo: "/tmp/unityagent_ipc.fifo"

    readonly property string defaultSystemPrompt: "You are UnityAgent, the agent built into the hexin desktop shell (Arch Linux + Hyprland). Be concise, accurate and practical. You can read and search files, list folders, fetch web pages, search the web, capture the screen, move the pointer, click and scroll with ydotool, create projects, write and edit files, and run shell commands through tools. Read-only tools run immediately; create_project, write_file, edit_file, run_command and mouse_click are shown to the user as an approval card, so call them when the task needs them and never claim something happened until a tool result says so. Before clicking, take a screenshot, use the monitor layout in the result to convert what you see into logical x/y coordinates, and say what you are about to click; prefer passing x/y to mouse_click over a separate mouse_move. Read the real config or file before answering instead of guessing. If a tool is denied, do not retry it. Hyprland actions use the Lua dispatchers (`hl.dsp.*`), never legacy `hyprctl dispatch workspace 3` syntax. To install packages, check the official repos first and use `sudo pacman -S --needed <pkg>`; only use `yay -S --needed <pkg>` when the package is not in the repos and is available on the AUR. All coding projects you create must live under `~/Projects/UnityAgent/<name>`: call create_project with a short name, add files with write_file, then build and test with run_command and `cwd` set to that project folder. Use short paragraphs and markdown, with commands in fenced code blocks."
    // Older builds stored these exact prompts; migrate them so existing installs
    // get the tool behaviour without overwriting a custom prompt.
    readonly property var legacySystemPrompts: [
        "You are UnityAgent, the agent built into the hexin desktop shell (Arch Linux + Hyprland). Be concise, accurate and practical. You can read and search files, list folders, fetch web pages, search the web, capture the screen, create projects, write and edit files, and run shell commands through tools. Read-only tools run immediately; create_project, write_file, edit_file and run_command are shown to the user as an approval card, so call them when the task needs them and never claim something happened until a tool result says so. Read the real config or file before answering instead of guessing. If a tool is denied, do not retry it. Hyprland actions use the Lua dispatchers (`hl.dsp.*`), never legacy `hyprctl dispatch workspace 3` syntax. To install packages, check the official repos first and use `sudo pacman -S --needed <pkg>`; only use `yay -S --needed <pkg>` when the package is not in the repos and is available on the AUR. All coding projects you create must live under `~/Projects/UnityAgent/<name>`: call create_project with a short name, add files with write_file, then build and test with run_command and `cwd` set to that project folder. Use short paragraphs and markdown, with commands in fenced code blocks.",
        "You are UnityAgent, the agent built into the hexin desktop shell (Arch Linux + Hyprland). Be concise, accurate and practical. You can read and search files, list folders, fetch web pages, search the web, capture the screen, write and edit files, and run shell commands through tools. Read-only tools run immediately; write_file, edit_file and run_command are shown to the user as an approval card, so call them when the task needs them and never claim something happened until a tool result says so. Read the real config or file before answering instead of guessing. If a tool is denied, do not retry it. Hyprland actions use the Lua dispatchers (`hl.dsp.*`), never legacy `hyprctl dispatch workspace 3` syntax. To install packages, check the official repos first and use `sudo pacman -S --needed <pkg>`; only use `yay -S --needed <pkg>` when the package is not in the repos and is available on the AUR. Use short paragraphs and markdown, with commands in fenced code blocks.",
        "You are UnityAgent, the agent built into the hexin desktop shell (Arch Linux + Hyprland). Be concise, accurate and practical. You can read and search files, list folders, fetch web pages, search the web, write and edit files, and run shell commands through tools. Read-only tools run immediately; write_file, edit_file and run_command are shown to the user as an approval card, so call them when the task needs them and never claim something happened until a tool result says so. Read the real config or file before answering instead of guessing. If a tool is denied, do not retry it. Use short paragraphs and markdown, with commands in fenced code blocks.",
        "You are UnityAgent, the assistant built into the hexin desktop shell (Arch Linux + Hyprland). Be concise, accurate and practical. Use short paragraphs and fenced code blocks for commands. When the user asks you to perform a system action, put the exact command in a single ```bash block; the interface turns it into an approval card and nothing runs until the user presses Approve & Run. After a command runs you receive a [tool result] message with its exit code and output: explain in plain, friendly language what it means and whether it worked, and if more action is needed propose exactly one command in a ```bash block. Never claim a command ran unless a tool result says so.",
        "You are UnityAgent, the assistant built into the hexin desktop shell (Arch Linux + Hyprland). Be concise, accurate and practical. Use short paragraphs and fenced code blocks for commands. When the user asks you to perform a system action, put the exact command in a single ```bash block; the interface turns it into an approval card and nothing runs until the user presses Approve & Run. Never claim a command ran unless it did."
    ]

    // A bundled description of this machine (the Lua Hyprland config, keybinds,
    // the shell) is appended to the system prompt on every request. Without it
    // the model answers as if this were a stock Hyprland install: editing
    // hyprland.conf, installing grim, and so on.
    property string agentContext: ""

    // ───────────── policy ─────────────
    // Settings > UnityAgent owns these switches. The daemon gets the same
    // feature map with every request, so turning a feature off here also
    // removes or refuses its tools instead of only hiding UI.
    readonly property bool enabled: Config.unityAgent.enabled
    onEnabledChanged: {
        if (!enabled && busy)
            stop();
        // Turning the universal switch back on starts the daemon that login
        // autostart skipped while it was off.
        if (enabled && daemonCheck)
            ensureDaemon();
    }
    readonly property var features: ({
            projects: Config.unityAgent.projects,
            commands: Config.unityAgent.commands,
            files: Config.unityAgent.files,
            packages: Config.unityAgent.packages,
            weeklyUpdates: Config.unityAgent.weeklyUpdates,
            web: Config.unityAgent.web,
            screenshots: Config.unityAgent.screenshots,
            mouse: Config.unityAgent.mouse
        })
    readonly property string featureContext: {
        if (!enabled)
            return "The user turned UnityAgent off in Settings > UnityAgent. Do not answer or run tools.";
        const off = [];
        if (!Config.unityAgent.projects)
            off.push("creating coding projects");
        if (!Config.unityAgent.commands)
            off.push("running shell commands");
        if (!Config.unityAgent.files)
            off.push("writing or editing files");
        if (!Config.unityAgent.packages)
            off.push("installing or removing packages");
        if (!Config.unityAgent.web)
            off.push("web search and page fetching");
        if (!Config.unityAgent.screenshots)
            off.push("taking screenshots");
        if (!Config.unityAgent.mouse)
            off.push("moving, clicking or scrolling the mouse");
        if (!off.length)
            return "";
        return "The user turned these features off in Settings > UnityAgent: " + off.join(", ") + ". Do not attempt them. If asked, explain that the feature is disabled and where to turn it back on.";
    }
    readonly property string effectiveSystemPrompt: {
        const parts = [
            (settings.systemPrompt || "").trim(),
            (agentContext || "").trim(),
            featureContext.trim()
        ].filter(p => p.length);
        return parts.join("\n\n");
    }

    // ───────────── window state ─────────────
    property bool visible: false
    property string view: "chat"

    // ───────────── chat history ─────────────
    property var conversations: []
    property string activeId: ""
    property bool busy: false
    // True while text from the current request is streaming in. Together with
    // `busy` this lets the UI tell "thinking" (waiting for the first token or
    // for a tool) apart from "responding" (tokens are arriving).
    property bool streaming: false
    property bool runningCommand: false
    property bool historyLoaded: false
    // The request id of the agent loop currently running, so Stop can cancel
    // the daemon thread (including a pending approval wait).
    property string activeRequestId: ""
    // Outgoing FIFO writes are queued and fed to a small helper over stdin.
    // The old `execDetached(["sh","-c","printf ... > fifo"])` put the whole
    // request — including an interactive password — in argv where `ps` could
    // see it.
    property var postQueue: []
    property string postLine: ""

    readonly property int activeIndex: {
        for (let i = 0; i < conversations.length; i++) {
            if (conversations[i].id === activeId)
                return i
        }
        return -1
    }
    readonly property var activeConversation: activeIndex >= 0 ? conversations[activeIndex] : null
    readonly property var messages: activeConversation ? (activeConversation.messages || []) : []
    readonly property string activeTitle: activeConversation ? (activeConversation.title || "New chat") : "New chat"

    // ───────────── BYOK configuration ─────────────
    property var settings: ({
            provider: "openai",
            model: "gpt-5",
            baseUrl: "",
            temperature: 0.7,
            systemPrompt: defaultSystemPrompt,
            // Timestamp of the last weekly package-update check.
            lastUpdateCheck: 0
        })
    property var keys: ({})
    property var customModels: ({})
    property bool settingsLoaded: false

    readonly property var provider: Models.byId(settings.provider)
    readonly property var providerModels: {
        const extra = customModels[settings.provider] || []
        return modelsForProvider(settings.provider).concat(extra.filter(m => modelsForProvider(settings.provider).indexOf(m) < 0))
    }
    readonly property string effectiveBaseUrl: (settings.baseUrl && settings.baseUrl.length) ? settings.baseUrl : (provider ? provider.baseUrl : "")
    readonly property bool providerNeedsKey: provider ? Models.needsKey(provider.id) : true
    readonly property bool modelReady: {
        if (!provider || !settings.model || settings.model.length === 0)
            return false
        if (providerNeedsKey && !(keys[provider.id] || "").length)
            return false
        return true
    }

    // ───────────── connection test ─────────────
    property bool testRunning: false
    property string testResult: ""
    property string testRequestId: ""

    // ───────────── weekly update check ─────────────
    property bool updateCheckRunning: false
    property string updateSummary: ""
    readonly property int updateIntervalMs: 7 * 24 * 60 * 60 * 1000

    // ───────────── public actions ─────────────

    // The universal switch lives in Settings > UnityAgent. When it is off the
    // shortcut must not open the window at all: say why instead, so the key
    // does not look broken.
    function notifyOff() {
        Quickshell.execDetached([
            "notify-send", "-a", "hexin", "-i", "dialog-information",
            "-u", "normal", "-t", "4000",
            "-h", "string:x-hexin-notice:1",
            "UnityAgent", "UnityAgent is off. Turn it on in Settings → UnityAgent."
        ]);
    }

    // A crash/service report waiting for the current turn to finish.
    property string pendingFix: ""

    onBusyChanged: flushPendingFix()
    onRunningCommandChanged: flushPendingFix()

    function flushPendingFix() {
        if (!pendingFix.length || busy || runningCommand)
            return
        if (!enabled) {
            pendingFix = ""
            return
        }
        const prompt = pendingFix
        pendingFix = ""
        sendMessage(prompt)
    }

    // Called by the System errors watcher when the user picks "Fix with AI".
    function fixSystemError(info) {
        if (!enabled) {
            notifyOff()
            return
        }
        const prompt = "A system error was reported by hexin:\n\n" + info.prompt
            + "\n\nReply with your diagnosis first. If a fix is needed, propose it and wait for my approval."
        open()
        if (busy || runningCommand) {
            pendingFix = prompt
            Notifs.notify("UnityAgent is busy", "The error report is queued and will be sent when the current request finishes.", "dialog-information")
            return
        }
        sendMessage(prompt)
    }

    function toggle() {
        if (!enabled) {
            notifyOff();
            return;
        }
        visible = !visible
        if (visible)
            view = "chat"
    }

    function open() {
        visible = true
        view = "chat"
    }

    function close() {
        visible = false
    }

    function showChat() {
        view = "chat"
    }

    function showSettings() {
        view = "settings"
    }

    function newChat() {
        // Reuse an empty conversation instead of piling up "New chat" rows.
        if (activeConversation && (activeConversation.messages || []).length === 0) {
            view = "chat"
            return
        }
        const now = Date.now()
        const conv = {
            id: "c" + now.toString(36) + Math.random().toString(36).slice(2, 6),
            title: "New chat",
            created: now,
            updated: now,
            messages: []
        }
        conversations = [conv].concat(conversations)
        activeId = conv.id
        view = "chat"
        scheduleHistorySave()
    }

    function deleteChat(id) {
        const next = conversations.filter(c => c.id !== id)
        conversations = next
        if (activeId === id)
            activeId = next.length ? next[0].id : ""
        if (next.length === 0)
            newChat()
        scheduleHistorySave()
    }

    function selectChat(id) {
        activeId = id
        view = "chat"
    }

    function clearHistory() {
        conversations = []
        activeId = ""
        newChat()
    }

    function modelsForProvider(id) {
        const base = Models.modelsFor(id) || []
        const extra = customModels[id] || []
        return base.concat(extra)
    }

    function keyFor(id) {
        return keys[id] || ""
    }

    function setKey(id, value) {
        const next = Object.assign({}, keys)
        const clean = (value || "").trim()
        if (clean.length)
            next[id] = clean
        else
            delete next[id]
        keys = next
        scheduleSettingsSave()
    }

    function setProvider(id) {
        const p = Models.byId(id)
        const list = modelsForProvider(id)
        settings = Object.assign({}, settings, {
            provider: id,
            model: list.length ? list[0] : "",
            baseUrl: ""
        })
        scheduleSettingsSave()
    }

    function setModel(model) {
        settings = Object.assign({}, settings, { model: model })
        scheduleSettingsSave()
    }

    function addCustomModel(model) {
        const id = settings.provider
        const clean = (model || "").trim()
        // Model ids are short; anything longer is a mis-paste (an API key, a
        // whole line of text) and would blow the chip layout apart.
        if (!clean.length || clean.length > 80 || /\s/.test(clean))
            return
        const list = (customModels[id] || []).slice()
        if (list.indexOf(clean) < 0)
            list.push(clean)
        const next = Object.assign({}, customModels)
        next[id] = list
        customModels = next
        setModel(clean)
    }

    function removeCustomModel(model) {
        const id = settings.provider
        const list = (customModels[id] || []).filter(m => m !== model)
        const next = Object.assign({}, customModels)
        if (list.length)
            next[id] = list
        else
            delete next[id]
        customModels = next
        if (settings.model === model)
            setModel((Models.modelsFor(id) || ["gpt-4o-mini"])[0])
        scheduleSettingsSave()
    }

    function setBaseUrl(url) {
        settings = Object.assign({}, settings, { baseUrl: url })
        scheduleSettingsSave()
    }

    function setTemperature(t) {
        settings = Object.assign({}, settings, { temperature: t })
        scheduleSettingsSave()
    }

    function setSystemPrompt(text) {
        settings = Object.assign({}, settings, { systemPrompt: text })
        scheduleSettingsSave()
    }

    function resetSystemPrompt() {
        setSystemPrompt(defaultSystemPrompt)
    }

    // ───────────── weekly update check ─────────────

    function maybeWeeklyUpdate() {
        if (!enabled || !Config.unityAgent.weeklyUpdates || updateCheckRunning)
            return
        if (!settingsLoaded)
            return
        const last = settings.lastUpdateCheck || 0
        if (last > 0 && Date.now() - last < updateIntervalMs)
            return
        runUpdateCheck()
    }

    // Read-only: `checkupdates` when pacman-contrib is installed, otherwise
    // `pacman -Qu`. Neither needs root and neither touches the system.
    function runUpdateCheck() {
        if (updateCheckRunning)
            return
        updateCheckRunning = true
        updateSummary = ""
        updateCheck.command = ["sh", "-c",
            "if command -v checkupdates >/dev/null 2>&1; then exec checkupdates; else exec pacman -Qu; fi"]
        updateCheck.running = true
    }

    function finishUpdateCheck(output) {
        updateCheckRunning = false
        const lines = (output || "").trim().split("\n").filter(l => l.trim().length)
        settings = Object.assign({}, settings, { lastUpdateCheck: Date.now() })
        scheduleSettingsSave()

        if (!lines.length) {
            updateSummary = "Up to date"
            return
        }

        updateSummary = lines.length + (lines.length === 1 ? " update available" : " updates available")
        Quickshell.execDetached([
            "notify-send", "-a", "hexin", "-i", "system-software-update",
            "-u", "normal", "-t", "6000",
            "UnityAgent", updateSummary + " — ask me to install them."
        ])

        // Leave a note in the open chat so the result is still there after the
        // toast disappears. Never interrupt a running request.
        if (historyLoaded && !busy && activeIndex >= 0) {
            const shown = lines.slice(0, 24).join("\n") + (lines.length > 24 ? "\n…" : "")
            appendMessage(activeIndex, {
                role: "note",
                title: "Weekly update check",
                content: updateSummary + ":\n" + shown + "\n\nAsk me to update the system when you are ready.",
                ts: Date.now()
            })
            scheduleHistorySave()
        }
    }

    // ───────────── sending ─────────────

    function sendMessage(text) {
        const body = (text || "").trim()
        if (!body.length || busy || runningCommand || !enabled)
            return
        if (activeIndex < 0)
            newChat()

        const ci = activeIndex
        appendMessage(ci, {
            role: "user",
            content: body,
            ts: Date.now()
        })
        titleFromFirstMessage(ci, body)

        if (!modelReady) {
            appendMessage(ci, {
                role: "assistant",
                content: providerNeedsKey
                    ? "No API key for " + (provider ? provider.name : "this provider") + " yet. Open Settings (the gear in the sidebar) and paste a key — it is stored locally in " + stateDir + "."
                    : "Pick a model in Settings first.",
                ts: Date.now(),
                error: true
            })
            return
        }

        const convo = conversations[ci]
        const history = buildHistory(convo.messages)
        const rid = "r" + Date.now().toString(36) + Math.random().toString(36).slice(2, 6)
        activeRequestId = rid
        appendMessage(ci, {
            role: "assistant",
            content: "",
            ts: Date.now(),
            pending: true,
            requestId: rid
        })

        busy = true
        streaming = false
        // An agent turn can wait on several approvals; the daemon has its own
        // HTTP timeout, so this is only a last-resort unstick.
        watchdog.interval = 900000
        watchdog.restart()
        post({
            type: "agent",
            id: rid,
            enabled: enabled,
            features: features,
            provider: provider.id,
            kind: provider.kind || "openai",
            baseUrl: effectiveBaseUrl,
            apiKey: keyFor(provider.id),
            model: settings.model,
            temperature: settings.temperature,
            systemPrompt: effectiveSystemPrompt,
            messages: history
        })
    }

    // Convert the visible conversation into provider messages. Tool cards are
    // reduced to short "[tool: …]" notes so a later request still knows what was
    // read or run; inside one request the daemon speaks the provider's native
    // tool format itself.
    function buildHistory(msgs) {
        const out = []
        function push(role, content) {
            const text = (content || "").trim()
            if (!text.length)
                return
            const last = out.length ? out[out.length - 1] : null
            if (last && last.role === role)
                last.content += "\n\n" + text
            else
                out.push({ role: role, content: text })
        }
        for (let i = 0; i < (msgs || []).length; i++) {
            const m = msgs[i]
            if (m.pending || m.error)
                continue
            if (m.role === "user")
                push("user", m.content)
            else if (m.role === "assistant") {
                let text = m.content || ""
                if (m.code)
                    text += "\n\n```bash\n" + m.code + "\n```"
                push("assistant", text)
            } else if (m.role === "tool") {
                // Tool cards are UI-only inside a request (the daemon speaks the
                // provider's native tool format), but a summary keeps the next
                // request aware of what was read or run. Keep enough of a read
                // result to remember the values that were changed — truncating
                // too hard is what made a revert guess at the old keybind.
                const a = m.toolArgs || {}
                const arg = a.command || a.path || a.url || a.query || ""
                const body = (m.output || "").trim()
                const cap = 6000
                push("user", "[tool: " + (m.toolName || "command") + (arg ? " " + arg : "") + "]\n"
                     + (body.length ? body.slice(0, cap) : "(no output)")
                     + (body.length > cap ? "\n… (truncated; read the file again if you need the rest)" : ""))
            }
        }
        return out
    }

    function toolTurn(command, output, exitCode, failed) {
        const code = (exitCode === null || exitCode === undefined) ? "unknown" : String(exitCode)
        const body = (output || "").trim()
        return "[tool result]\nCommand: `" + command + "`\nExit code: " + code + " (" + (failed ? "failed" : "succeeded") + ")\nOutput:\n```\n" + (body.length ? body : "(no output)") + "\n```"
    }

    // After an approved command finishes, send the result back to the model so
    // it can explain what happened in plain words (and propose the next step).
    function explainRunResult(ci, mi, command, output, exitCode, failed) {
        const conv = conversations[ci]
        if (!conv || !modelReady)
            return
        const history = buildHistory((conv.messages || []).slice(0, mi))
        const intro = toolTurn(command, output, exitCode, failed)
        history.push({
            role: "user",
            content: intro + "\n\nExplain that result to me in simple, friendly language: what happened, whether it worked and what it means. If it failed, say how to fix it. If a follow-up command would help, propose exactly one command in a ```bash block and ask for my approval. Do not claim you ran anything yourself."
        })
        const rid = "e" + Date.now().toString(36) + Math.random().toString(36).slice(2, 6)
        activeRequestId = rid
        appendMessage(ci, {
            role: "assistant",
            content: "",
            ts: Date.now(),
            pending: true,
            requestId: rid
        })
        busy = true
        streaming = false
        watchdog.interval = 120000
        watchdog.restart()
        post({
            type: "chat",
            id: rid,
            provider: provider.id,
            kind: provider.kind || "openai",
            baseUrl: effectiveBaseUrl,
            apiKey: keyFor(provider.id),
            model: settings.model,
            temperature: settings.temperature,
            systemPrompt: effectiveSystemPrompt,
            messages: history
        })
    }

    function stop() {
        if (!busy || runningCommand)
            return
        if (activeRequestId.length)
            post({
                type: "stop",
                id: activeRequestId
            })
        for (let i = 0; i < conversations.length; i++) {
            const msgs = conversations[i].messages || []
            for (let j = 0; j < msgs.length; j++) {
                if (!msgs[j].pending)
                    continue
                if (msgs[j].role === "tool")
                    updateMessage(i, j, {
                        pending: false,
                        needsApproval: false,
                        needsInput: false,
                        inputPrompt: "",
                        inputSecret: false,
                        error: true,
                        title: "Stopped",
                        output: "Stopped before it finished."
                    })
                else
                    updateMessage(i, j, {
                        pending: false,
                        error: true,
                        content: "Stopped."
                    })
            }
        }
        busy = false
        streaming = false
        activeRequestId = ""
        watchdog.stop()
    }

    // The user pressed Approve or Deny on a tool card. The daemon is blocked in
    // await_approval() for this call id and resumes as soon as it reads this.
    function approveTool(callId, approved) {
        const hit = findByCallId(callId)
        if (!hit)
            return
        const msg = conversations[hit.ci].messages[hit.mi]
        // Ignore a second click (or a stale script call): the daemon only waits
        // while the card is still asking.
        if (!msg || msg.needsApproval !== true)
            return
        updateMessage(hit.ci, hit.mi, {
            needsApproval: false,
            needsInput: false,
            inputPrompt: "",
            inputSecret: false,
            pending: approved === true,
            denied: approved !== true,
            error: approved !== true,
            title: approved === true ? "" : "Denied"
        })
        post({
            type: "approve",
            callId: callId,
            approved: approved === true
        })
    }

    // The user answered an interactive prompt. The value goes only over the
    // FIFO to the daemon; it is never added to a message, so it cannot appear
    // in the transcript, history.json, or a later model request.
    function submitInput(callId, value, cancelled) {
        const hit = findByCallId(callId)
        if (!hit)
            return
        const msg = conversations[hit.ci].messages[hit.mi]
        if (!msg || msg.needsInput !== true)
            return
        updateMessage(hit.ci, hit.mi, {
            needsInput: false,
            inputPrompt: "",
            inputSecret: false,
            pending: cancelled !== true,
            denied: cancelled === true,
            error: cancelled === true,
            title: cancelled === true ? "Cancelled" : ""
        })
        post({
            type: "input-result",
            callId: callId,
            value: cancelled === true ? "" : String(value || ""),
            cancelled: cancelled === true
        })
    }

    function approveCommand(code) {
        const command = (code || "").trim()
        if (!command.length || runningCommand || !enabled || !Config.unityAgent.commands)
            return
        if (activeIndex < 0)
            newChat()
        const ci = activeIndex
        const rid = "x" + Date.now().toString(36) + Math.random().toString(36).slice(2, 6)
        appendMessage(ci, {
            role: "tool",
            content: command,
            title: "Running",
            ts: Date.now(),
            pending: true,
            requestId: rid
        })
        busy = true
        runningCommand = true
        watchdog.interval = 320000
        watchdog.restart()
        post({
            type: "run",
            id: rid,
            command: command
        })
    }

    function testConnection() {
        if (testRunning)
            return
        testResult = ""
        if (!provider || !settings.model) {
            testResult = "Pick a provider and model first."
            return
        }
        if (providerNeedsKey && !keyFor(provider.id).length) {
            testResult = "Add an API key first."
            return
        }
        testRequestId = "t" + Date.now().toString(36)
        testRunning = true
        post({
            type: "chat",
            id: testRequestId,
            provider: provider.id,
            kind: provider.kind || "openai",
            baseUrl: effectiveBaseUrl,
            apiKey: keyFor(provider.id),
            model: settings.model,
            temperature: 0,
            systemPrompt: "You are a connection test. Reply with exactly: OK",
            messages: [
                {
                    role: "user",
                    content: "Reply with exactly: OK"
                }
            ]
        })
        testTimeout.restart()
    }

    // ───────────── conversation mutations ─────────────

    function appendMessage(ci, msg) {
        const conv = conversations[ci]
        if (!conv)
            return
        const msgs = (conv.messages || []).slice()
        msgs.push(msg)
        replaceConversation(ci, Object.assign({}, conv, {
            messages: msgs,
            updated: Date.now()
        }))
        scheduleHistorySave()
    }

    // Insert a message before the pending assistant bubble, so the transcript
    // reads user → tool cards → answer instead of answer → tool cards.
    function insertMessage(ci, msg) {
        const conv = conversations[ci]
        if (!conv)
            return
        const msgs = (conv.messages || []).slice()
        let at = -1
        for (let i = msgs.length - 1; i >= 0; i--) {
            if (msgs[i].role === "assistant" && msgs[i].pending) {
                at = i
                break
            }
        }
        if (at < 0)
            msgs.push(msg)
        else
            msgs.splice(at, 0, msg)
        replaceConversation(ci, Object.assign({}, conv, {
            messages: msgs,
            updated: Date.now()
        }))
        scheduleHistorySave()
    }

    function updateMessage(ci, mi, patch) {
        const conv = conversations[ci]
        if (!conv || !conv.messages || !conv.messages[mi])
            return
        const msgs = conv.messages.slice()
        msgs[mi] = Object.assign({}, msgs[mi], patch)
        replaceConversation(ci, Object.assign({}, conv, {
            messages: msgs,
            updated: Date.now()
        }))
        scheduleHistorySave()
    }

    function replaceConversation(ci, conv) {
        const next = conversations.slice()
        next[ci] = conv
        conversations = next
    }

    function titleFromFirstMessage(ci, body) {
        const conv = conversations[ci]
        if (!conv || (conv.title !== "New chat" && conv.title.length))
            return
        let title = body.replace(/\s+/g, " ").trim()
        if (title.length > 46)
            title = title.slice(0, 44) + "…"
        replaceConversation(ci, Object.assign({}, conv, { title: title }))
    }

    function findPending(requestId) {
        for (let i = 0; i < conversations.length; i++) {
            const msgs = conversations[i].messages || []
            for (let j = 0; j < msgs.length; j++) {
                if (msgs[j].requestId === requestId && msgs[j].pending)
                    return {
                        ci: i,
                        mi: j
                    }
            }
        }
        return null
    }

    // Any message belonging to a request, pending or not.
    function findRequest(requestId) {
        if (!requestId)
            return null
        for (let i = 0; i < conversations.length; i++) {
            const msgs = conversations[i].messages || []
            for (let j = 0; j < msgs.length; j++) {
                if (msgs[j].requestId === requestId)
                    return {
                        ci: i,
                        mi: j
                    }
            }
        }
        return null
    }

    function findByCallId(callId) {
        if (!callId)
            return null
        for (let i = 0; i < conversations.length; i++) {
            const msgs = conversations[i].messages || []
            for (let j = msgs.length - 1; j >= 0; j--) {
                if (msgs[j].callId === callId)
                    return {
                        ci: i,
                        mi: j
                    }
            }
        }
        return null
    }

    // Tool arguments are kept in history for the card. A write_file body can be
    // large, and history is rewritten on every change, so cap long strings —
    // the daemon already holds the real values, and approval only needs the id.
    function cleanToolArgs(args) {
        const out = {}
        if (!args || typeof args !== "object")
            return out
        for (const k in args) {
            const v = args[k]
            if (typeof v === "string" && v.length > 4000)
                out[k] = v.slice(0, 4000) + "…"
            else
                out[k] = v
        }
        return out
    }

    // A tool or approval event from the daemon: update the card if this call
    // already has one, otherwise insert it before the answer placeholder.
    function applyToolEvent(obj, approval) {
        const patch = {
            toolName: obj.name || "",
            toolArgs: cleanToolArgs(obj.args),
            callId: obj.callId,
            imagePath: obj.imagePath || "",
            needsInput: false,
            inputPrompt: "",
            inputSecret: false
        }
        if (approval) {
            patch.pending = true
            patch.needsApproval = true
        } else if (obj.pending === true) {
            patch.pending = true
            patch.needsApproval = false
        } else {
            patch.pending = false
            patch.needsApproval = false
            patch.output = obj.output || ""
            patch.ok = obj.ok !== false
            patch.denied = obj.denied === true
            patch.error = obj.ok === false
            patch.title = obj.denied === true ? "Denied" : (obj.ok === false ? "Failed" : "Done")
        }

        const hit = findByCallId(obj.callId)
        if (hit) {
            updateMessage(hit.ci, hit.mi, patch)
            return
        }
        const owner = findRequest(obj.id)
        let target = owner ? owner.ci : activeIndex
        if (target < 0) {
            newChat()
            target = activeIndex
        }
        if (target < 0)
            return
        insertMessage(target, Object.assign({
            role: "tool",
            ts: Date.now(),
            content: "",
            output: "",
            needsApproval: false,
            denied: false,
            pending: false,
            ok: true,
            title: "",
            error: false,
            imagePath: ""
        }, patch))
    }

    // A command is waiting for input on its terminal (sudo password, a
    // confirmation, ...). The prompt is shown in the tool card; the answer is
    // posted straight back to the daemon and never written to history.
    function applyInputEvent(obj) {
        const patch = {
            toolName: obj.name || "run_command",
            toolArgs: cleanToolArgs(obj.args || {}),
            callId: obj.callId,
            needsInput: true,
            inputPrompt: obj.prompt || "Input required",
            inputSecret: obj.secret === true,
            pending: true,
            needsApproval: false,
            error: false
        }

        // Bring the window forward so a sudo prompt cannot be missed.
        visible = true
        if (view !== "chat")
            view = "chat"

        const hit = findByCallId(obj.callId)
        if (hit) {
            updateMessage(hit.ci, hit.mi, patch)
            return
        }
        const owner = findRequest(obj.id)
        if (owner) {
            updateMessage(owner.ci, owner.mi, patch)
            return
        }
        let target = activeIndex
        if (target < 0) {
            newChat()
            target = activeIndex
        }
        if (target < 0)
            return
        insertMessage(target, Object.assign({
            role: "tool",
            ts: Date.now(),
            content: "",
            output: "",
            needsApproval: false,
            denied: false,
            pending: true,
            ok: true,
            title: "",
            error: false,
            imagePath: ""
        }, patch))
    }

    // Live output from a command that is still running. The card tails the
    // last lines so a long install shows progress instead of a silent spinner.
    function applyStreamEvent(obj) {
        let hit = findByCallId(obj.callId)
        if (!hit)
            hit = findRequest(obj.id)
        if (!hit)
            return
        const msg = conversations[hit.ci].messages[hit.mi]
        if (!msg || msg.pending !== true)
            return
        updateMessage(hit.ci, hit.mi, {
            output: obj.output || ""
        })
    }

    // ───────────── daemon I/O ─────────────

    function post(obj) {
        root.postQueue.push(JSON.stringify(obj))
        root.pumpPost()
    }

    function pumpPost() {
        if (postWriter.running)
            return
        if (root.postLine.length === 0 && root.postQueue.length > 0)
            root.postLine = root.postQueue.shift()
        if (root.postLine.length === 0)
            return
        postTimeout.restart()
        postWriter.running = true
    }

    function flushPost() {
        if (!postWriter.running || root.postLine.length === 0)
            return
        postWriter.write(root.postLine + "\n")
        root.postLine = ""
    }

    function handleLine(data) {
        if (!data || !data.trim().length)
            return
        let obj = null
        try {
            obj = JSON.parse(data)
        } catch (e) {
            return
        }
        const type = obj.type || ""

        if (type === "delta") {
            const hit = findPending(obj.id)
            if (hit) {
                streaming = true
                const cur = conversations[hit.ci].messages[hit.mi]
                updateMessage(hit.ci, hit.mi, {
                    content: (cur.content || "") + (obj.text || "")
                })
            }
            return
        }

        if (type === "chat" || type === "done") {
            if (obj.id === testRequestId) {
                testRunning = false
                testTimeout.stop()
                testResult = obj.text || "Connected."
                return
            }
            finishRequest(obj.id, obj.text || obj.message || "")
            return
        }

        if (type === "error") {
            if (obj.id === testRequestId) {
                testRunning = false
                testTimeout.stop()
                testResult = obj.message || "Failed."
                return
            }
            failRequest(obj.id, obj.message || "Request failed.")
            return
        }

        if (type === "approval") {
            if (!obj.callId)
                return
            streaming = false
            applyToolEvent(obj, true)
            return
        }

        if (type === "input") {
            if (!obj.callId)
                return
            streaming = false
            applyInputEvent(obj)
            return
        }

        if (type === "tool-output") {
            applyStreamEvent(obj)
            return
        }

        if (type === "tool") {
            if (!obj.callId)
                return
            streaming = false
            applyToolEvent(obj, false)
            return
        }

        if (type === "proposal") {
            streaming = false
            if (activeIndex < 0)
                newChat()
            appendMessage(activeIndex, {
                role: "assistant",
                title: obj.title || "Action Proposal",
                content: obj.message || "",
                code: obj.code || "",
                ts: Date.now()
            })
            return
        }

        if (type === "run-result") {
            const hit = findPending(obj.id)
            if (hit) {
                const msg = conversations[hit.ci].messages[hit.mi]
                const command = (msg && msg.content) || obj.command || ""
                const failed = obj.error === true
                updateMessage(hit.ci, hit.mi, {
                    pending: false,
                    needsInput: false,
                    inputPrompt: "",
                    inputSecret: false,
                    error: failed,
                    title: obj.title || (failed ? "Failed" : "Done"),
                    content: command,
                    output: obj.output || "",
                    exitCode: (obj.exitCode === undefined ? (failed ? 1 : 0) : obj.exitCode)
                })
                busy = false
                runningCommand = false
                streaming = false
                watchdog.stop()
                // Feed the output back to the model immediately; the history
                // save is debounced, so it still captures the finished turn.
                root.explainRunResult(hit.ci, hit.mi, command, obj.output || "", obj.exitCode, failed)
            }
            return
        }

        if (type === "ready")
            return

        // Legacy daemon: {title, message, code} with no type.
        if (obj.title || obj.message) {
            if (activeIndex < 0)
                newChat()
            appendMessage(activeIndex, {
                role: obj.code ? "assistant" : "note",
                title: obj.title || "",
                content: obj.message || "",
                code: obj.code || "",
                ts: Date.now()
            })
        }
    }

    function finishRequest(requestId, text) {
        const hit = findPending(requestId)
        if (hit)
            updateMessage(hit.ci, hit.mi, {
                pending: false,
                content: text || "(empty response)"
            })
        busy = false
        streaming = false
        if (activeRequestId === requestId)
            activeRequestId = ""
        watchdog.stop()
    }

    function failRequest(requestId, message) {
        const hit = findPending(requestId)
        if (hit)
            updateMessage(hit.ci, hit.mi, {
                pending: false,
                error: true,
                content: message
            })
        busy = false
        streaming = false
        if (activeRequestId === requestId)
            activeRequestId = ""
        watchdog.stop()
    }

    // ───────────── persistence ─────────────

    function scheduleHistorySave() {
        if (!historyLoaded)
            return
        saveHistoryTimer.restart()
    }

    function scheduleSettingsSave() {
        if (!settingsLoaded)
            return
        saveSettingsTimer.restart()
    }

    function loadHistory(json) {
        try {
            const data = JSON.parse(json)
            const list = data.conversations
            if (Array.isArray(list) && list.length) {
                conversations = list.map(c => ({
                    id: c.id || ("c" + Math.random().toString(36).slice(2, 8)),
                    title: c.title || "New chat",
                    created: c.created || Date.now(),
                    updated: c.updated || Date.now(),
                    messages: Array.isArray(c.messages)
                        ? c.messages.filter(m => !(m.pending && m.role === "assistant")).map(cleanMessage)
                        : []
                }))
                const wanted = data.activeId
                activeId = conversations.some(c => c.id === wanted) ? wanted : conversations[0].id
            }
        } catch (e) {}
        historyLoaded = true
        if (conversations.length === 0)
            newChat()
    }

    function cleanMessage(m) {
        const interrupted = m.pending === true
        return {
            role: m.role || "assistant",
            title: interrupted && m.role === "tool" ? "Interrupted" : (m.title || ""),
            content: m.content || "",
            code: m.code || "",
            output: m.output || "",
            exitCode: (typeof m.exitCode === "number" ? m.exitCode : null),
            toolName: m.toolName || "",
            toolArgs: (m.toolArgs && typeof m.toolArgs === "object") ? m.toolArgs : {},
            callId: m.callId || "",
            needsApproval: false,
            needsInput: false,
            inputPrompt: "",
            inputSecret: false,
            denied: m.denied === true,
            ok: m.ok !== false,
            ts: m.ts || Date.now(),
            error: m.error === true || interrupted
        }
    }

    function loadSettings(json) {
        try {
            const data = JSON.parse(json)
            if (data.settings) {
                settings = Object.assign({}, settings, data.settings)
                if (legacySystemPrompts.indexOf(settings.systemPrompt) >= 0)
                    settings = Object.assign({}, settings, { systemPrompt: defaultSystemPrompt })
            }
            if (data.keys && typeof data.keys === "object") {
                const clean = {}
                for (const k in data.keys) {
                    if (data.keys[k] && String(data.keys[k]).length)
                        clean[k] = String(data.keys[k])
                }
                keys = clean
            }
            if (data.customModels && typeof data.customModels === "object")
                customModels = data.customModels
        } catch (e) {}
        settingsLoaded = true
    }

    function saveHistory() {
        historyFile.setText(JSON.stringify({
            version: 1,
            activeId: activeId,
            conversations: conversations
        }, null, 2))
    }

    function saveSettings() {
        settingsFile.setText(JSON.stringify({
            version: 1,
            settings: settings,
            keys: keys,
            customModels: customModels
        }, null, 2))
    }

    // ───────────── infrastructure ─────────────

    // ───────────── daemon lifecycle ─────────────
    // The daemon is not autostarted at login while the universal switch is off
    // (see ~/.config/hypr/hexin/40-autostart.lua). Turning the switch back
    // on starts it here, and the boot check covers a shell started on its own.
    // `pgrep` is anchored to `python3` so the check cannot match this shell or
    // an unrelated command that merely mentions the script.
    function ensureDaemon() {
        if (!enabled || daemonCheck.running)
            return
        daemonCheck.running = true
    }

    Timer {
        id: daemonBootCheck
        // Give the login autostart a moment to win, so a fresh session does
        // not briefly run two daemons (the daemon evicts duplicates, but a
        // needless SIGTERM is still churn).
        interval: 6000
        repeat: false
        running: root.enabled && Config.isLoaded
        onTriggered: root.ensureDaemon()
    }

    Process {
        id: daemonCheck
        running: false
        command: ["sh", "-c",
            "mkdir -p \"$HOME/.local/state/hexin\"; "
            + "pgrep -f '^python3 .*unityagentd[.]py' >/dev/null 2>&1 || "
            + "(setsid python3 \"$HOME/.config/hexin/scripts/unityagentd.py\" "
            + ">>\"$HOME/.local/state/hexin/unityagentd.log\" 2>&1 &)"]
    }

    // FIFO reader: holds the fifo open O_RDWR so the daemon's non-blocking
    // writes never fail, evicts stale readers and dies with the shell.
    Process {
        id: ipcReader
        command: ["python3", "-u", (Quickshell.env("HOME") || "") + "/.config/hexin/scripts/unityagent-listen.py", root.ipcFifo]
        running: true
        onExited: restartTimer.restart()
        onRunningChanged: if (running)
            restartTimer.stop()

        stdout: SplitParser {
            onRead: data => root.handleLine(data)
        }
    }

    Timer {
        id: restartTimer
        interval: 500
        repeat: false
        onTriggered: ipcReader.running = true
    }

    // FIFO writer. `read` takes exactly one queued JSON line from stdin and
    // copies it to the request FIFO, so the line (and any password in it) never
    // appears in a process command line. `timeout` stops a writer from hanging
    // forever if the daemon is not running.
    Process {
        id: postWriter
        command: ["timeout", "10", "sh", "-c",
            "IFS= read -r line; printf '%s\\n' \"$line\" > " + root.inputFifo]
        stdinEnabled: true
        onStarted: Qt.callLater(root.flushPost)
        onExited: {
            postTimeout.stop()
            postWriter.running = false
            root.pumpPost()
        }
    }

    // If the writer never starts (or the daemon is gone), drop the line and
    // move on so the agent does not wedge.
    Timer {
        id: postTimeout
        interval: 12000
        repeat: false
        onTriggered: {
            root.postLine = ""
            postWriter.running = false
            root.pumpPost()
        }
    }

    Timer {
        id: watchdog
        interval: 120000
        repeat: false
        onTriggered: {
            if (!root.busy)
                return
            root.busy = false
            root.runningCommand = false
            root.streaming = false
            root.activeRequestId = ""
            for (let i = 0; i < root.conversations.length; i++) {
                const msgs = root.conversations[i].messages || []
                for (let j = 0; j < msgs.length; j++) {
                    if (!msgs[j].pending)
                        continue
                    if (msgs[j].role === "tool") {
                        root.updateMessage(i, j, {
                            pending: false,
                            needsApproval: false,
                            needsInput: false,
                            inputPrompt: "",
                            inputSecret: false,
                            error: true,
                            title: "No response",
                            output: "The tool did not report back. Check the daemon (scripts/unityagentd.py)."
                        })
                    } else {
                        root.updateMessage(i, j, {
                            pending: false,
                            error: true,
                            content: "No response from the agent daemon. Is scripts/unityagentd.py running?"
                        })
                    }
                }
            }
        }
    }

    Timer {
        id: testTimeout
        interval: 45000
        repeat: false
        onTriggered: {
            if (root.testRunning) {
                root.testRunning = false
                root.testResult = "Timed out waiting for the provider."
            }
        }
    }

    // The weekly check runs on a slow timer and is also nudged when the shell
    // starts or the setting is turned back on. `lastUpdateCheck` lives in the
    // agent's state file, so restarting the shell does not trigger it early.
    Timer {
        id: weeklyUpdateTimer
        interval: 6 * 60 * 60 * 1000
        repeat: true
        running: root.enabled && Config.unityAgent.weeklyUpdates
        onTriggered: root.maybeWeeklyUpdate()
    }

    Timer {
        id: weeklyUpdateBoot
        interval: 25000
        repeat: false
        running: root.enabled && Config.unityAgent.weeklyUpdates
        onTriggered: root.maybeWeeklyUpdate()
    }

    Connections {
        target: root
        function onSettingsLoadedChanged() {
            if (root.settingsLoaded)
                root.maybeWeeklyUpdate();
        }
    }

    Timer {
        id: updateCheckTimeout
        interval: 60000
        repeat: false
        running: root.updateCheckRunning
        onTriggered: {
            if (!root.updateCheckRunning)
                return;
            updateCheck.running = false;
            root.updateCheckRunning = false;
            root.updateSummary = "Check timed out";
        }
    }

    Process {
        id: updateCheck
        running: false
        stdout: StdioCollector {
            id: updateOut
            onStreamFinished: root.finishUpdateCheck(text)
        }
        stderr: StdioCollector {
            waitForEnd: true
        }
        onExited: (code, status) => {
            // A failed check must not block the next attempt forever.
            if (root.updateCheckRunning && code !== 0 && updateOut.text.length === 0)
                root.finishUpdateCheck("");
        }
    }

    Timer {
        id: saveHistoryTimer
        interval: 350
        repeat: false
        onTriggered: root.saveHistory()
    }

    Timer {
        id: saveSettingsTimer
        interval: 350
        repeat: false
        onTriggered: root.saveSettings()
    }

    FileView {
        id: historyFile
        path: root.historyPath
        blockLoading: true
        printErrors: false
        onLoaded: root.loadHistory(text())
        onLoadFailed: root.loadHistory("")
        onSaved: Quickshell.execDetached(["chmod", "600", root.historyPath])
        onSaveFailed: error => console.warn("[UnityAgent] history save failed:", error)
    }

    FileView {
        id: settingsFile
        path: root.settingsPath
        blockLoading: true
        printErrors: false
        onLoaded: root.loadSettings(text())
        onLoadFailed: root.loadSettings("")
        onSaved: Quickshell.execDetached(["chmod", "600", root.settingsPath])
        onSaveFailed: error => console.warn("[UnityAgent] settings save failed:", error)
    }

    // The machine description shipped with the shell. Watch it so edits take
    // effect on the next request without restarting the shell.
    FileView {
        id: contextFile
        path: Qt.resolvedUrl("../assets/agent-context.md")
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.agentContext = text()
        onLoadFailed: error => {
            root.agentContext = "";
            console.warn("[UnityAgent] could not load the machine context:", error);
        }
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", stateDir])
        historyFile.reload()
        settingsFile.reload()
        contextFile.reload()
    }
}
