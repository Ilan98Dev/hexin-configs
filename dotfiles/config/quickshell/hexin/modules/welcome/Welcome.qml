import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.services
import qs.components

// First-run welcome tour. Shown once by Onboarding (see services/Onboarding.qml)
// and reopenable from Settings > General. A layer-shell overlay rather than a
// normal window so it reliably takes the keyboard (Esc / arrows / Enter) on
// first run.
//
// Five pages slide horizontally inside one card: the intro, the essential
// keybinds, personalisation (live theme + accent), the HexinAgent master
// switch, and a closing page. Arrow keys, the dots and the footer buttons all
// drive the same `page` value.
LazyLoader {
    active: Onboarding.open

    PanelWindow {
        id: win

        // Follow the focused monitor if it changes while the tour is open.
        screen: {
            const name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
            for (const s of Quickshell.screens) {
                if (s.name === name)
                    return s;
            }
            return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
        }

        visible: Onboarding.open
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-welcome"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // Dim the desktop and swallow clicks outside the card.
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.45)
        }
        MouseArea {
            anchors.fill: parent
        }

        Rectangle {
            id: surface

            property int page: 0
            readonly property int pageCount: 5
            readonly property int slideDuration: Theme.anim > 0 ? Theme.anim + 140 : 0

            // Presets and accents offered by the personalisation page.
            readonly property var tourPresets: [
                "Hexin",
                "Catppuccin Mocha",
                "Tokyo Night",
                "Gruvbox",
                "Nord",
                "Dracula"
            ]
            readonly property var tourAccents: [
                "#F97316",
                "#7C3AED",
                "#EAB308",
                "#cba6f7",
                "#89b4fa",
                "#a6e3a1",
                "#f38ba8",
                "#ffffff"
            ]

            function go(i) {
                page = Math.max(0, Math.min(pageCount - 1, i));
            }

            function next() {
                if (page < pageCount - 1)
                    page += 1;
                else
                    Onboarding.dismiss();
            }

            function previous() {
                if (page > 0)
                    page -= 1;
            }

            // Close the tour and land on a specific Settings page.
            function openSettings(key) {
                Onboarding.dismiss();
                Panels.settingsPage = key;
                Panels.openSettings();
            }

            anchors.centerIn: parent
            width: Math.min(960, win.width - 40)
            height: Math.min(640, win.height - 40)
            color: Theme.base
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.lighter(Theme.base, 1.10)
                }
                GradientStop {
                    position: 0.42
                    color: Theme.base
                }
                GradientStop {
                    position: 1
                    color: Theme.base
                }
            }
            radius: Theme.radius + 4
            border.width: 1
            border.color: Qt.alpha(Theme.accent, 0.18)
            clip: true
            focus: true

            opacity: 0
            scale: 0.97
            transformOrigin: Item.Center

            Component.onCompleted: {
                Qt.callLater(() => surface.forceActiveFocus());
                revealTimer.start();
            }

            Keys.onEscapePressed: Onboarding.dismiss()
            Keys.onLeftPressed: surface.previous()
            Keys.onRightPressed: surface.next()
            Keys.onReturnPressed: surface.next()

            Timer {
                id: revealTimer
                interval: 16
                onTriggered: {
                    if (Theme.anim > 0) {
                        enterAnim.start();
                    } else {
                        surface.opacity = 1;
                        surface.scale = 1;
                    }
                }
            }

            ParallelAnimation {
                id: enterAnim
                NumberAnimation {
                    target: surface
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Theme.anim + 80
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: surface
                    property: "scale"
                    from: 0.97
                    to: 1
                    duration: Theme.anim + 120
                    easing.type: Easing.OutCubic
                }
            }

            // Soft accent bloom in the top-right corner; it breathes slowly so
            // the card never feels static while the tour is open.
            Rectangle {
                id: bloom
                anchors {
                    top: parent.top
                    right: parent.right
                    topMargin: -130
                    rightMargin: -110
                }
                width: 360
                height: 360
                radius: 180
                color: Qt.alpha(Theme.accent, 0.10)

                SequentialAnimation on opacity {
                    running: Theme.anim > 0
                    loops: Animation.Infinite
                    NumberAnimation {
                        from: 0.45
                        to: 1.0
                        duration: 3200
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        from: 1.0
                        to: 0.45
                        duration: 3200
                        easing.type: Easing.InOutSine
                    }
                }
            }

            ColumnLayout {
                anchors {
                    fill: parent
                    margins: 26
                }
                spacing: 14

                // ── header ──────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        width: 30
                        height: 30
                        radius: 9
                        color: Theme.accentSoft

                        Logo {
                            anchors.centerIn: parent
                            size: 20
                        }
                    }
                    Txt {
                        text: "hexin"
                        font.bold: true
                        font.pixelSize: Theme.fontSize + 2
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Txt {
                        text: (surface.page + 1) + " / " + surface.pageCount
                        color: Theme.subtext
                        font.pixelSize: Theme.fontSmall
                        Layout.alignment: Qt.AlignVCenter
                    }
                    IconButton {
                        glyph: Icons.close
                        size: 30
                        onClicked: Onboarding.dismiss()
                    }
                }

                // ── pages ───────────────────────────────────────────
                Item {
                    id: viewport
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    // 1 ─ welcome ─────────────────────────────────────
                    Item {
                        id: pageWelcome

                        width: viewport.width
                        height: viewport.height
                        x: (0 - surface.page) * viewport.width
                        opacity: surface.page === 0 ? 1 : 0
                        enabled: surface.page === 0

                        Behavior on x {
                            NumberAnimation {
                                duration: surface.slideDuration
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Math.round(surface.slideDuration * 0.55)
                                easing.type: Easing.OutCubic
                            }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            width: Math.min(660, parent.width - 40)
                            spacing: 8

                            Item {
                                Layout.alignment: Qt.AlignHCenter
                                implicitWidth: 200
                                implicitHeight: 200

                                Rectangle {
                                    id: halo
                                    anchors.centerIn: parent
                                    width: 190
                                    height: 190
                                    radius: 95
                                    color: Qt.alpha(Theme.accent, 0.08)

                                    SequentialAnimation on scale {
                                        running: Theme.anim > 0 && surface.page === 0
                                        loops: Animation.Infinite
                                        NumberAnimation {
                                            from: 0.90
                                            to: 1.06
                                            duration: 2400
                                            easing.type: Easing.InOutSine
                                        }
                                        NumberAnimation {
                                            from: 1.06
                                            to: 0.90
                                            duration: 2400
                                            easing.type: Easing.InOutSine
                                        }
                                    }
                                }

                                // Two dots orbiting the mark in opposite
                                // directions. Pure rotation keeps this cheap.
                                Item {
                                    anchors.fill: parent

                                    RotationAnimation on rotation {
                                        from: 0
                                        to: 360
                                        duration: 14000
                                        loops: Animation.Infinite
                                        running: Theme.anim > 0 && surface.page === 0
                                    }

                                    Rectangle {
                                        width: 7
                                        height: 7
                                        radius: 3.5
                                        color: Theme.accent
                                        x: parent.width / 2 - width / 2
                                        y: 3
                                    }
                                }
                                Item {
                                    anchors.fill: parent

                                    RotationAnimation on rotation {
                                        from: 360
                                        to: 0
                                        duration: 19000
                                        loops: Animation.Infinite
                                        running: Theme.anim > 0 && surface.page === 0
                                    }

                                    Rectangle {
                                        width: 5
                                        height: 5
                                        radius: 2.5
                                        color: Qt.alpha(Theme.accent, 0.55)
                                        x: parent.width / 2 - width / 2
                                        y: parent.height - height - 3
                                    }
                                }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 138
                                    height: 138
                                    radius: 36
                                    color: Theme.accentSoft
                                    border.width: 1
                                    border.color: Qt.alpha(Theme.accent, 0.35)
                                }

                                Logo {
                                    anchors.centerIn: parent
                                    size: 104
                                }
                            }

                            Txt {
                                Layout.fillWidth: true
                                text: "Welcome to"
                                color: Theme.subtext
                                font.pixelSize: Theme.fontSize + 2
                                horizontalAlignment: Text.AlignHCenter
                            }
                            Txt {
                                Layout.fillWidth: true
                                text: "hexin"
                                color: Theme.accent
                                font.pixelSize: 46
                                font.bold: true
                                font.letterSpacing: 1
                                horizontalAlignment: Text.AlignHCenter
                            }
                            Txt {
                                Layout.fillWidth: true
                                text: "A keyboard-first desktop for Hyprland — fast, quiet and entirely yours."
                                color: Theme.subtext
                                font.pixelSize: Theme.fontSize + 1
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.Wrap
                            }
                        }
                    }

                    // 2 ─ keybinds ────────────────────────────────────
                    Item {
                        id: pageKeys

                        width: viewport.width
                        height: viewport.height
                        x: (1 - surface.page) * viewport.width
                        opacity: surface.page === 1 ? 1 : 0
                        enabled: surface.page === 1

                        Behavior on x {
                            NumberAnimation {
                                duration: surface.slideDuration
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Math.round(surface.slideDuration * 0.55)
                                easing.type: Easing.OutCubic
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            spacing: 10

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Txt {
                                    Layout.fillWidth: true
                                    text: "The keys that matter"
                                    font.pixelSize: Theme.fontLarge + 10
                                    font.bold: true
                                }
                                Txt {
                                    Layout.fillWidth: true
                                    text: "A handful of shortcuts and you can leave the mouse behind."
                                    color: Theme.subtext
                                }
                            }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2
                                columnSpacing: 10
                                rowSpacing: 10

                                Repeater {
                                    model: [
                                        {
                                            keys: ["SUPER", "SPACE"],
                                            label: "App launcher",
                                            hint: "Every app, by name or keyword"
                                        },
                                        {
                                            keys: ["ALT", "SPACE"],
                                            label: "Spotlight",
                                            hint: "Apps, files, maths and the web"
                                        },
                                        {
                                            keys: ["SUPER", "C"],
                                            label: "Control centre",
                                            hint: "Volume, Wi-Fi, Bluetooth, power"
                                        },
                                        {
                                            keys: ["SUPER", "N"],
                                            label: "Notifications",
                                            hint: "History and Do Not Disturb"
                                        },
                                        {
                                            keys: ["SUPER", ","],
                                            label: "Settings",
                                            hint: "Theme, bar, Hyprland and more"
                                        },
                                        {
                                            keys: ["SUPER", "K"],
                                            label: "All keybinds",
                                            hint: "Search every shortcut in the shell"
                                        },
                                        {
                                            keys: ["SUPER", "V"],
                                            label: "Clipboard history",
                                            hint: "Search everything you copied"
                                        },
                                        {
                                            keys: ["SUPER", "T"],
                                            label: "HexinAgent",
                                            hint: "Your approval-first assistant"
                                        },
                                        {
                                            keys: ["SUPER", "Q"],
                                            label: "Close window",
                                            hint: "Quit the focused app"
                                        },
                                        {
                                            keys: ["SUPER", "1…0"],
                                            label: "Workspaces",
                                            hint: "Jump straight to a desktop"
                                        }
                                    ]

                                    KeybindCard {
                                        required property var modelData

                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 1
                                        Layout.preferredHeight: 66
                                        keys: modelData.keys
                                        label: modelData.label
                                        hint: modelData.hint
                                    }
                                }
                            }

                            Item {
                                Layout.fillHeight: true
                            }

                            Txt {
                                Layout.fillWidth: true
                                text: "Use ← → to browse · SUPER + K opens the full searchable list any time."
                                color: Theme.subtext
                                font.pixelSize: Theme.fontSmall
                            }
                        }
                    }

                    // 3 ─ personalisation ─────────────────────────────
                    Item {
                        id: pageStyle

                        width: viewport.width
                        height: viewport.height
                        x: (2 - surface.page) * viewport.width
                        opacity: surface.page === 2 ? 1 : 0
                        enabled: surface.page === 2

                        Behavior on x {
                            NumberAnimation {
                                duration: surface.slideDuration
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Math.round(surface.slideDuration * 0.55)
                                easing.type: Easing.OutCubic
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            spacing: 12

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Txt {
                                    Layout.fillWidth: true
                                    text: "Make it yours"
                                    font.pixelSize: Theme.fontLarge + 10
                                    font.bold: true
                                }
                                Txt {
                                    Layout.fillWidth: true
                                    text: "Pick a palette and an accent — the whole desktop updates live."
                                    color: Theme.subtext
                                }
                            }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 3
                                columnSpacing: 10
                                rowSpacing: 10

                                Repeater {
                                    model: surface.tourPresets

                                    Rectangle {
                                        id: presetCard

                                        required property string modelData
                                        readonly property var pal: Theme.presets[modelData]
                                        readonly property bool selected: Config.appearance.preset === modelData

                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 1
                                        Layout.preferredHeight: 64
                                        radius: Theme.radiusSmall + 2
                                        color: pal.base
                                        border.width: selected ? 2 : 1
                                        border.color: selected ? Theme.accent : Theme.border

                                        Behavior on border.color {
                                            ColorAnimation {
                                                duration: Theme.animFast
                                            }
                                        }

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: 9

                                            Row {
                                                spacing: 4

                                                Repeater {
                                                    model: ["accent", "red", "green", "blue"]

                                                    Rectangle {
                                                        required property string modelData
                                                        width: 10
                                                        height: 10
                                                        radius: 5
                                                        color: presetCard.pal[modelData]
                                                    }
                                                }
                                            }
                                            Txt {
                                                text: presetCard.modelData
                                                color: presetCard.pal.text
                                                font.pixelSize: Theme.fontSmall + 1
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                Config.appearance.preset = presetCard.modelData;
                                                Config.appearance.accent = "";
                                            }
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Txt {
                                    text: "Accent"
                                    color: Theme.subtext
                                    font.pixelSize: Theme.fontSmall
                                }

                                Row {
                                    spacing: 6

                                    Repeater {
                                        model: surface.tourAccents

                                        Rectangle {
                                            required property string modelData
                                            readonly property bool selected: Config.appearance.accent.toLowerCase() === modelData.toLowerCase()

                                            width: 22
                                            height: 22
                                            radius: 11
                                            color: modelData
                                            border.width: selected ? 2 : 1
                                            border.color: selected ? Theme.text : Theme.border

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: Config.appearance.accent = modelData
                                            }
                                        }
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                WelcomeButton {
                                    text: "Preset accent"
                                    onClicked: Config.appearance.accent = ""
                                }
                            }

                            Item {
                                Layout.fillHeight: true
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Txt {
                                    Layout.fillWidth: true
                                    text: "Changes apply instantly — no restart needed."
                                    color: Theme.subtext
                                    font.pixelSize: Theme.fontSmall
                                }
                                WelcomeButton {
                                    text: "Wallpaper"
                                    onClicked: surface.openSettings("wallpaper")
                                }
                                WelcomeButton {
                                    text: "Appearance"
                                    onClicked: surface.openSettings("appearance")
                                }
                            }
                        }
                    }

                    // 4 ─ HexinAgent ─────────────────────────────────
                    Item {
                        id: pageAgent

                        width: viewport.width
                        height: viewport.height
                        x: (3 - surface.page) * viewport.width
                        opacity: surface.page === 3 ? 1 : 0
                        enabled: surface.page === 3

                        Behavior on x {
                            NumberAnimation {
                                duration: surface.slideDuration
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Math.round(surface.slideDuration * 0.55)
                                easing.type: Easing.OutCubic
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            spacing: 10

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Txt {
                                    Layout.fillWidth: true
                                    text: "Meet HexinAgent"
                                    font.pixelSize: Theme.fontLarge + 10
                                    font.bold: true
                                }
                                Txt {
                                    Layout.fillWidth: true
                                    text: "An assistant inside the shell. Read-only actions run immediately; anything that changes your system asks first."
                                    color: Theme.subtext
                                    wrapMode: Text.Wrap
                                }
                            }

                            // The universal switch comes first, exactly like
                            // Settings ▸ HexinAgent.
                            Card {
                                Layout.fillWidth: true
                                padding: 14
                                border.width: 1
                                border.color: Config.hexinAgent.enabled ? Qt.alpha(Theme.accent, 0.55) : Theme.border

                                Behavior on border.color {
                                    ColorAnimation {
                                        duration: Theme.animFast
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 12

                                    Rectangle {
                                        width: 44
                                        height: 44
                                        radius: 13
                                        color: Theme.accentSoft

                                        Logo {
                                            anchors.centerIn: parent
                                            size: 28
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Txt {
                                            Layout.fillWidth: true
                                            text: "HexinAgent"
                                            font.bold: true
                                            font.pixelSize: Theme.fontSize + 2
                                        }
                                        Txt {
                                            Layout.fillWidth: true
                                            text: "SUPER + T opens the chat. Turning this on starts the background daemon; turning it off disables the shortcut and every tool."
                                            color: Theme.subtext
                                            font.pixelSize: Theme.fontSmall
                                            wrapMode: Text.Wrap
                                        }
                                    }

                                    ColumnLayout {
                                        spacing: 4

                                        Txt {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: Config.hexinAgent.enabled ? "On" : "Off"
                                            color: Config.hexinAgent.enabled ? Theme.accent : Theme.subtext
                                            font.pixelSize: Theme.fontSmall
                                            font.bold: true
                                        }
                                        Toggle {
                                            checked: Config.hexinAgent.enabled
                                            onToggled: v => Config.hexinAgent.enabled = v
                                        }
                                    }
                                }
                            }

                            GridLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                columns: 2
                                columnSpacing: 8
                                rowSpacing: 8

                                FeatureRow {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: 1
                                    Layout.minimumHeight: 54
                                    title: "Projects"
                                    description: "Create and build coding projects"
                                    available: Config.hexinAgent.enabled
                                    checked: Config.hexinAgent.projects
                                    onToggled: v => Config.hexinAgent.projects = v
                                }
                                FeatureRow {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: 1
                                    Layout.minimumHeight: 54
                                    title: "Commands"
                                    description: "Run shell commands with approval"
                                    available: Config.hexinAgent.enabled
                                    checked: Config.hexinAgent.commands
                                    onToggled: v => Config.hexinAgent.commands = v
                                }
                                FeatureRow {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: 1
                                    Layout.minimumHeight: 54
                                    title: "Files"
                                    description: "Write and edit files with approval"
                                    available: Config.hexinAgent.enabled
                                    checked: Config.hexinAgent.files
                                    onToggled: v => Config.hexinAgent.files = v
                                }
                                FeatureRow {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: 1
                                    Layout.minimumHeight: 54
                                    title: "Packages"
                                    description: "Install or remove packages"
                                    available: Config.hexinAgent.enabled
                                    checked: Config.hexinAgent.packages
                                    onToggled: v => Config.hexinAgent.packages = v
                                }
                                FeatureRow {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: 1
                                    Layout.minimumHeight: 54
                                    title: "Weekly updates"
                                    description: "Read-only package-update check"
                                    available: Config.hexinAgent.enabled
                                    checked: Config.hexinAgent.weeklyUpdates
                                    onToggled: v => Config.hexinAgent.weeklyUpdates = v
                                }
                                FeatureRow {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: 1
                                    Layout.minimumHeight: 54
                                    title: "Web"
                                    description: "Search the web and fetch pages"
                                    available: Config.hexinAgent.enabled
                                    checked: Config.hexinAgent.web
                                    onToggled: v => Config.hexinAgent.web = v
                                }
                                FeatureRow {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: 1
                                    Layout.minimumHeight: 54
                                    title: "Screenshots"
                                    description: "Capture the screen when asked"
                                    available: Config.hexinAgent.enabled
                                    checked: Config.hexinAgent.screenshots
                                    onToggled: v => Config.hexinAgent.screenshots = v
                                }

                                Card {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: 1
                                    Layout.minimumHeight: 54
                                    padding: 10

                                    Txt {
                                        Layout.fillWidth: true
                                        text: "Approval first"
                                        color: Theme.accent
                                        font.bold: true
                                        font.pixelSize: Theme.fontSmall + 1
                                    }
                                    Txt {
                                        Layout.fillWidth: true
                                        text: "Every command, file write and project is shown as a card before it runs."
                                        color: Theme.subtext
                                        font.pixelSize: Theme.fontSmall
                                        wrapMode: Text.Wrap
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Txt {
                                    Layout.fillWidth: true
                                    text: "Add a provider and API key in Settings ▸ HexinAgent. Everything here can be changed later."
                                    color: Theme.subtext
                                    font.pixelSize: Theme.fontSmall
                                    wrapMode: Text.Wrap
                                }
                                WelcomeButton {
                                    text: "Configure HexinAgent"
                                    onClicked: surface.openSettings("hexinagent")
                                }
                            }
                        }
                    }

                    // 5 ─ enjoy ───────────────────────────────────────
                    Item {
                        id: pageEnjoy

                        width: viewport.width
                        height: viewport.height
                        x: (4 - surface.page) * viewport.width
                        opacity: surface.page === 4 ? 1 : 0
                        enabled: surface.page === 4

                        Behavior on x {
                            NumberAnimation {
                                duration: surface.slideDuration
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Math.round(surface.slideDuration * 0.55)
                                easing.type: Easing.OutCubic
                            }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            width: Math.min(620, parent.width - 40)
                            spacing: 10

                            Item {
                                Layout.alignment: Qt.AlignHCenter
                                implicitWidth: 150
                                implicitHeight: 150

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 142
                                    height: 142
                                    radius: 71
                                    color: Qt.alpha(Theme.accent, 0.08)

                                    SequentialAnimation on scale {
                                        running: Theme.anim > 0 && surface.page === 4
                                        loops: Animation.Infinite
                                        NumberAnimation {
                                            from: 0.94
                                            to: 1.05
                                            duration: 2600
                                            easing.type: Easing.InOutSine
                                        }
                                        NumberAnimation {
                                            from: 1.05
                                            to: 0.94
                                            duration: 2600
                                            easing.type: Easing.InOutSine
                                        }
                                    }
                                }

                                Item {
                                    anchors.fill: parent

                                    RotationAnimation on rotation {
                                        from: 0
                                        to: 360
                                        duration: 16000
                                        loops: Animation.Infinite
                                        running: Theme.anim > 0 && surface.page === 4
                                    }

                                    Rectangle {
                                        width: 6
                                        height: 6
                                        radius: 3
                                        color: Theme.accent
                                        x: parent.width / 2 - width / 2
                                        y: 0
                                    }
                                }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 104
                                    height: 104
                                    radius: 28
                                    color: Theme.accentSoft
                                }

                                Logo {
                                    anchors.centerIn: parent
                                    size: 78
                                }
                            }

                            Txt {
                                Layout.fillWidth: true
                                text: "Enjoy!"
                                color: Theme.accent
                                font.pixelSize: 44
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                            }
                            Txt {
                                Layout.fillWidth: true
                                text: "That's everything. Reopen this tour from Settings ▸ General whenever you like."
                                color: Theme.subtext
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.Wrap
                            }

                            Card {
                                Layout.fillWidth: true
                                Layout.topMargin: 2
                                padding: 12

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    KeyCap {
                                        text: "SUPER"
                                    }
                                    KeyCap {
                                        text: "SPACE"
                                    }
                                    Txt {
                                        Layout.fillWidth: true
                                        text: "Launch anything"
                                        color: Theme.subtext
                                    }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    KeyCap {
                                        text: "SUPER"
                                    }
                                    KeyCap {
                                        text: "C"
                                    }
                                    Txt {
                                        Layout.fillWidth: true
                                        text: "Open the control centre"
                                        color: Theme.subtext
                                    }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    KeyCap {
                                        text: "SUPER"
                                    }
                                    KeyCap {
                                        text: "T"
                                    }
                                    Txt {
                                        Layout.fillWidth: true
                                        text: "Ask HexinAgent for a hand"
                                        color: Theme.subtext
                                    }
                                }
                            }

                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.topMargin: 2
                                spacing: 10

                                WelcomeButton {
                                    text: "Replay tour"
                                    onClicked: surface.go(0)
                                }
                                WelcomeButton {
                                    text: "Open settings"
                                    onClicked: surface.openSettings("general")
                                }
                            }
                        }
                    }
                }

                // ── footer ──────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    spacing: 10

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1

                        WelcomeButton {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            visible: surface.page < surface.pageCount - 1
                            text: "Skip tour"
                            onClicked: Onboarding.dismiss()
                        }
                    }

                    Row {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 6

                        Repeater {
                            model: surface.pageCount

                            Rectangle {
                                required property int index

                                width: surface.page === index ? 20 : 7
                                height: 7
                                radius: 4
                                color: surface.page === index ? Theme.accent : Theme.surfaceHi

                                Behavior on width {
                                    NumberAnimation {
                                        duration: Theme.animFast
                                        easing.type: Easing.OutCubic
                                    }
                                }
                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.animFast
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: surface.go(index)
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1

                        RowLayout {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            WelcomeButton {
                                visible: surface.page > 0
                                text: "Back"
                                onClicked: surface.previous()
                            }
                            WelcomeButton {
                                primary: true
                                text: surface.page === surface.pageCount - 1 ? "Finish" : "Next"
                                onClicked: surface.next()
                            }
                        }
                    }
                }
            }
        }
    }
}
