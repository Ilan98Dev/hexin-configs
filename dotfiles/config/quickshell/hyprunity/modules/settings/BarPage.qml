import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

SettingsPage {
    title: "Bar"
    subtitle: "Layout and contents of the top bar."

    SettingRow {
        title: "Show bar"

        Toggle {
            checked: Config.bar.enabled
            onToggled: v => Config.bar.enabled = v
        }
    }

    SectionLabel {
        text: "Arrange"
    }
    BarArrange {
        section: "left"
        Layout.fillWidth: true
    }
    BarArrange {
        section: "center"
        Layout.fillWidth: true
    }
    BarArrange {
        section: "right"
        Layout.fillWidth: true
    }
    Txt {
        text: "Each item keeps its side — drag within a strip to reorder it. Center stays centred."
        color: Theme.subtext
        font.pixelSize: Theme.fontSmall
        wrapMode: Text.Wrap
        Layout.fillWidth: true
        Layout.bottomMargin: 4
    }

    SectionLabel {
        text: "Layout"
    }

    SettingRow {
        title: "Position"

        Segmented {
            options: [
                {
                    label: "Top",
                    value: "top"
                },
                {
                    label: "Bottom",
                    value: "bottom"
                }
            ]
            current: Config.bar.position
            onSelected: v => Config.bar.position = v
        }
    }
    SettingRow {
        title: "Floating"
        description: "Detach the bar from the screen edges with rounded corners."

        Toggle {
            checked: Config.bar.floating
            onToggled: v => Config.bar.floating = v
        }
    }
    SettingRow {
        title: "Height"

        ValueSlider {
            from: 28
            to: 60
            step: 1
            suffix: " px"
            value: Config.bar.height
            onMoved: v => Config.bar.height = Math.round(v)
        }
    }
    SettingRow {
        title: "Floating margin"

        ValueSlider {
            from: 0
            to: 20
            step: 1
            suffix: " px"
            value: Config.bar.margin
            onMoved: v => Config.bar.margin = Math.round(v)
        }
    }

    SectionLabel {
        text: "Left"
    }

    SettingRow {
        title: "Launcher button glyph"
        description: "Leave empty to show the UnityOS star image. Any glyph here replaces the image in the bar."

        RowLayout {
            spacing: 8

            Logo {
                Layout.alignment: Qt.AlignVCenter
                size: 26
                useImage: Config.bar.launcherIcon.length === 0
                glyph: Config.bar.launcherIcon
                glyphSize: Theme.fontSmall + 3
            }

            Input {
                implicitWidth: 70
                text: Config.bar.launcherIcon
                placeholder: "image"
                onCommitted: value => Config.bar.launcherIcon = value
            }

            IconButton {
                visible: Config.bar.launcherIcon.length > 0
                glyph: Icons.refresh
                glyphSize: Theme.fontSmall + 3
                size: 32
                onClicked: Config.bar.launcherIcon = ""
            }
        }
    }
    SettingRow {
        title: "Workspace style"

        Segmented {
            options: [
                {
                    label: "Dots",
                    value: "dots"
                },
                {
                    label: "Numbers",
                    value: "numbers"
                }
            ]
            current: Config.bar.workspaceStyle
            onSelected: v => Config.bar.workspaceStyle = v
        }
    }
    SettingRow {
        title: "Workspace count"

        ValueSlider {
            from: 1
            to: 10
            step: 1
            value: Config.bar.workspaceCount
            onMoved: v => Config.bar.workspaceCount = Math.round(v)
        }
    }
    SettingRow {
        title: "Active window title"

        Toggle {
            checked: Config.bar.showWindowTitle
            onToggled: v => Config.bar.showWindowTitle = v
        }
    }
    SettingRow {
        title: "Window title max width"

        ValueSlider {
            from: 100
            to: 600
            step: 10
            suffix: " px"
            value: Config.bar.windowTitleWidth
            onMoved: v => Config.bar.windowTitleWidth = Math.round(v)
        }
    }

    SectionLabel {
        text: "Clock"
    }

    SettingRow {
        title: "Show seconds"

        Toggle {
            checked: Config.bar.clockSeconds
            onToggled: v => Config.bar.clockSeconds = v
        }
    }
    SettingRow {
        title: "Date format"
        description: "Qt format string, e.g. ddd d MMM, dd/MM, MMMM d."

        Input {
            text: Config.bar.dateFormat
            onCommitted: value => Config.bar.dateFormat = value
        }
    }

    SectionLabel {
        text: "Status cluster"
    }
    SettingRow {
        title: "Show status cluster"

        Toggle {
            checked: Config.bar.showStatus
            onToggled: v => Config.bar.showStatus = v
        }
    }
    SettingRow {
        title: "Volume"
        description: "Scroll to change volume, middle-click to mute, click for the control panel."

        Toggle {
            checked: Config.bar.showVolume
            onToggled: v => Config.bar.showVolume = v
        }
    }
    SettingRow {
        title: "Network"

        Toggle {
            checked: Config.bar.showNetwork
            onToggled: v => Config.bar.showNetwork = v
        }
    }
    SettingRow {
        title: "Bluetooth"

        Toggle {
            checked: Config.bar.showBluetooth
            onToggled: v => Config.bar.showBluetooth = v
        }
    }
    SettingRow {
        title: "Battery"

        Toggle {
            checked: Config.bar.showBattery
            onToggled: v => Config.bar.showBattery = v
        }
    }
    SettingRow {
        title: "Notification bell"
        description: "Right-click toggles Do Not Disturb."

        Toggle {
            checked: Config.bar.showNotifications
            onToggled: v => Config.bar.showNotifications = v
        }
    }
}
