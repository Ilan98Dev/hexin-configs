pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Shell commands and runtime toggles (night light, caffeine).
Singleton {
    id: root

    property bool nightLight: false
    property bool caffeine: false
    property bool gameMode: false
    property var _gamePrev: ({})

    function sh(cmd) {
        if (cmd && cmd.trim() !== "")
            Quickshell.execDetached(["sh", "-c", cmd]);
    }

    function notify(title, body, icon) {
        Notifs.notify(title, body, icon);
    }

    function launcher() {
        const cmd = Config.apps.launcher;
        if (cmd && cmd.trim() !== "")
            sh(cmd);
        else
            Panels.toggle("launcher");
    }
    function clipboard() {
        Panels.toggle("clipboard");
    }
    function terminal() {
        sh(Config.apps.terminal);
    }
    function lock() {
        if (Config.apps.lock && Config.apps.lock.trim() !== "")
            sh(Config.apps.lock);
        else
            Lock.lock();
    }
    function logout() {
        sh(Config.apps.logout);
    }
    function suspend() {
        sh(Config.apps.suspend);
    }
    function reboot() {
        sh(Config.apps.reboot);
    }
    function shutdown() {
        sh(Config.apps.shutdown);
    }

    // Give the panel time to close before grabbing the screen. When no panel
    // is open (e.g. the IPC/keybind path) start straight away.
    function screenshot() {
        const panelWasOpen = Panels.active !== "";
        Panels.close();
        if (panelWasOpen)
            shotTimer.start();
        else
            startScreenshot();
    }

    function startScreenshot() {
        const cmd = Config.apps.screenshot;
        if (!cmd || cmd.trim() === "")
            return;
        // Give the command a real stdin. Quickshell hands children a pipe, and
        // slurp reads boxes from a piped stdin instead of opening its selection
        // UI — which made the control-centre button hang with no overlay.
        shotProc.command = ["sh", "-c", "exec 0</dev/null; " + cmd];
        shotProc.running = true;
    }

    Timer {
        id: shotTimer
        interval: 350
        onTriggered: root.startScreenshot()
    }

    // Notify only once the screenshot command has actually finished. The old
    // execDetached + immediate notify fired while slurp was still open, so the
    // toast appeared before the picture was taken.
    Process {
        id: shotProc
        onExited: (code, status) => {
            if (code === 0)
                Notifs.notify("Screenshot", "Screenshot captured", "camera");
        }
    }

    // hyprsunset runs for as long as night light is on.
    Process {
        running: root.nightLight
        command: ["hyprsunset", "-t", String(Config.controlPanel.nightLightTemp)]
    }

    // A systemd idle inhibitor lives as long as this process does.
    Process {
        running: root.caffeine
        command: ["systemd-inhibit", "--what=idle", "--who=Quickshell", "--why=Caffeine mode", "--mode=block", "sleep", "infinity"]
    }

    // The property *is* the state: every caller (tile, shortcut, IPC) assigns
    // it and this handler does the work. Change signals only fire on a real
    // change, so re-assigning the current value stays a no-op.
    onGameModeChanged: applyGameMode()

    // Thin wrapper kept for imperative callers.
    function setGameMode(on) {
        gameMode = on;
    }

    function applyGameMode() {
        if (gameMode) {
            _gamePrev = {
                animations: Config.hyprland.animations,
                blur: Config.hyprland.blur,
                shadow: Config.hyprland.shadow,
                rounding: Config.hyprland.rounding,
                gaps_in: Config.hyprland.gaps_in,
                gaps_out: Config.hyprland.gaps_out,
                border_size: Config.hyprland.border_size,
                activeOpacity: Config.hyprland.activeOpacity,
                inactiveOpacity: Config.hyprland.inactiveOpacity
            };
            // Pause Quickshell animations for this session only. Changing
            // Config.appearance.animations here used to persist: a crash or
            // logout while game mode was on left animations disabled for good.
            Theme.motionPaused = true;
            Hypr.applyRuntime({
                animations: { enabled: false },
                decoration: {
                    rounding: 0,
                    active_opacity: 1.0,
                    inactive_opacity: 1.0,
                    blur: { enabled: false },
                    shadow: { enabled: false }
                },
                general: { gaps_in: 0, gaps_out: 0, border_size: 1 }
            });
            Notifs.notify("Game mode", "Desktop chrome stripped for gaming", "gamepad");
        } else {
            // Restore the saved values, falling back to whatever Settings
            // currently holds; Hypr.reapply() then pushes the full table so a
            // cold start (no snapshot) still lands on the configured state.
            const p = _gamePrev || {};
            Config.hyprland.animations = p.animations !== undefined ? p.animations : Config.hyprland.animations;
            Config.hyprland.blur = p.blur !== undefined ? p.blur : Config.hyprland.blur;
            Config.hyprland.shadow = p.shadow !== undefined ? p.shadow : Config.hyprland.shadow;
            Config.hyprland.rounding = p.rounding !== undefined ? p.rounding : Config.hyprland.rounding;
            Config.hyprland.gaps_in = p.gaps_in !== undefined ? p.gaps_in : Config.hyprland.gaps_in;
            Config.hyprland.gaps_out = p.gaps_out !== undefined ? p.gaps_out : Config.hyprland.gaps_out;
            Config.hyprland.border_size = p.border_size !== undefined ? p.border_size : Config.hyprland.border_size;
            Config.hyprland.activeOpacity = p.activeOpacity !== undefined ? p.activeOpacity : Config.hyprland.activeOpacity;
            Config.hyprland.inactiveOpacity = p.inactiveOpacity !== undefined ? p.inactiveOpacity : Config.hyprland.inactiveOpacity;
            Theme.motionPaused = false;
            Hypr.reapply();
            Notifs.notify("Game mode", "Previous settings restored", "gamepad");
            _gamePrev = {};
        }
    }
}
