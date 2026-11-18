pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config

// Which panel is open, and on which screen.
Singleton {
    id: root

    property string active: ""       // "" | "notifications" | "calendar" | "control" | "launcher" | "clipboard" | "wallpaper" | "keybinds"
    property string screenName: ""
    property bool settingsOpen: false
    // Optional page key to reveal when the settings window opens. Cleared by
    // the window after it switches, so a later normal open starts on the last
    // page the user was on.
    property string settingsPage: ""

    readonly property int barSize: Config.bar.enabled ? Config.bar.height + (Config.bar.floating ? Config.bar.margin * 2 : 0) : 0

    function focusedScreen() {
        return Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
    }

    function open(name, screen) {
        screenName = screen || focusedScreen();
        active = name;
    }

    function close() {
        active = "";
    }

    function toggle(name, screen) {
        const s = screen || focusedScreen();
        if (active === name && screenName === s)
            close();
        else
            open(name, s);
    }

    function openSettings() {
        close();
        settingsOpen = true;
    }
}
