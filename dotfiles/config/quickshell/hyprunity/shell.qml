//@ pragma UseQApplication

//@ pragma Env QS_NO_RELOAD_POPUP=1

// =====================================================================
//  hyprunity — a Quickshell desktop shell for UnityOS / Hyprland.
//
//  Surfaces
//    Bar                top/bottom bar, one per monitor
//    Wallpaper          background layer (default image / yours / none)
//    PanelHost          control centre, notifications, calendar, launcher,
//                       clipboard history + wallpaper picker overlay
//    NotifPopups        notification toasts
//    Osd                volume / brightness on-screen display
//    SettingsApp        floating settings window
//    WlSessionLock      built-in lock screen (PAM)
//
//  Everything is driven from the bar or over IPC:
//      qs ipc call panels toggle control
//      qs ipc call panels toggle launcher
//      qs ipc call settings toggle
//      qs ipc call shell lock            (compat with earlier hyprunity binds)
// =====================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.services

import qs.modules.bar
import qs.modules.notifications
import qs.modules.panels
import qs.modules.osd
import qs.modules.settings
import qs.modules.wallpaper
import qs.modules.lock
import qs.modules.welcome
import qs.modules.unityagent

ShellRoot {
    Bar {}
    Variants {
        model: Quickshell.screens
        Wallpaper {}
    }
    UnityAgentWindow {}
    AgentNeon {}
    NotifPopups {}
    PanelHost {}
    Osd {}
    SettingsApp {}
    Welcome {}

    // ───────────── built-in session lock ─────────────
    WlSessionLock {
        id: sessionLock
        locked: Lock.locked

        WlSessionLockSurface {
            color: Theme.base

            LockScreen {
                anchors.fill: parent
            }
        }
    }

    // Make sure the notification daemon and services are instantiated early.
    // Theme + GlobalTheme must load so matugen-on-wallpaper-change is armed.
    Component.onCompleted: {
        Notifs.count;
        Config.bar.enabled;
        Theme.appearancePreset;
        GlobalTheme.appearancePreset;
        // Singletons are lazy: touch the watcher so it starts polling at boot
        // instead of waiting for the first IPC call.
        SystemErrors.refresh();
    }

    // ───────────── IPC:  qs ipc call <target> <function> [args] ─────────
    IpcHandler {
        target: "panels"
        function toggle(name: string): void {
            Panels.toggle(name);
        }
        function open(name: string): void {
            Panels.open(name);
        }
        function close(): void {
            Panels.close();
        }
    }

    IpcHandler {
        target: "settings"
        function toggle(): void {
            Panels.settingsOpen = !Panels.settingsOpen;
        }
        function open(): void {
            Panels.settingsOpen = true;
        }
    }

    // Clicked from the "Fix with AI" notification button.
    IpcHandler {
        target: "systemerrors"
        function fix(id: string): void {
            SystemErrors.fix(id);
        }
        function refresh(): void {
            SystemErrors.refresh();
        }
    }

    IpcHandler {
        target: "welcome"
        function open(): void {
            Onboarding.show();
        }
        function close(): void {
            Onboarding.close();
        }
        function dismiss(): void {
            Onboarding.dismiss();
        }
        function reset(): void {
            Onboarding.reset();
        }
    }

    IpcHandler {
        target: "audio"
        function up(): void {
            Audio.step(0.05);
        }
        function down(): void {
            Audio.step(-0.05);
        }
        function mute(): void {
            Audio.toggleMute();
        }
        function micMute(): void {
            Audio.toggleMicMute();
        }
    }

    IpcHandler {
        target: "brightness"
        function up(): void {
            Brightness.step(0.05);
        }
        function down(): void {
            Brightness.step(-0.05);
        }
    }

    IpcHandler {
        target: "notifications"
        function toggleDnd(): void {
            Notifs.toggleDnd();
        }
        function clear(): void {
            Notifs.clearAll();
        }
    }

    IpcHandler {
        target: "media"
        function playPause(): void {
            if (Media.player && Media.player.canTogglePlaying)
                Media.player.togglePlaying();
        }
        function next(): void {
            if (Media.player && Media.player.canGoNext)
                Media.player.next();
        }
        function previous(): void {
            if (Media.player && Media.player.canGoPrevious)
                Media.player.previous();
        }
    }

    // Backwards-compatible target for the binds shipped with the first
    // hyprunity builds (`qs -c hyprunity ipc call shell toggle launcher`).
    IpcHandler {
        target: "shell"
        function toggle(panel: string): void {
            if (panel === "launcher")
                Actions.launcher();
            else if (panel === "power")
                Panels.toggle("control");
            else if (panel === "settings")
                Panels.settingsOpen = !Panels.settingsOpen;
            else
                Panels.toggle(panel);
        }
        function open(panel: string): void {
            if (panel === "settings")
                Panels.settingsOpen = true;
            else if (panel === "power")
                Panels.open("control");
            else if (panel === "launcher")
                Actions.launcher();
            else
                Panels.open(panel);
        }
        function close(): void {
            Panels.close();
        }
        function lock(): void {
            Lock.lock();
        }
        function reload(): void {
            Quickshell.reload(false);
        }
    }

    IpcHandler {
        target: "actions"
        function notify(title: string, body: string): void {
            Notifs.notify(title, body || "");
        }
        function gameMode(): void {
            Actions.gameMode = !Actions.gameMode;
        }
        function screenshot(): void {
            Actions.screenshot();
        }
        function caffeine(): void {
            Actions.caffeine = !Actions.caffeine;
            Notifs.notify(Actions.caffeine ? "Caffeine" : "Caffeine", Actions.caffeine ? "Keeping the system awake" : "Caffeine off", "coffee");
        }
        function nightLight(): void {
            Actions.nightLight = !Actions.nightLight;
            Notifs.notify(Actions.nightLight ? "Night Light" : "Night Light", Actions.nightLight ? "Night Light enabled" : "Night Light disabled", "moon");
        }
    }

    IpcHandler {
        target: "unityagent"
        function toggle(): void {
            UnityAgent.toggle();
        }
        function open(): void {
            UnityAgent.open();
        }
        function hide(): void {
            UnityAgent.close();
        }
        function settings(): void {
            UnityAgent.open();
            UnityAgent.showSettings();
        }
        function chat(): void {
            UnityAgent.open();
        }
        function newChat(): void {
            UnityAgent.open();
            UnityAgent.newChat();
        }
        function ask(text: string): void {
            UnityAgent.open();
            UnityAgent.sendMessage(text);
        }
        function approve(callId: string, approved: bool): void {
            UnityAgent.approveTool(callId, approved);
        }
        function stop(): void {
            UnityAgent.stop();
        }
        function setKey(provider: string, key: string): void {
            UnityAgent.setKey(provider, key);
        }
        function setProvider(provider: string): void {
            UnityAgent.setProvider(provider);
        }
        function setModel(model: string): void {
            UnityAgent.setModel(model);
        }
        function setBaseUrl(url: string): void {
            UnityAgent.setBaseUrl(url);
        }
        function testConnection(): void {
            UnityAgent.testConnection();
        }
        function removeCustomModel(model: string): void {
            UnityAgent.removeCustomModel(model);
        }
    }

    IpcHandler {
        target: "recorder"
        function fullscreen(): void {
            Recorder.startFull();
        }
        function region(): void {
            Recorder.startRegion();
        }
        function stop(): void {
            Recorder.stop();
        }
        function toggle(): void {
            Recorder.startDefault();
        }
    }

    // ───────────── Hyprland global shortcuts ─────────────
    // hyprland.lua:  hl.bind("SUPER + A", hl.dsp.global("quickshell:controlPanel"))
    GlobalShortcut {
        name: "controlPanel"
        description: "Toggle the control panel"
        onPressed: Panels.toggle("control")
    }
    GlobalShortcut {
        name: "notificationCenter"
        description: "Toggle the notification center"
        onPressed: Panels.toggle("notifications")
    }
    GlobalShortcut {
        name: "launcher"
        description: "Toggle the application launcher"
        onPressed: Actions.launcher()
    }
    GlobalShortcut {
        name: "spotlight"
        description: "Toggle Spotlight search"
        onPressed: Panels.toggle("spotlight")
    }
    GlobalShortcut {
        name: "clipboard"
        description: "Toggle the clipboard history"
        onPressed: Actions.clipboard()
    }
    GlobalShortcut {
        name: "wallpaper"
        description: "Open the wallpaper switcher"
        onPressed: Panels.toggle("wallpaper")
    }
    GlobalShortcut {
        name: "settings"
        description: "Toggle the settings app"
        onPressed: Panels.settingsOpen = !Panels.settingsOpen
    }
    GlobalShortcut {
        name: "dnd"
        description: "Toggle Do Not Disturb"
        onPressed: Notifs.toggleDnd()
    }
    GlobalShortcut {
        name: "lock"
        description: "Lock the session"
        onPressed: Lock.lock()
    }
    GlobalShortcut {
        name: "gamemode"
        description: "Toggle game mode"
        onPressed: Actions.gameMode = !Actions.gameMode
    }
    GlobalShortcut {
        name: "unityagent"
        description: "Toggle UnityAgent"
        onPressed: UnityAgent.toggle()
    }
    GlobalShortcut {
        name: "recordRegion"
        description: "Record a screen region"
        onPressed: Recorder.startRegion()
    }
    GlobalShortcut {
        name: "recordFull"
        description: "Record the full screen"
        onPressed: Recorder.startFull()
    }
    GlobalShortcut {
        name: "keybinds"
        description: "Open the keybind cheatsheet"
        onPressed: Panels.toggle("keybinds")
    }
}
