pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    property var matugen: null

    readonly property var activeMatugen: (root.matugen && root.matugen.base && root.matugen.accent) ? root.matugen : ({
            base: "#111318", mantle: "#191c20", surface: "#1d2024", surfaceHi: "#282a2f",
            text: "#e2e2e9", subtext: "#8e9099", accent: "#a9c7ff",
            red: "#ffb4ab", green: "#dcbce1", yellow: "#dcbce1", blue: "#bdc7dc"
        })

    readonly property var presets: ({
            "UnityOS": {
                base: "#121118", mantle: "#1a1924", surface: "#262335", surfaceHi: "#332f45",
                text: "#F3F4F6", subtext: "#9CA3AF", accent: "#F97316",
                red: "#ef4444", green: "#22c55e", yellow: "#EAB308", blue: "#7C3AED"
            },
            "Auto (Matugen)": activeMatugen,
            "Catppuccin Mocha": {
                base: "#1e1e2e", mantle: "#181825", surface: "#313244", surfaceHi: "#45475a",
                text: "#cdd6f4", subtext: "#a6adc8", accent: "#cba6f7",
                red: "#f38ba8", green: "#a6e3a1", yellow: "#f9e2af", blue: "#89b4fa"
            },
            "Catppuccin Latte": {
                base: "#eff1f5", mantle: "#e6e9ef", surface: "#ccd0da", surfaceHi: "#bcc0cc",
                text: "#4c4f69", subtext: "#6c6f85", accent: "#8839ef",
                red: "#d20f39", green: "#40a02b", yellow: "#df8e1d", blue: "#1e66f5"
            },
            "Tokyo Night": {
                base: "#1a1b26", mantle: "#16161e", surface: "#292e42", surfaceHi: "#3b4261",
                text: "#c0caf5", subtext: "#9aa5ce", accent: "#7aa2f7",
                red: "#f7768e", green: "#9ece6a", yellow: "#e0af68", blue: "#7dcfff"
            },
            "Gruvbox": {
                base: "#282828", mantle: "#1d2021", surface: "#3c3836", surfaceHi: "#504945",
                text: "#ebdbb2", subtext: "#a89984", accent: "#fe8019",
                red: "#fb4934", green: "#b8bb26", yellow: "#fabd2f", blue: "#83a598"
            },
            "Nord": {
                base: "#2e3440", mantle: "#272c36", surface: "#3b4252", surfaceHi: "#434c5e",
                text: "#eceff4", subtext: "#d8dee9", accent: "#88c0d0",
                red: "#bf616a", green: "#a3be8c", yellow: "#ebcb8b", blue: "#81a1c1"
            },
            "Rose Pine": {
                base: "#191724", mantle: "#16141f", surface: "#26233a", surfaceHi: "#403d52",
                text: "#e0def4", subtext: "#908caa", accent: "#c4a7e7",
                red: "#eb6f92", green: "#9ccfd8", yellow: "#f6c177", blue: "#31748f"
            },
            "Dracula": {
                base: "#282a36", mantle: "#21222c", surface: "#343746", surfaceHi: "#44475a",
                text: "#f8f8f2", subtext: "#bdc0d8", accent: "#bd93f9",
                red: "#ff5555", green: "#50fa7b", yellow: "#f1fa8c", blue: "#8be9fd"
            }
        })
    readonly property var names: Object.keys(presets)
    readonly property var p: (Config.appearance.preset === "Auto (Matugen)")
        ? activeMatugen
        : (presets[Config.appearance.preset] ?? presets["Catppuccin Mocha"])

    readonly property color base: p.base
    readonly property color mantle: p.mantle
    readonly property color surface: p.surface
    readonly property color surfaceHi: p.surfaceHi
    readonly property color text: p.text
    readonly property color subtext: p.subtext
    readonly property color red: p.red
    readonly property color green: p.green
    readonly property color yellow: p.yellow
    readonly property color blue: p.blue
    readonly property color accent: Config.appearance.accent !== "" ? Config.appearance.accent : p.accent

    function luminance(c) {
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    }
    readonly property color onAccent: luminance(accent) > 0.55 ? "#11111b" : "#ffffff"

    readonly property color bg: Qt.alpha(base, Config.appearance.opacity)
    readonly property color bgSolid: Qt.alpha(base, Math.max(0.96, Config.appearance.opacity))
    readonly property color card: Qt.alpha(surface, 0.55)
    readonly property color hover: Qt.alpha(text, 0.08)
    readonly property color pressed: Qt.alpha(text, 0.14)
    readonly property color border: Qt.alpha(text, 0.10)
    readonly property color accentSoft: Qt.alpha(accent, 0.20)

    readonly property int radius: Config.appearance.radius
    readonly property int radiusSmall: Math.max(4, Math.round(Config.appearance.radius * 0.6))

    readonly property string font: Config.appearance.font
    readonly property string iconFont: Config.appearance.iconFont
    readonly property int fontSize: Config.appearance.fontSize
    readonly property int fontSmall: Math.max(9, fontSize - 2)
    readonly property int fontLarge: fontSize + 4
    readonly property int iconSize: fontSize + 3

    // Game mode pauses motion for the running session without touching the
    // user's saved animation setting.
    property bool motionPaused: false

    readonly property int anim: (!motionPaused && Config.appearance.animations) ? Config.appearance.animDuration : 0
    readonly property int animFast: Math.round(anim * 0.6)

    readonly property string matugenBin: (Quickshell.env("HOME") || "") + "/.local/bin/hexin-matugen-apply"
    readonly property string themeSyncBin: (Quickshell.env("HOME") || "") + "/.local/bin/hexin-theme-sync"
    readonly property string appearancePreset: Config.appearance.preset
    readonly property string wallType: Config.wallpaper.type
    readonly property string wallImage: Config.wallpaper.image || ""
    property string lastMatugenWall: ""
    property bool ready: false

    readonly property bool isDefaultWallpaper: {
        if (wallType === "default" || wallType === "none")
            return true;
        if (wallType === "image") {
            const img = (wallImage || "").replace(/^file:\/\//, "");
            const def = String(Config.defaultWallpaper || "").replace(/^file:\/\//, "");
            if (!img.length || img === def)
                return true;
        }
        return false;
    }

    Timer {
        id: syncTimer
        interval: 300
        onTriggered: Quickshell.execDetached([themeSyncBin])
    }

    function switchToUnityOS() {
        Config.appearance.preset = "UnityOS";
        syncTimer.restart();
    }

    onIsDefaultWallpaperChanged: {
        if (!ready || !Config.isLoaded) return;
        if (isDefaultWallpaper && appearancePreset === "Auto (Matugen)") {
            switchToUnityOS();
        }
    }

    function wallpaperPath() {
        var p = "";
        if (wallType === "image" && wallImage.length)
            p = wallImage;
        else if (wallType === "default")
            p = String(Config.defaultWallpaper || "");
        if (p.startsWith("file://"))
            p = p.substring(7);
        return p;
    }

    function requestMatugen(force) {
        if (force) lastMatugenWall = "";
        matugenDebounce.restart();
    }

    function applyMatugen(force) {
        if (appearancePreset !== "Auto (Matugen)") return;
        const wall = wallpaperPath();
        if (!wall.length) return;
        if (!force && wall === lastMatugenWall) return;
        lastMatugenWall = wall;
        Quickshell.execDetached([matugenBin, wall]);
        colorsReload.restart();
    }

    function loadMatugen(jsonText) {
        try {
            const c = JSON.parse(jsonText);
            const d = (c.colors && c.colors.dark) ? c.colors.dark : {};
            if (!d.background && !d.primary) return;
            const next = {
                base: d.background || "#131318",
                mantle: d.surface_container_low || d.surface || "#1b1b21",
                surface: d.surface_container || d.surface || "#1f1f25",
                surfaceHi: d.surface_container_high || "#29292f",
                text: d.on_background || d.on_surface || "#e4e1e9",
                subtext: d.outline || "#90909a",
                accent: d.primary || "#bcc3ff",
                red: d.error || "#ffb4ab",
                green: d.tertiary || "#e6bad7",
                yellow: d.tertiary || "#e6bad7",
                blue: d.secondary || "#c4c5dd"
            };
            const cur = root.matugen;
            if (cur && cur.accent === next.accent && cur.base === next.base && cur.surface === next.surface) return;
            root.matugen = next;
        } catch (e) {}
    }

    onWallTypeChanged: {
        lastMatugenWall = "";
        matugenDebounce.restart();
    }
    onWallImageChanged: {
        lastMatugenWall = "";
        matugenDebounce.restart();
    }
    onAppearancePresetChanged: {
        if (appearancePreset === "Auto (Matugen)") {
            if (Config.appearance.accent === "#F97316" || Config.appearance.accent === "#f97316")
                Config.appearance.accent = "";
            lastMatugenWall = "";
            matugenDebounce.restart();
        }
    }

    Timer {
        id: matugenDebounce
        interval: 50
        onTriggered: root.applyMatugen(false)
    }

    Timer {
        id: colorsReload
        interval: 400
        repeat: true
        triggeredOnStart: false
        property int tries: 0
        onTriggered: {
            tries++;
            matugenFile.reload();
            if (tries >= 6) { running = false; tries = 0; }
        }
    }

    FileView {
        id: matugenFile
        path: (Quickshell.env("HOME") || "") + "/.local/state/quickshell/user/generated/colors.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.loadMatugen(text())
    }

    Timer {
        id: readyTimer
        interval: 150
        onTriggered: {
            root.ready = true;
            if (isDefaultWallpaper && appearancePreset === "Auto (Matugen)") {
                switchToUnityOS();
            }
        }
    }

    Component.onCompleted: {
        matugenFile.reload();
        matugenDebounce.restart();
        readyTimer.start();
    }
}
