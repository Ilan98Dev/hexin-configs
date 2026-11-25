import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import qs.components

SettingsPage {
    title: "Notifications"
    subtitle: "Toasts and the notification center."

    SettingRow {
        title: "Show popups"
        description: "When off, notifications still land in the notification center."

        Toggle {
            checked: Config.notifications.popups
            onToggled: v => Config.notifications.popups = v
        }
    }
    SettingRow {
        title: "Do Not Disturb"

        Toggle {
            checked: Config.notifications.dnd
            onToggled: v => Config.notifications.dnd = v
        }
    }
    SettingRow {
        title: "Critical notifications bypass DND"

        Toggle {
            checked: Config.notifications.criticalBypassDnd
            onToggled: v => Config.notifications.criticalBypassDnd = v
        }
    }

    SectionLabel {
        text: "Popups"
    }

    SettingRow {
        title: "Position"

        Segmented {
            options: [
                {
                    label: "Top left",
                    value: "top-left"
                },
                {
                    label: "Top",
                    value: "top-center"
                },
                {
                    label: "Top right",
                    value: "top-right"
                },
                {
                    label: "Bottom left",
                    value: "bottom-left"
                },
                {
                    label: "Bottom right",
                    value: "bottom-right"
                }
            ]
            current: Config.notifications.position
            onSelected: v => Config.notifications.position = v
        }
    }
    SettingRow {
        title: "Timeout"
        description: "Seconds before a popup hides. 0 keeps it until dismissed. Critical notifications never time out."

        ValueSlider {
            from: 0
            to: 30
            step: 1
            suffix: " s"
            value: Config.notifications.timeout
            onMoved: v => Config.notifications.timeout = Math.round(v)
        }
    }
    SettingRow {
        title: "Max visible popups"

        ValueSlider {
            from: 1
            to: 8
            step: 1
            value: Config.notifications.maxPopups
            onMoved: v => Config.notifications.maxPopups = Math.round(v)
        }
    }
    SettingRow {
        title: "Popup width"

        ValueSlider {
            from: 260
            to: 560
            step: 10
            suffix: " px"
            value: Config.notifications.width
            onMoved: v => Config.notifications.width = Math.round(v)
        }
    }

    SectionLabel {
        text: "Try it"
    }

    SettingRow {
        title: "Send test notifications"
        description: "Uses notify-send (libnotify)."

        Rectangle {
            implicitWidth: t1.implicitWidth + 24
            implicitHeight: 32
            radius: Theme.radiusSmall
            color: Theme.accent

            Txt {
                id: t1
                anchors.centerIn: parent
                text: "Normal"
                color: Theme.onAccent
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["notify-send", "-a", "Quickshell", "Hello from your shell", "Notifications look like this. <b>Bold</b> and <i>italic</i> work too."])
            }
        }
        Rectangle {
            implicitWidth: t2.implicitWidth + 24
            implicitHeight: 32
            radius: Theme.radiusSmall
            color: Theme.red

            Txt {
                id: t2
                anchors.centerIn: parent
                text: "Critical"
                color: Theme.base
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["notify-send", "-a", "Quickshell", "-u", "critical", "Battery critically low", "Plug in your charger. Critical notifications stay until dismissed."])
            }
        }
    }
}
