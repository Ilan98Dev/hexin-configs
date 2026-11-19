pragma Singleton

import QtQuick
import Quickshell

// Glyphs are Font Awesome 4.7 code points, present in every Nerd Font.
Singleton {
    readonly property string volumeHigh: ""
    readonly property string volumeLow: ""
    readonly property string volumeMute: ""
    readonly property string mic: ""
    readonly property string micOff: ""
    readonly property string wifi: ""
    readonly property string globe: ""
    readonly property string bluetooth: ""
    readonly property string bolt: ""
    readonly property var battery: ["", "", "", "", ""]
    readonly property string bell: ""
    readonly property string bellSlash: ""
    readonly property string sun: ""
    readonly property string moon: ""
    readonly property string coffee: ""
    readonly property string cog: ""
    readonly property string lock: ""
    readonly property string signOut: ""
    readonly property string power: ""
    readonly property string refresh: ""
    readonly property string camera: ""
    readonly property string desktop: "\uf108"
    readonly property string crop: "\uf125"
    readonly property string record: "\uf111"
    readonly property string stop: "\uf04d"
    readonly property string play: ""
    readonly property string pause: ""
    readonly property string prev: ""
    readonly property string next: ""
    readonly property string music: ""
    readonly property string close: ""
    readonly property string check: ""
    readonly property string chevronDown: ""
    readonly property string chevronUp: ""
    readonly property string chevronLeft: ""
    readonly property string chevronRight: ""
    readonly property string trash: ""
    readonly property string leaf: ""
    readonly property string rocket: ""
    readonly property string balance: ""
    readonly property string paint: ""
    readonly property string bars: ""
    readonly property string sliders: ""
    readonly property string terminal: ""
    readonly property string info: ""
    readonly property string star: "\uf005"
    readonly property string cpu: ""
    readonly property string disk: ""
    readonly property string ram: ""
    readonly property string lockLarge: ""
    readonly property string brightness: ""
    readonly property string headphones: ""
    readonly property string lockSmall: ""

    readonly property string image: "\uf03e"
    readonly property string layout: "\uf009"
    readonly property string search: "\uf002"
    readonly property string file: "\uf15b"
    readonly property string clipboard: "\uf0ea"
    readonly property string apps: "\uf009"
    readonly property string gamepad: "\uf11b"
    readonly property string eye: "\uf06e"
    readonly property string eyeSlash: "\uf070"
    readonly property string plus: "\uf067"
    readonly property string minus: "\uf068"
    readonly property string keyboard: "\uf11c"

    // Friendly names the shell uses for its own notifications, mapped onto
    // icons the desktop theme actually ships.
    readonly property var iconAliases: ({
            "gamepad": "applications-games",
            "coffee": "preferences-system-power",
            "moon": "weather-clear-night",
            "camera": "camera-photo"
        })

    // Resolve one name through the icon theme. `check` makes Quickshell return
    // "" instead of a URL for unknown names; that matters because its icon
    // provider paints a magenta/black checkerboard for a missing icon.
    function themeIcon(name) {
        if (!name)
            return "";
        return Quickshell.iconPath(iconAliases[name] !== undefined ? iconAliases[name] : name, true);
    }

    // Resolve a notification / desktop icon name or path to an image source.
    // Returns "" when nothing usable resolves, so callers fall back to a glyph
    // rather than painting a broken icon.
    function src(name) {
        if (!name)
            return "";
        if (name.startsWith("image://icon/")) {
            // Notifications can carry an already-resolved icon URL; the name
            // inside it still has to exist in the theme.
            const q = name.indexOf("?");
            return themeIcon(name.slice("image://icon/".length, q < 0 ? undefined : q));
        }
        if (name.startsWith("/"))
            return "file://" + name;
        if (name.startsWith("file:") || name.startsWith("image:") || name.startsWith("http"))
            return name;
        return themeIcon(name);
    }
}
