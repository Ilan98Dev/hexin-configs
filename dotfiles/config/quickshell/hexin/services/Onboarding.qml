pragma Singleton

import QtQuick
import Quickshell
import qs.config

// First-run welcome tour.
//
// `open` drives the five-page window in modules/welcome: intro, keybinds,
// personalisation, HexinAgent setup and a closing page. The tour is shown once,
// a short moment after the shell starts, when Config.general.welcomeSeen is
// still false. Dismissing it persists that flag; Settings > General can
// show it again at any time (that does not clear the flag until the user
// dismisses it again).
Singleton {
    id: root

    property bool open: false
    property bool autoShown: false

    function show() {
        open = true;
    }

    function close() {
        open = false;
    }

    function dismiss() {
        Config.general.welcomeSeen = true;
        open = false;
    }

    function reset() {
        Config.general.welcomeSeen = false;
        open = true;
    }

    // Give the bar, wallpaper and settings file a moment to settle before
    // covering the desktop with a welcome window.
    Timer {
        interval: 1600
        running: true
        onTriggered: {
            if (!root.autoShown && !Config.general.welcomeSeen) {
                root.autoShown = true;
                root.open = true;
            }
        }
    }
}
