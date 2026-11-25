import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

SettingsPage {
    title: "Hyprland"
    subtitle: "Tune the compositor from here. Changes apply live and are saved to the file hyprland.lua loads."

    SettingRow {
        title: "Manage from hexin"
        description: "When on, the controls below apply with hyprctl eval and save to " + Hypr.confPath + "."

        Toggle {
            checked: Config.hyprland.manage
            onToggled: v => Config.hyprland.manage = v
        }
    }

    SectionLabel {
        text: "Layout"
    }

    SettingRow {
        title: "Inner gaps"

        ValueSlider {
            from: 0
            to: 40
            step: 1
            suffix: " px"
            value: Config.hyprland.gaps_in
            onMoved: v => {
                Config.hyprland.gaps_in = Math.round(v);
                Hypr.apply("gaps_in", Math.round(v));
            }
        }
    }
    SettingRow {
        title: "Outer gaps"

        ValueSlider {
            from: 0
            to: 60
            step: 1
            suffix: " px"
            value: Config.hyprland.gaps_out
            onMoved: v => {
                Config.hyprland.gaps_out = Math.round(v);
                Hypr.apply("gaps_out", Math.round(v));
            }
        }
    }
    SettingRow {
        title: "Border size"

        ValueSlider {
            from: 0
            to: 10
            step: 1
            suffix: " px"
            value: Config.hyprland.border_size
            onMoved: v => {
                Config.hyprland.border_size = Math.round(v);
                Hypr.apply("border_size", Math.round(v));
            }
        }
    }
    SettingRow {
        title: "Corner rounding"

        ValueSlider {
            from: 0
            to: 24
            step: 1
            suffix: " px"
            value: Config.hyprland.rounding
            onMoved: v => {
                Config.hyprland.rounding = Math.round(v);
                Hypr.apply("rounding", Math.round(v));
            }
        }
    }

    SectionLabel {
        text: "Effects"
    }

    SettingRow {
        title: "Animations"

        Toggle {
            checked: Config.hyprland.animations
            onToggled: v => {
                Config.hyprland.animations = v;
                Hypr.apply("animations", v);
            }
        }
    }
    SettingRow {
        title: "Active opacity"

        ValueSlider {
            from: 0.5
            to: 1.0
            step: 0.05
            suffix: ""
            value: Config.hyprland.activeOpacity
            onMoved: v => {
                Config.hyprland.activeOpacity = Math.round(v * 100) / 100;
                Hypr.apply("activeOpacity", Math.round(v * 100) / 100);
            }
        }
    }
    SettingRow {
        title: "Inactive opacity"

        ValueSlider {
            from: 0.5
            to: 1.0
            step: 0.05
            suffix: ""
            value: Config.hyprland.inactiveOpacity
            onMoved: v => {
                Config.hyprland.inactiveOpacity = Math.round(v * 100) / 100;
                Hypr.apply("inactiveOpacity", Math.round(v * 100) / 100);
            }
        }
    }
    SettingRow {
        title: "Blur"

        Toggle {
            checked: Config.hyprland.blur
            onToggled: v => {
                Config.hyprland.blur = v;
                Hypr.apply("blur", v);
            }
        }
    }
    SettingRow {
        title: "Blur size"

        ValueSlider {
            from: 1
            to: 15
            step: 1
            suffix: " px"
            value: Config.hyprland.blurSize
            onMoved: v => {
                Config.hyprland.blurSize = Math.round(v);
                Hypr.apply("blurSize", Math.round(v));
            }
        }
    }
    SettingRow {
        title: "Blur passes"

        ValueSlider {
            from: 1
            to: 4
            step: 1
            value: Config.hyprland.blurPasses
            onMoved: v => {
                Config.hyprland.blurPasses = Math.round(v);
                Hypr.apply("blurPasses", Math.round(v));
            }
        }
    }
    SettingRow {
        title: "Shadows"

        Toggle {
            checked: Config.hyprland.shadow
            onToggled: v => {
                Config.hyprland.shadow = v;
                Hypr.apply("shadow", v);
            }
        }
    }
    SettingRow {
        title: "Shadow range"

        ValueSlider {
            from: 1
            to: 40
            step: 1
            suffix: " px"
            value: Config.hyprland.shadowRange
            onMoved: v => {
                Config.hyprland.shadowRange = Math.round(v);
                Hypr.apply("shadowRange", Math.round(v));
            }
        }
    }
    SettingRow {
        title: "Accent-coloured window borders"
        description: "Colour the active window border with the current theme accent."

        Toggle {
            checked: Config.hyprland.accentBorders
            onToggled: v => {
                Config.hyprland.accentBorders = v;
                Hypr.apply("accentBorders", v);
            }
        }
    }

    SectionLabel {
        text: "Status"
    }

    Card {
        Layout.fillWidth: true
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                width: 8
                height: 8
                radius: 4
                color: Hypr.active ? Theme.green : Theme.red
            }
            Txt {
                Layout.fillWidth: true
                text: Hypr.active ? "Connected to a running Hyprland session." : "Not running under Hyprland — changes can't be applied live."
                color: Theme.subtext
                wrapMode: Text.Wrap
            }
            Rectangle {
                implicitWidth: readLbl.implicitWidth + 24
                implicitHeight: 30
                radius: Theme.radiusSmall
                color: readMa.containsMouse ? Theme.hover : Theme.surfaceHi
                opacity: Hypr.active ? 1 : 0.4

                Txt {
                    id: readLbl
                    anchors.centerIn: parent
                    text: "Read current"
                }
                MouseArea {
                    id: readMa
                    anchors.fill: parent
                    enabled: Hypr.active
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hypr.importFromCompositor()
                }
            }
        }
    }

    Card {
        Layout.fillWidth: true
        spacing: 4

        Txt {
            text: "Where these are saved"
            font.bold: true
        }
        Txt {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Theme.subtext
            text: "hyprland.lua loads this one file, so the values survive a reload and your next login:"
        }
        Txt {
            Layout.fillWidth: true
            wrapMode: Text.WrapAnywhere
            color: Theme.accent
            font.family: "monospace"
            font.pixelSize: Theme.fontSmall + 1
            text: Hypr.confPath
        }
    }
}
