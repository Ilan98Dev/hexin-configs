pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Live keybind list for the SUPER + K cheatsheet.
//
// The source of truth is ~/.config/hypr/hyprunity/90-keybinds.lua. A helper
// script next to it (keybinds-dump.lua) runs the real file with a stubbed
// Hyprland API and prints JSON, so loops and variables (mainMod, PROGRAMS,
// SHOT) resolve exactly like they do in the live config. FileView watches the
// source, so saving it refreshes the list without reloading the shell.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string sourcePath: home + "/.config/hypr/hyprunity/90-keybinds.lua"
    readonly property string dumpPath: home + "/.config/hypr/hyprunity/keybinds-dump.lua"

    property var binds: []
    property bool loaded: false
    property string error: ""
    property bool pending: false

    function refresh() {
        if (dump.running) {
            pending = true;
            return;
        }
        pending = false;
        error = "";
        dump.running = true;
    }

    function parse(json) {
        try {
            const data = JSON.parse(json);
            const list = Array.isArray(data.binds) ? data.binds : [];
            binds = list.map(normalise);
            error = data.error || "";
            loaded = true;
        } catch (e) {
            error = "Could not read the keybind list.";
        }
    }

    // ───────────── presentation ─────────────
    function normalise(raw) {
        const keys = String(raw.keys || "").trim();
        const kind = String(raw.kind || "");
        const args = Array.isArray(raw.args) ? raw.args : [];
        const comment = String(raw.comment || "").trim();
        const section = String(raw.section || "").trim();
        const label = describe(kind, args);
        const hint = hintFor(kind, args, comment);
        const command = commandOf(args);
        return {
            keys: keys,
            caps: formatCaps(keys),
            label: label,
            hint: hint,
            section: shortSection(section),
            sectionRaw: section,
            comment: comment,
            line: raw.line || 0,
            search: (keys + " " + label + " " + hint + " " + section + " " + comment + " " + command).toLowerCase()
        };
    }

    function formatCaps(keys) {
        if (!keys.length)
            return [];
        const labels = {
            "RETURN": "ENTER",
            "ESCAPE": "ESC",
            "comma": ",",
            "left": "←",
            "right": "→",
            "up": "↑",
            "down": "↓",
            "mouse:272": "LMB",
            "mouse:273": "RMB",
            "mouse_down": "SCROLL ↓",
            "mouse_up": "SCROLL ↑",
            "XF86AudioRaiseVolume": "VOL +",
            "XF86AudioLowerVolume": "VOL −",
            "XF86AudioMute": "MUTE",
            "XF86AudioMicMute": "MIC MUTE",
            "XF86MonBrightnessUp": "BRIGHT +",
            "XF86MonBrightnessDown": "BRIGHT −",
            "XF86AudioPlay": "PLAY",
            "XF86AudioPause": "PAUSE",
            "XF86AudioNext": "NEXT",
            "XF86AudioPrev": "PREV"
        };
        return keys.split(" + ").map(token => labels[token] || token);
    }

    function commandOf(args) {
        const first = args.length ? args[0] : "";
        return typeof first === "string" ? first : "";
    }

    function describe(kind, args) {
        const first = args.length ? args[0] : null;
        const table = first !== null && typeof first === "object" ? first : null;

        if (kind === "dsp.global") {
            const name = String(first || "").replace("quickshell:", "");
            const globals = {
                controlPanel: "Control centre",
                notificationCenter: "Notifications",
                launcher: "App launcher",
                clipboard: "Clipboard history",
                settings: "Settings",
                wallpaper: "Wallpaper switcher",
                unityagent: "UnityAgent",
                dnd: "Do Not Disturb",
                gamemode: "Game mode",
                lock: "Lock screen",
                recordRegion: "Record a region",
                recordFull: "Record full screen",
                keybinds: "Keybind cheatsheet"
            };
            return globals[name] || name || "Shell action";
        }

        if (kind === "dsp.exec_cmd")
            return commandLabel(commandOf(args));

        if (kind === "dsp.window.close")
            return "Close window";
        if (kind === "dsp.window.fullscreen")
            return "Toggle fullscreen";
        if (kind === "dsp.window.float")
            return table && table.action === "toggle" ? "Toggle floating" : "Float window";
        if (kind === "dsp.window.pseudo")
            return "Toggle pseudo-tiling";
        if (kind === "dsp.window.drag")
            return "Move window (drag)";
        if (kind === "dsp.window.resize") {
            if (!table)
                return "Resize window (drag)";
            if (table.x < 0)
                return "Resize left";
            if (table.x > 0)
                return "Resize right";
            if (table.y < 0)
                return "Resize up";
            if (table.y > 0)
                return "Resize down";
            return "Resize window";
        }
        if (kind === "dsp.focus") {
            if (table && table.direction)
                return "Focus " + table.direction;
            if (table && table.workspace !== undefined)
                return "Switch to " + workspaceName(table.workspace);
            return "Focus window";
        }
        if (kind === "dsp.window.move") {
            if (table && table.direction)
                return "Move window " + table.direction;
            if (table && table.workspace !== undefined)
                return "Move window to " + workspaceName(table.workspace);
            return "Move window";
        }
        if (kind === "dsp.workspace.toggle_special")
            return "Toggle " + String(first || "special") + " scratchpad";
        if (kind === "dsp.layout")
            return String(first) === "togglesplit" ? "Toggle split direction" : "Layout: " + String(first);

        return kind.replace("dsp.", "").replace(/\./g, " ") || "Keybind";
    }

    function workspaceName(value) {
        const name = String(value);
        if (name === "e+1")
            return "next workspace";
        if (name === "e-1")
            return "previous workspace";
        if (name.startsWith("special:"))
            return name.slice(8) + " scratchpad";
        return "workspace " + name;
    }

    function commandLabel(command) {
        const c = command.replace(/\s+/g, " ").trim();
        if (!c.length)
            return "Run command";

        if (c.includes("call audio up"))
            return "Volume up";
        if (c.includes("call audio down"))
            return "Volume down";
        if (c.includes("call audio mute"))
            return "Mute";
        if (c.includes("call audio micMute"))
            return "Mute microphone";
        if (c.includes("call brightness up"))
            return "Brightness up";
        if (c.includes("call brightness down"))
            return "Brightness down";
        if (c.includes("call media playPause"))
            return "Play / pause";
        if (c.includes("call media next"))
            return "Next track";
        if (c.includes("call media previous"))
            return "Previous track";
        if (c.includes("call shell reload"))
            return "Reload the shell";
        if (c.includes("hyprpicker"))
            return "Pick a colour";
        if (c.includes("slurp") && c.includes("grim"))
            return "Screenshot a region";
        if (c.includes("grim") && c.includes("wl-copy"))
            return "Screenshot the full screen";

        if (c.startsWith("kitty") || c.startsWith("alacritty") || c.startsWith("foot"))
            return "Terminal";
        if (c === "nautilus" || c.endsWith("/nautilus"))
            return "Files";
        if (c.includes("zen-browser") || c.includes("firefox") || c.includes("chromium"))
            return "Browser";
        if (c.includes("vesktop") || c.includes("discord"))
            return "Messages";
        if (c.includes("spotify"))
            return "Music";

        return "Run: " + (c.length > 42 ? c.slice(0, 40) + "…" : c);
    }

    function hintFor(kind, args, comment) {
        if (kind === "dsp.exec_cmd") {
            const command = commandOf(args).replace(/\s+/g, " ").trim();
            return command.length > 90 ? command.slice(0, 88) + "…" : command;
        }
        const note = comment.replace(/^\[shell\]\s*/i, "").trim();
        if (kind === "dsp.global") {
            // Only show the note when it says something the label does not.
            const label = describe(kind, args).toLowerCase();
            return note.length && !label.includes(note.toLowerCase()) ? note : "";
        }
        return note;
    }

    function shortSection(section) {
        const names = {
            "the shell: hyprunity registers these as global shortcuts": "Shell",
            "applications": "Apps",
            "launcher + clipboard history (hyprunity's own panels)": "Launcher",
            "windows": "Windows",
            "workspaces": "Workspaces",
            "scratchpads (special workspaces)": "Scratchpads",
            "screenshots and tools": "Screenshots",
            "game mode: owned by the shell (toggles animations/blur/shadows/gaps)": "Game mode",
            "media, volume and brightness": "Media"
        };
        if (names[section])
            return names[section];
        const cleaned = section.split(":")[0].replace(/\(.*?\)/g, "").trim();
        return cleaned.length ? cleaned : "Other";
    }

    // ───────────── data ─────────────
    Process {
        id: dump
        command: ["lua", root.dumpPath]

        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const message = text.trim();
                if (message.length)
                    root.error = message;
            }
        }

        onExited: (code, status) => {
            if (code !== 0 && root.error.length === 0)
                root.error = "Could not read keybinds (lua exited with " + code + ").";
            if (root.pending) {
                root.pending = false;
                root.refresh();
            }
        }
    }

    // Saving 90-keybinds.lua is enough; no shell reload needed.
    FileView {
        id: sourceFile
        path: root.sourcePath
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: {
            reload();
            root.refresh();
        }
        onLoadFailed: error => root.error = "Could not watch 90-keybinds.lua."
    }

    // A fresh read every time the cheatsheet opens, plus the first load.
    Connections {
        target: Panels
        function onActiveChanged() {
            if (Panels.active === "keybinds")
                root.refresh();
        }
    }

    Component.onCompleted: refresh()
}
