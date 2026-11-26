pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Background watcher for machine errors: failed systemd units and application
// crashes recorded by systemd-coredump.
//
// When something new appears it posts a notification with a "Fix with AI"
// button. Choosing it hands the details to HexinAgent, which opens the chat
// with a ready-made prompt (nothing runs until the user approves it).
//
// Only runs while HexinAgent and Settings > HexinAgent > System errors are
// both on. The first poll after startup (or after turning the switch on) only
// records a baseline, so old failures are never replayed as new.
Singleton {
    id: root

    readonly property bool watching: Config.hexinAgent.enabled && Config.hexinAgent.systemErrors
    readonly property int maxErrors: 25
    readonly property string stateDir: {
        const base = Quickshell.env("XDG_STATE_HOME");
        const home = Quickshell.env("HOME") || "";
        return (base && base.length ? base : home + "/.local/state") + "/hexin";
    }
    readonly property string statePath: stateDir + "/system-errors.json"

    property var errors: []        // newest first: { id, kind, title, body, prompt, time }
    property var knownUnits: ({})  // "system:<unit>" / "user:<unit>" -> true
    property var knownCores: ({})  // crash key -> true
    property bool systemSeeded: false
    property bool userSeeded: false
    property bool coreSeeded: false

    function refresh() {
        if (!watching)
            return;
        if (!unitsProc.running)
            unitsProc.running = true;
        if (!userUnitsProc.running)
            userUnitsProc.running = true;
        if (!coreProc.running)
            coreProc.running = true;
    }

    function find(id) {
        for (const e of errors) {
            if (e.id === id)
                return e;
        }
        return null;
    }

    // Reports outlive a shell reload: the notification stays on screen, so its
    // button must still find the prompt after a config reload. Kept in the
    // state dir, never in the settings file.
    function restore(text) {
        try {
            const list = JSON.parse(text || "[]");
            if (!Array.isArray(list))
                return;
            // Keep anything detected before the file finished loading.
            const ids = {};
            for (const e of errors)
                ids[e.id] = true;
            const merged = errors.concat(list.filter(e => !ids[e.id]));
            errors = merged.slice(0, maxErrors);
        } catch (e) {
            // A truncated file is not worth reporting; it will be rewritten on
            // the next error.
        }
    }

    function save() {
        store.setText(JSON.stringify(errors));
    }

    // Called from the notification's Fix with AI button via IPC.
    function fix(id) {
        const err = find(id);
        if (!err) {
            Notifs.notify("System error", "That report has expired. Open HexinAgent and describe what happened.", "dialog-information");
            return;
        }
        HexinAgent.fixSystemError(err);
    }

    function addError(info) {
        const err = {
            id: "e" + Date.now().toString(36) + Math.random().toString(36).slice(2, 5),
            kind: info.kind,
            title: info.title,
            body: info.body,
            prompt: info.prompt,
            time: Date.now()
        };
        errors = [err, ...errors].slice(0, maxErrors);
        save();
        console.log("[SystemErrors] " + err.title + (info.notice ? " (notified)" : ""));
        if (info.notice)
            Notifs.notifyAction(err.title, err.body, info.icon || "dialog-error", "Fix with AI", "fix", "qs ipc -c hexin call systemerrors fix " + err.id);
    }

    // ── failed units ────────────────────────────────────────────────
    function parseUnits(json, scope) {
        let items = [];
        try {
            items = JSON.parse(json || "[]");
        } catch (e) {
            return;
        }
        if (!Array.isArray(items))
            return;

        const seeded = scope === "user" ? root.userSeeded : root.systemSeeded;
        const now = {};
        const fresh = [];
        for (const item of items) {
            const unit = String(item.unit || "");
            if (!unit.length)
                continue;
            const key = scope + ":" + unit;
            now[key] = true;
            if (seeded && !root.knownUnits[key])
                fresh.push({
                    unit: unit,
                    description: String(item.description || ""),
                    scope: scope
                });
        }

        // Replace this scope's known set, keeping the other one untouched.
        const known = {};
        for (const key in root.knownUnits) {
            if (!key.startsWith(scope + ":"))
                known[key] = true;
        }
        for (const key in now)
            known[key] = true;
        root.knownUnits = known;

        if (!seeded) {
            if (scope === "user")
                root.userSeeded = true;
            else
                root.systemSeeded = true;
            return;
        }

        for (const unit of fresh) {
            const where = unit.scope === "user" ? "user service" : "system service";
            root.addError({
                kind: "unit",
                title: unit.unit + " failed",
                body: (unit.description || "Service failed") + " · Fix with AI can diagnose it",
                icon: "dialog-error",
                notice: true,
                prompt: "A " + where + " failed on this machine.\n\n"
                    + "Unit: " + unit.unit + " (" + unit.scope + ")\n"
                    + "Description: " + (unit.description || "(none)") + "\n"
                    + "State: failed\n\n"
                    + "Please diagnose it. Start with `" + (unit.scope === "user" ? "systemctl --user status " + unit.unit : "systemctl status " + unit.unit) + "` "
                    + "and `" + (unit.scope === "user" ? "journalctl --user -u " + unit.unit : "journalctl -u " + unit.unit) + " -n 50`, "
                    + "explain what you found, and only propose a change after I approve it."
            });
        }
    }

    // ── coredumps (application crashes) ─────────────────────────────
    function parseCoredumps(text) {
        const lines = String(text || "").split("\n");
        const rows = [];
        for (const raw of lines) {
            const line = raw.trim();
            if (!line.length || line.startsWith("TIME") || line.startsWith("No coredumps"))
                continue;
            const f = line.split(/\s+/);
            if (f.length < 10)
                continue;

            // TIME  PID  UID  GID  SIG  COREFILE  EXE  SIZE
            // The timezone token is absent in some locales.
            let i = 3;
            if (!/^\d+$/.test(f[i]))
                i += 1;
            if (!/^\d+$/.test(f[i] || ""))
                continue;

            const pid = f[i];
            const signal = f[i + 3] || "";
            const corefile = f[i + 4] || "";
            const rest = f.slice(i + 5);
            if (rest.length < 1)
                continue;
            const exe = (rest.length > 1 ? rest.slice(0, -1) : rest).join(" ");
            if (exe.length < 2)
                continue;

            rows.push({
                key: f[1] + " " + f[2] + " " + pid + " " + exe,
                time: f.slice(0, i).join(" "),
                pid: pid,
                signal: signal,
                corefile: corefile,
                exe: exe
            });
        }

        const seeded = root.coreSeeded;
        root.coreSeeded = true;

        if (!seeded) {
            const baseline = {};
            for (const row of rows)
                baseline[row.key] = true;
            root.knownCores = baseline;
            return;
        }

        const known = root.knownCores;
        for (const row of rows) {
            if (known[row.key])
                continue;
            known[row.key] = true;
            const name = row.exe.split("/").pop();
            root.addError({
                kind: "crash",
                title: name + " crashed",
                body: row.signal + (row.corefile === "present" ? " · core saved" : "") + " · Fix with AI can diagnose it",
                icon: "dialog-error",
                notice: true,
                prompt: "An application crashed on this machine.\n\n"
                    + "Executable: " + row.exe + "\n"
                    + "Signal: " + row.signal + "\n"
                    + "When: " + row.time + "\n"
                    + "PID: " + row.pid + "\n\n"
                    + "Please diagnose it. Start with `coredumpctl info " + row.pid + "` and the application's own logs, "
                    + "explain what you found, and only propose a change after I approve it."
            });
        }

        // Keep the seen set bounded if the machine crashes a lot.
        if (Object.keys(known).length > 400) {
            const recent = {};
            for (const row of rows)
                recent[row.key] = true;
            root.knownCores = recent;
        } else {
            root.knownCores = known;
        }
    }

    Timer {
        interval: 30000
        repeat: true
        running: root.watching
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: unitsProc
        command: ["systemctl", "--failed", "-o", "json", "--no-pager"]
        stdout: StdioCollector {
            onStreamFinished: root.parseUnits(text, "system")
        }
    }

    Process {
        id: userUnitsProc
        command: ["systemctl", "--user", "--failed", "-o", "json", "--no-pager"]
        stdout: StdioCollector {
            onStreamFinished: root.parseUnits(text, "user")
        }
    }

    Process {
        id: coreProc
        command: ["coredumpctl", "list", "--no-pager", "--reverse"]
        stdout: StdioCollector {
            onStreamFinished: root.parseCoredumps(text)
        }
    }

    FileView {
        id: store
        path: root.statePath
        printErrors: false
        onLoaded: root.restore(text())
    }
}
