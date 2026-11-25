import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.services

// Toast popups, shown on the focused monitor.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property var modelData

        readonly property string pos: Config.notifications.position
        readonly property bool isTop: pos.startsWith("top")
        readonly property bool focusedHere: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name === modelData.name : modelData === Quickshell.screens[0]
        readonly property var items: Notifs.popupList

        screen: modelData
        visible: Config.notifications.popups && items.length > 0 && focusedHere
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: Config.notifications.width
        implicitHeight: Math.max(1, col.implicitHeight)

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-notifications"

        anchors {
            top: isTop
            bottom: !isTop
            left: pos.endsWith("left")
            right: pos.endsWith("right")
        }

        margins {
            top: isTop && Config.bar.enabled && Config.bar.position === "top" ? Panels.barSize + 6 : 12
            bottom: !isTop && Config.bar.enabled && Config.bar.position === "bottom" ? Panels.barSize + 6 : 12
            left: 12
            right: 12
        }

        Column {
            id: col
            width: parent.width
            spacing: 10

            Repeater {
                model: win.items

                NotifCard {
                    required property var modelData
                    width: col.width
                    notif: modelData
                    popup: true
                }
            }
        }
    }
}
