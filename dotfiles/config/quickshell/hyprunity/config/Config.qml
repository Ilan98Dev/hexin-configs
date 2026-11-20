pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Persistent, live-reloading settings for hyprunity.
//
// Stored OUTSIDE the Quickshell config directory on purpose: Quickshell reloads
// the whole shell whenever a file inside its config dir changes, which would
// make every settings tweak restart the shell mid-edit.
//
//   ~/.config/hyprunity/settings.json
//
// Everything in the Settings app writes straight into this file (debounced),
// and the file is watched so external edits apply live too.
Singleton {
    id: root

    readonly property string dir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/hyprunity"
    readonly property string path: dir + "/settings.json"

    // Wallpaper bundled with the config, used by the "default" style. Lives
    // next to this file so it is always there, whatever the user does with
    // their own pictures.
    readonly property url defaultWallpaper: Qt.resolvedUrl("../assets/wallpaper.jpg")

    property bool resetting: false
    property bool isLoaded: false

    property alias appearance: adapter.appearance
    property alias bar: adapter.bar
    property alias notifications: adapter.notifications
    property alias controlPanel: adapter.controlPanel
    property alias wallpaper: adapter.wallpaper
    property alias hyprland: adapter.hyprland
    property alias apps: adapter.apps
    property alias general: adapter.general
    property alias unityAgent: adapter.unityAgent

    function resetAll() {
        resetting = true;
        Quickshell.execDetached(["rm", "-f", path]);
        reloadTimer.start();
    }

    // Older configs called the built-in wallpaper "art". It has been replaced
    // by the bundled picture, so fold the old value forward when the file
    // loads (the adapter write below is debounced like any other edit).
    function migrate() {
        if (wallpaper.type === "art")
            wallpaper.type = "default";
        // The launcher used to ship with the Arch glyph. That glyph now means
        // "override the image logo", so only fold the old default forward —
        // a glyph the user chose themselves is kept.
        if (bar.launcherIcon === "\uf009")
            bar.launcherIcon = "";
        root.isLoaded = true;
    }

    Timer {
        id: createTimer
        interval: 400
        onTriggered: if (!root.resetting) fileView.writeAdapter()
    }
    Timer {
        id: saveTimer
        interval: 250
        onTriggered: if (!root.resetting) fileView.writeAdapter()
    }
    Timer {
        id: reloadTimer
        interval: 500
        onTriggered: Quickshell.reload(false)
    }

    FileView {
        id: fileView
        path: root.path
        blockLoading: true
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        onLoaded: root.migrate()
        onAdapterUpdated: saveTimer.restart()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound && !root.resetting) {
                Quickshell.execDetached(["mkdir", "-p", root.dir]);
                createTimer.start();
            }
        }

        adapter: JsonAdapter {
            id: adapter

            property JsonObject appearance: JsonObject {
                // "UnityOS" is the house palette; other presets ship too.
                property string preset: "UnityOS"
                property string accent: ""          // "" = use the preset's accent
                property real opacity: 0.92
                property int radius: 14
                property string font: "JetBrainsMono Nerd Font"
                property string iconFont: "JetBrainsMono Nerd Font"
                property int fontSize: 13
                property bool animations: true
                property int animDuration: 180
            }

            property JsonObject bar: JsonObject {
                property bool enabled: true
                property string position: "top"      // top | bottom
                property bool floating: true
                property int height: 38
                property int margin: 6
                property bool showLauncher: true
                // Empty = use the UnityOS star image. A glyph here replaces the
                // image in the bar launcher button.
                property string launcherIcon: ""
                property bool showWorkspaces: true
                property int workspaceCount: 5
                property string workspaceStyle: "dots" // dots | numbers
                property bool showWindowTitle: true
                property int windowTitleWidth: 260
                property bool showMedia: true
                property bool showTray: true
                property bool showStats: false
                property bool showStatus: true
                property bool showVolume: true
                property bool showNetwork: true
                property bool showBluetooth: true
                property bool showBattery: true
                property bool showNotifications: true
                // The bar's REC/stop pill. It only appears while recording;
                // this flag and the arrange strip control whether and where.
                property bool showRecording: true
                property bool clock24h: true
                property bool clockSeconds: false
                property string dateFormat: "ddd d MMM"
                property string leftOrder: "launcher,workspaces,windowTitle"
                property string rightOrder: "media,tray,stats,status,recording,notifications"
                property string centerOrder: "clock"
            }

            property JsonObject notifications: JsonObject {
                property bool popups: true
                property bool dnd: false
                property bool criticalBypassDnd: true
                property string position: "top-right" // top-left | top-center | top-right | bottom-left | bottom-right
                property int timeout: 6               // seconds, 0 = sticky
                property int maxPopups: 4
                property int width: 360
            }

            property JsonObject controlPanel: JsonObject {
                property int width: 400
                property bool showSliders: true
                property bool showTiles: true
                property bool showMedia: true
                property bool showStats: true
                property bool showPower: true
                property int nightLightTemp: 4000
                // What the control panel's Record tile starts.
                property string recordingMode: "region" // region | fullscreen
            }

            property JsonObject wallpaper: JsonObject {
                property string type: "default"  // default | image | none
                property string image: ""        // absolute path when type === "image"
                property real dim: 0.35        // 0..0.8 scrim over image wallpapers
                // Folder the SUPER + W wallpaper picker lists. `~` is expanded.
                property string folder: "~/Pictures/Wallpapers"
            }

            property JsonObject hyprland: JsonObject {
                property bool manage: true          // write hyprunity/settings.lua + apply with hyprctl eval
                property int gaps_in: 5
                property int gaps_out: 12
                property int border_size: 2
                property int rounding: 8
                property bool animations: true
                property bool accentBorders: true    // tint window borders with the accent
                property real activeOpacity: 0.95
                property real inactiveOpacity: 0.95
                property bool blur: true
                property int blurSize: 8
                property int blurPasses: 2
                property bool shadow: true
                property int shadowRange: 12
                property int shadowPower: 3
            }

            property JsonObject apps: JsonObject {
                // hyprunity ships its own launcher + clipboard history panels.
                // Leave empty to use the built-in panel; set a command to run
                // an external launcher (fuzzel, rofi, …).
                property string launcher: ""
                property string terminal: "kitty"
                // Used by Spotlight's web rows (search / open a URL).
                property string browser: "zen-browser"
                property string screenshot: "grim -g \"$(slurp)\" - | wl-copy"
                // Empty = use hyprunity's built-in Quickshell lock screen.
                property string lock: ""
                property string logout: "hyprctl dispatch 'hl.dsp.exit()'"
                property string suspend: "systemctl suspend"
                property string reboot: "systemctl reboot"
                property string shutdown: "systemctl poweroff"
            }

            property JsonObject general: JsonObject {
                property bool weekStartsMonday: true
                property bool osd: true
                property int osdTimeout: 1500
                // First-run tour. Set once the welcome screen is dismissed;
                // Settings > General can show it again.
                property bool welcomeSeen: false
            }

            // Settings > UnityAgent. These are policy switches, not provider
            // credentials: the API key and model live in the agent's own state
            // file. The daemon receives them with every request and removes or
            // refuses the matching tools.
            property JsonObject unityAgent: JsonObject {
                property bool enabled: true          // universal off switch
                property bool projects: true         // create_project + project cwd
                property bool commands: true         // run_command
                property bool files: true            // write_file + edit_file
                property bool packages: true         // pacman/yay/paru installs
                property bool weeklyUpdates: true    // weekly package-update check
                property bool web: true              // fetch_url + web_search
                property bool screenshots: true      // screenshot
                property bool mouse: true            // ydotool pointer, click, scroll
                property bool systemErrors: true     // crash/service alerts with "Fix with AI"
            }
        }
    }
}
