pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Live Hyprland option control for the Settings app.
//
// Two things happen when an option changes:
//   1. the value is pushed to the running session with
//          hyprctl eval 'hl.config({ ... })'
//      A Lua-driven Hyprland *refuses* `hyprctl keyword` ("keyword can't work
//      with non-legacy parsers. Use eval."), so the Lua call is the only way in.
//   2. the values are written to
//          ~/.config/hypr/hexin/settings.lua
//      That is the one file the app owns. ~/.config/hypr/hyprland.lua loads it,
//      so the values survive a reload and the next login on their own.
//
// Nothing is applied unless Config.hyprland.manage is on, so first launch never
// stomps your existing Hyprland settings.
Singleton {
    id: root

    /// True when we're running inside a live Hyprland session.
    readonly property bool active: {
        const s = Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE");
        return s !== null && s.length > 0;
    }

    // ~/.config/hypr/hexin/settings.lua — loaded by ~/.config/hypr/hyprland.lua
    readonly property string confPath: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/hypr/hexin/settings.lua"

    /// Inactive window border — the muted slate from the UnityOS palette.
    readonly property string inactiveBorder: "rgba(44464f77)"
    /// The active border used when accent borders are switched off. Matches
    /// the fallback in ~/.config/hypr/hexin/50-look-and-feel.lua.
    readonly property string defaultActiveBorder: "rgba(f97316ff)"

    // option -> where it lives inside the hl.config() table
    readonly property var optionPaths: ({
            gaps_in: ["general", "gaps_in"],
            gaps_out: ["general", "gaps_out"],
            border_size: ["general", "border_size"],
            rounding: ["decoration", "rounding"],
            animations: ["animations", "enabled"],
            activeOpacity: ["decoration", "active_opacity"],
            inactiveOpacity: ["decoration", "inactive_opacity"],
            blur: ["decoration", "blur", "enabled"],
            blurSize: ["decoration", "blur", "size"],
            blurPasses: ["decoration", "blur", "passes"],
            shadow: ["decoration", "shadow", "enabled"],
            shadowRange: ["decoration", "shadow", "range"],
            shadowPower: ["decoration", "shadow", "render_power"]
        })

    /// Last values read back from the compositor (see refresh()).
    property var state: ({})

    // ── applying ─────────────────────────────────────────────────────
    function rgba(c) {
        const h = x => Math.round(Math.max(0, Math.min(1, x)) * 255).toString(16).padStart(2, "0");
        return "rgba(" + h(c.r) + h(c.g) + h(c.b) + h(c.a) + ")";
    }

    /// The active/inactive border colours, as an hl.config() table.
    function accentBorders() {
        return {
            general: {
                col: {
                    active_border: rgba(Theme.accent),
                    inactive_border: root.inactiveBorder
                }
            }
        };
    }

    /// Undo accent borders live. Previously switching the toggle off only
    /// rewrote settings.lua, so the running session kept the accent colour
    /// until the next Hyprland reload.
    function plainBorders() {
        return {
            general: {
                col: {
                    active_border: root.defaultActiveBorder,
                    inactive_border: root.inactiveBorder
                }
            }
        };
    }

    // ── Lua serialisation ────────────────────────────────────────────
    function luaValue(v) {
        if (typeof v === "boolean")
            return v ? "true" : "false";
        if (typeof v === "number")
            return String(v);
        return JSON.stringify(String(v));
    }

    function toLua(obj, depth) {
        const pad = "    ".repeat(depth);
        const inner = "    ".repeat(depth + 1);
        const rows = [];
        for (const k of Object.keys(obj)) {
            const v = obj[k];
            if (v !== null && typeof v === "object")
                rows.push(inner + k + " = " + toLua(v, depth + 1));
            else
                rows.push(inner + k + " = " + luaValue(v));
        }
        return "{\n" + rows.join(",\n") + "\n" + pad + "}";
    }

    /// nest(["general", "gaps_in"], 5)  ->  { general: { gaps_in: 5 } }
    function nest(path, value) {
        const root = {};
        let cur = root;
        for (let i = 0; i < path.length - 1; i++) {
            cur[path[i]] = {};
            cur = cur[path[i]];
        }
        cur[path[path.length - 1]] = value;
        return root;
    }

    function evalExpr(obj) {
        return "hl.config(" + toLua(obj, 0) + ")";
    }

    function apply(key, value) {
        if (!Config.hyprland.manage)
            return;
        if (active && optionPaths[key] !== undefined)
            enqueue(evalExpr(nest(optionPaths[key], value)));
        if (key === "accentBorders")
            enqueue(evalExpr(value ? accentBorders() : plainBorders()));
        writeConf();
    }

    function applyRuntime(obj) {
        if (!Config.hyprland.manage || !active)
            return;
        if (obj && typeof obj === "object")
            enqueue(evalExpr(obj));
    }

    function configTable() {
        const h = Config.hyprland;
        const t = {};
        t.general = {
            gaps_in: h.gaps_in,
            gaps_out: h.gaps_out,
            border_size: h.border_size
        };
        if (h.accentBorders)
            t.general.col = {
                active_border: rgba(Theme.accent),
                inactive_border: root.inactiveBorder
            };
        t.decoration = {
            rounding: h.rounding,
            active_opacity: h.activeOpacity,
            inactive_opacity: h.inactiveOpacity,
            blur: {
                enabled: h.blur,
                size: h.blurSize,
                passes: h.blurPasses
            },
            shadow: {
                enabled: h.shadow,
                range: h.shadowRange,
                render_power: h.shadowPower
            }
        };
        t.animations = { enabled: h.animations };
        return t;
    }

    function reapply() {
        applyRuntime(configTable());
        writeConf();
    }

    function applyBorders() {
        if (!Config.hyprland.manage)
            return;
        enqueue(evalExpr(Config.hyprland.accentBorders ? accentBorders() : plainBorders()));
        writeConf(); // keep settings.lua's border colours in step with the theme
    }

    // Keep the window borders in step with the theme. Nothing called
    // applyBorders() before, so "Accent-coloured window borders" only ever
    // fired once — the moment the toggle was switched on.
    Connections {
        target: Theme
        function onAccentChanged() {
            root.applyBorders();
        }
    }

    // ── hyprctl eval queue ───────────────────────────────────────────
    //
    // The busy flag is ours, not hypr.running: assigning hypr.command while a
    // start is still pending silently replaces it, and hypr.running reads back
    // as false until the process has actually spawned — so gating on it drops
    // every command but the last when several arrive in the same tick (which is
    // exactly what a slider drag does).
    property var _chain: []
    property bool _busy: false

    function enqueue(expr) {
        if (!active)
            return;
        _chain.push(expr);
        pump();
    }

    function pump() {
        if (_chain.length === 0 || _busy)
            return;
        hypr.command = ["hyprctl", "eval", _chain.shift()];
        _busy = true;
        hypr.running = true;
    }

    Process {
        id: hypr
        running: false
        stdout: StdioCollector {
            waitForEnd: true
        }
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const t = this.text.trim();
                if (t !== "")
                    console.warn("hexin: hyprctl eval failed:", t);
            }
        }
        onExited: (code, status) => {
            root._busy = false;
            root.pump();
        }
    }

    // ── read current values ──────────────────────────────────────────
    function refresh() {
        if (!active)
            return;
        _queue = [
            { key: "gaps_in", args: ["getoption", "general:gaps_in"] },
            { key: "gaps_out", args: ["getoption", "general:gaps_out"] },
            { key: "border_size", args: ["getoption", "general:border_size"] },
            { key: "rounding", args: ["getoption", "decoration:rounding"] },
            { key: "animations", args: ["getoption", "animations:enabled"] }
        ];
        _result = ({});
        _current = null;
        fetchPump();
    }

    property var _queue: []
    property var _result: ({})
    property var _current: null

    function fetchPump() {
        if (_queue.length === 0) {
            state = _result;
            return;
        }
        if (fetchProc.running)
            return;
        _current = _queue.shift();
        fetchProc.command = _current.args;
        fetchProc.running = true;
    }

    function fetchStep(text) {
        if (!_current)
            return;
        try {
            const o = JSON.parse(text.trim());
            const d = o.data || o;
            if (_current.key === "animations")
                _result.animations = (d.str === "true" || d.str === "1" || d.int === 1);
            else
                _result[_current.key] = d.int !== undefined ? d.int : d;
        } catch (e) {
            // leave the default alone
        }
    }

    Process {
        id: fetchProc
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.fetchStep(this.text)
        }
        onExited: root.fetchPump()
    }

    /// Seed the Settings sliders from the running compositor.
    function importFromCompositor() {
        if (!active)
            return;
        refreshPending = true;
        refresh();
    }

    property bool refreshPending: false

    onStateChanged: {
        if (!refreshPending)
            return;
        refreshPending = false;
        const s = root.state;
        if (s.gaps_in !== undefined)
            Config.hyprland.gaps_in = s.gaps_in;
        if (s.gaps_out !== undefined)
            Config.hyprland.gaps_out = s.gaps_out;
        if (s.border_size !== undefined)
            Config.hyprland.border_size = s.border_size;
        if (s.rounding !== undefined)
            Config.hyprland.rounding = s.rounding;
        if (s.animations !== undefined)
            Config.hyprland.animations = s.animations;
    }

    // ── settings file (the one file the app owns) ────────────────────
    function confContent() {
        const h = Config.hyprland;
        const o = {
            gaps_in: h.gaps_in,
            gaps_out: h.gaps_out,
            border_size: h.border_size,
            rounding: h.rounding,
            animations: h.animations,
            accent_borders: h.accentBorders,
            active_border: h.accentBorders ? rgba(Theme.accent) : root.defaultActiveBorder,
            inactive_border: root.inactiveBorder,
            active_opacity: h.activeOpacity,
            inactive_opacity: h.inactiveOpacity,
            blur: h.blur,
            blur_size: h.blurSize,
            blur_passes: h.blurPasses,
            shadow: h.shadow,
            shadow_range: h.shadowRange,
            shadow_power: h.shadowPower
        };

        const L = [];
        L.push("-- =====================================================================");
        L.push("-- hexin — settings the Settings app owns (generated)");
        L.push("--");
        L.push("-- Rewritten whenever a control on Settings > Hyprland moves, so hand");
        L.push("-- edits here are temporary. Loaded for you by hyprland.lua.");
        L.push("-- =====================================================================");
        L.push("return " + toLua(o, 0));
        L.push("");
        return L.join("\n");
    }

    property string _confPending: ""

    function writeConf() {
        _confPending = confContent();
        if (!confWriter.running)
            startConfWrite();
    }

    function startConfWrite() {
        if (_confPending === "")
            return;
        confWriter.stdinEnabled = true; // re-arm stdin for a fresh run
        confWriter.running = true;
    }

    function flushConf() {
        if (_confPending === "")
            return;
        const data = _confPending;
        _confPending = "";
        confWriter.write(data + "\n");
        // Close stdin, or `cat` waits for EOF forever and the `mv` never runs.
        // (It used to sit there after the very first write, so only one mirror
        // write ever landed.)
        confWriter.stdinEnabled = false;
    }

    Process {
        id: confWriter
        // Write to a temp file and rename, so a reader never sees a half file.
        command: ["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && cat > \"$1.tmp\" && mv \"$1.tmp\" \"$1\"", "sh", root.confPath]
        running: false
        stdinEnabled: true
        stdout: StdioCollector {
            waitForEnd: true
        }
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const t = this.text.trim();
                if (t !== "")
                    console.warn("hexin: writing " + root.confPath + " failed:", t);
            }
        }
        onStarted: root.flushConf()
        onExited: root.startConfWrite()
    }
}
