import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

SettingsPage {
    id: root

    title: "Appearance"
    subtitle: "Theme, colours, fonts and motion. Changes apply instantly."

    readonly property var accents: ["#F97316", "#7C3AED", "#EAB308", "#cba6f7", "#89b4fa", "#74c7ec", "#94e2d5", "#a6e3a1", "#f9e2af", "#f38ba8", "#ffffff"]

    SectionLabel {
        text: "Theme preset"
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 3
        columnSpacing: 10
        rowSpacing: 10

        Repeater {
            model: Theme.names

            Rectangle {
                id: card

                required property string modelData
                readonly property var pal: Theme.presets[modelData]
                readonly property bool selected: Config.appearance.preset === modelData
                readonly property bool isAuto: modelData === "Auto (Matugen)"
                readonly property bool autoAllowed: !Theme.isDefaultWallpaper

                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: 78
                radius: Theme.radiusSmall + 2
                color: pal.base
                border.width: selected ? 2 : 1
                border.color: selected ? Theme.accent : Theme.border
                opacity: (isAuto && !autoAllowed) ? 0.35 : 1.0

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    Row {
                        spacing: 6
                        Layout.alignment: Qt.AlignHCenter

                        Repeater {
                            model: ["accent", "red", "green", "yellow", "blue"]

                            Rectangle {
                                required property string modelData
                                width: 14
                                height: 14
                                radius: 7
                                color: card.pal[modelData]
                            }
                        }
                    }
                    Txt {
                        text: card.modelData
                        color: card.pal.text
                        font.pixelSize: Theme.fontSmall + 1
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: (card.isAuto && !card.autoAllowed) ? Qt.ForbiddenCursor : Qt.PointingHandCursor
                    onClicked: {
                        if (card.isAuto && !card.autoAllowed)
                            return
                        Config.appearance.preset = card.modelData
                        if (card.modelData === "Auto (Matugen)" && (Config.appearance.accent === "#F97316" || Config.appearance.accent === "#f97316" || Config.appearance.accent === ""))
                            Config.appearance.accent = ""
                    }
                }
            }
        }
    }

    SectionLabel {
        text: "Accent colour"
    }

    SettingRow {
        title: "Accent"
        description: "Pick a swatch or type a hex colour. Leave empty to use the preset's own accent."

        Row {
            spacing: 6
            Repeater {
                model: root.accents

                Rectangle {
                    required property string modelData
                    width: 22
                    height: 22
                    radius: 11
                    color: modelData
                    border.width: Config.appearance.accent.toLowerCase() === modelData.toLowerCase() ? 2 : 1
                    border.color: Config.appearance.accent.toLowerCase() === modelData.toLowerCase() ? Theme.text : Theme.border

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Config.appearance.accent = parent.modelData
                    }
                }
            }
        }
        Input {
            implicitWidth: 110
            text: Config.appearance.accent
            placeholder: "preset"
            valid: text === "" || /^#([0-9a-fA-F]{6})$/.test(text)
            onCommitted: value => {
                if (value === "" || /^#([0-9a-fA-F]{6})$/.test(value))
                    Config.appearance.accent = value.toLowerCase();
            }
        }
    }

    SectionLabel {
        text: "Shape & transparency"
    }

    SettingRow {
        title: "Panel opacity"
        description: "Background opacity of the bar and panels. Add a blur layer rule in Hyprland for frosted glass."

        ValueSlider {
            from: 0.3
            to: 1
            step: 0.02
            decimals: 2
            value: Config.appearance.opacity
            onMoved: v => Config.appearance.opacity = v
        }
    }
    SettingRow {
        title: "Corner radius"

        ValueSlider {
            from: 0
            to: 28
            step: 1
            suffix: " px"
            value: Config.appearance.radius
            onMoved: v => Config.appearance.radius = Math.round(v)
        }
    }

    SectionLabel {
        text: "Typography"
    }

    SettingRow {
        title: "Font family"
        description: "Any installed font. The field turns red if Qt can't find it."

        Input {
            text: Config.appearance.font
            valid: text === "sans-serif" || text === "monospace" || Qt.fontFamilies().indexOf(text) >= 0
            onCommitted: value => {
                if (value !== "")
                    Config.appearance.font = value;
            }
        }
    }
    SettingRow {
        title: "Icon font"
        description: "A Nerd Font (or any font with Font Awesome glyphs)."

        Input {
            text: Config.appearance.iconFont
            valid: Qt.fontFamilies().indexOf(text) >= 0
            onCommitted: value => {
                if (value !== "")
                    Config.appearance.iconFont = value;
            }
        }
    }
    SettingRow {
        title: "Font size"

        ValueSlider {
            from: 10
            to: 20
            step: 1
            suffix: " px"
            value: Config.appearance.fontSize
            onMoved: v => Config.appearance.fontSize = Math.round(v)
        }
    }

    SectionLabel {
        text: "Motion"
    }

    SettingRow {
        title: "Animations"

        Toggle {
            checked: Config.appearance.animations
            onToggled: v => Config.appearance.animations = v
        }
    }
    SettingRow {
        title: "Animation duration"

        ValueSlider {
            from: 60
            to: 500
            step: 10
            suffix: " ms"
            value: Config.appearance.animDuration
            onMoved: v => Config.appearance.animDuration = Math.round(v)
        }
    }
}
