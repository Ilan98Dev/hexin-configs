import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import Quickshell.Bluetooth
import qs.config
import qs.services
import qs.components


Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property var modelData
        readonly property string screenName: modelData.name

        screen: modelData
        visible: Config.bar.enabled
        color: "transparent"
        implicitHeight: Panels.barSize

        WlrLayershell.namespace: "qs-bar"

        anchors {
            top: Config.bar.position === "top"
            bottom: Config.bar.position === "bottom"
            left: true
            right: true
        }

        Rectangle {
            id: bar
            anchors.fill: parent
            anchors.margins: Config.bar.floating ? Config.bar.margin : 0
            color: Theme.bg
            radius: Config.bar.floating ? Theme.radius : 0
            border.width: Config.bar.floating ? 1 : 0
            border.color: Theme.border

            Behavior on color {
                ColorAnimation {
                    duration: Theme.anim
                }
            }
            Behavior on border.color {
                ColorAnimation {
                    duration: Theme.anim
                }
            }

            // ───────────── center ─────────────
            Pill {
                id: centerPill
                anchors.centerIn: parent
                solid: true
                active: Panels.active === "calendar" && Panels.screenName === win.screenName
                onClicked: Panels.toggle("calendar", win.screenName)

                Txt {
                    text: Time.timeString
                    font.bold: true
                }
                Txt {
                    text: Time.dateString
                    color: Theme.subtext
                }
            }

            // ───────────── left ─────────────
            RowLayout {
                id: leftRow
                anchors {
                    left: parent.left
                    leftMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                // Stop before the centred clock even if the title width setting
                // is larger than the free space.
                width: Math.max(0, Math.min(implicitWidth, centerPill.x - x - 12))
                spacing: 6

                Repeater {
                    model: BarItems.leftOrderList()

                    delegate: Loader {
                        readonly property string itemId: modelData
                        // The loaded item is not a direct child of the RowLayout,
                        // so layout attached properties on WindowTitle do not
                        // apply. Cap the Loader itself or a long title runs under
                        // the centred clock.
                        Layout.maximumWidth: itemId === "windowTitle" ? Config.bar.windowTitleWidth : Number.POSITIVE_INFINITY
                        // Let the title shrink below its configured maximum when
                        // the left row is squeezed, so it elides instead of
                        // running under the clock.
                        Layout.fillWidth: itemId === "windowTitle"
                        // QQuickLoader keeps its last explicit width after active
                        // goes false, which would leave a dead slot in the row;
                        // layouts skip invisible items (and their spacing), so
                        // gate on having something loaded. Do NOT read item.visible
                        // here: it is effective visibility → binding loop.
                        visible: active && item !== null
                        opacity: visible ? 1 : 0
                        scale: visible ? 1 : 0.94

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.animFast
                            }
                        }
                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.animFast
                                easing.type: Easing.OutCubic
                            }
                        }
                        active: {
                            if (itemId === "launcher") return Config.bar.showLauncher;
                            if (itemId === "workspaces") return Config.bar.showWorkspaces;
                            if (itemId === "windowTitle") return Config.bar.showWindowTitle;
                            return true;
                        }
                        sourceComponent: {
                            if (itemId === "launcher") return launcherComp;
                            if (itemId === "workspaces") return wsComp;
                            if (itemId === "windowTitle") return wtComp;
                            return null;
                        }
                    }
                }

                Component {
                    id: launcherComp
                    Pill {
                        solid: true
                        padding: 8
                        active: Panels.active === "launcher" && Panels.screenName === win.screenName
                        onClicked: Actions.launcher()
                        Logo {
                            // Leave a little breathing room inside the pill; the
                            // star's ring otherwise sits flush against the edge.
                            size: Theme.fontSize + 7
                            useImage: Config.bar.launcherIcon.length === 0
                            glyph: Config.bar.launcherIcon
                            glyphSize: Theme.fontSize + 5
                        }
                    }
                }

                Component {
                    id: wsComp
                    Workspaces {
                        monitorScreen: win.modelData
                    }
                }

                Component {
                    id: wtComp
                    WindowTitle {
                        visible: text !== ""
                    }
                }
            }

            // ───────────── right ─────────────
            RowLayout {
                id: rightRow
                anchors {
                    right: parent.right
                    rightMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                spacing: 6

                Repeater {
                    model: BarItems.rightOrderList()

                    delegate: Loader {
                        readonly property string itemId: modelData
                        visible: active && item !== null
                        opacity: visible ? 1 : 0
                        scale: visible ? 1 : 0.94

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.animFast
                            }
                        }
                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.animFast
                                easing.type: Easing.OutCubic
                            }
                        }
                        active: {
                            if (itemId === "media") return Config.bar.showMedia && Media.player !== null && Media.title !== "";
                            if (itemId === "tray") return Config.bar.showTray && SystemTray.items.values.length > 0;
                            if (itemId === "stats") return Config.bar.showStats;
                            if (itemId === "status") return Config.bar.showStatus && (Config.bar.showVolume || Config.bar.showNetwork || Config.bar.showBluetooth || Config.bar.showBattery);
                            if (itemId === "recording") return Config.bar.showRecording && Recorder.recording;
                            if (itemId === "notifications") return Config.bar.showNotifications;
                            return true;
                        }
                        sourceComponent: {
                            if (itemId === "media") return mediaComp;
                            if (itemId === "tray") return trayComp;
                            if (itemId === "stats") return statsComp;
                            if (itemId === "status") return statusComp;
                            if (itemId === "recording") return recordingComp;
                            if (itemId === "notifications") return notifComp;
                            return null;
                        }
                    }
                }

                Component {
                    id: mediaComp
                    Pill {
                        solid: true
                        onClicked: if (Media.player && Media.player.canTogglePlaying) Media.player.togglePlaying()
                        onRightClicked: if (Media.player && Media.player.canGoNext) Media.player.next()
                        onMiddleClicked: if (Media.player && Media.player.canGoPrevious) Media.player.previous()

                        Glyph {
                            text: Media.playing ? Icons.pause : Icons.play
                            color: Theme.accent
                            font.pixelSize: Theme.fontSmall + 1
                        }
                        Txt {
                            text: Media.label
                            elide: Text.ElideRight
                            Layout.maximumWidth: 220
                        }
                    }
                }

                Component {
                    id: trayComp
                    Pill {
                        interactive: false
                        solid: true
                        padding: 8

                        Repeater {
                            model: SystemTray.items

                            TrayItem {
                                required property var modelData
                                item: modelData
                                barWindow: win
                            }
                        }
                    }
                }

                Component {
                    id: statsComp
                    Pill {
                        interactive: false
                        solid: true

                        Glyph {
                            text: Icons.cpu
                            color: Theme.blue
                            font.pixelSize: Theme.fontSmall + 2
                        }
                        Txt {
                            text: Math.round(SysStats.cpu * 100) + "%"
                        }
                        Glyph {
                            text: Icons.ram
                            color: Theme.green
                            font.pixelSize: Theme.fontSmall + 2
                        }
                        Txt {
                            text: Math.round(SysStats.mem * 100) + "%"
                        }
                    }
                }

                Component {
                    id: statusComp
                    Pill {
                        active: Panels.active === "control" && Panels.screenName === win.screenName
                        solid: true
                        onClicked: Panels.toggle("control", win.screenName)
                        onMiddleClicked: Audio.toggleMute()
                        onWheel: event => Audio.step(event.angleDelta.y > 0 ? 0.05 : -0.05)

                        Glyph {
                            visible: Config.bar.showVolume
                            text: Audio.icon
                            color: Audio.muted ? Theme.subtext : Theme.text
                        }
                        Txt {
                            visible: Config.bar.showVolume
                            text: Math.round(Audio.volume * 100) + "%"
                        }
                        Glyph {
                            visible: Config.bar.showNetwork
                            text: Net.icon
                            color: Net.connected && Net.wifiEnabled ? Theme.text : Theme.subtext
                        }
                        Glyph {
                            visible: Config.bar.showBluetooth && Bluetooth.defaultAdapter !== null
                            text: Icons.bluetooth
                            color: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled ? (Bluetooth.devices.values.some(d => d.connected) ? Theme.accent : Theme.text) : Theme.subtext
                        }
                        Glyph {
                            visible: Config.bar.showBattery && Power.present
                            text: Power.icon
                            color: Power.color
                        }
                        Txt {
                            visible: Config.bar.showBattery && Power.present
                            text: Power.percent + "%"
                            color: Power.color
                        }
                    }
                }

                Component {
                    id: notifComp
                    Pill {
                        active: Panels.active === "notifications" && Panels.screenName === win.screenName
                        solid: true
                        onClicked: Panels.toggle("notifications", win.screenName)
                        onRightClicked: Notifs.toggleDnd()

                        Glyph {
                            text: Notifs.dnd ? Icons.bellSlash : Icons.bell
                            color: Notifs.dnd ? Theme.subtext : Theme.text
                        }
                        Rectangle {
                            id: notifBadge
                            visible: Notifs.count > 0
                            Layout.preferredWidth: Math.max(18, badge.implicitWidth + 8)
                            Layout.preferredHeight: 18
                            radius: 9
                            color: Theme.accent

                            Behavior on scale {
                                NumberAnimation {
                                    duration: Theme.animFast
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Connections {
                                target: Notifs
                                function onCountChanged() {
                                    if (Notifs.count > 0)
                                        badgePop.restart();
                                }
                            }

                            SequentialAnimation {
                                id: badgePop
                                NumberAnimation {
                                    target: notifBadge
                                    property: "scale"
                                    to: 1.35
                                    duration: Theme.animFast
                                    easing.type: Easing.OutCubic
                                }
                                NumberAnimation {
                                    target: notifBadge
                                    property: "scale"
                                    to: 1
                                    duration: Math.max(1, Theme.animFast)
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Txt {
                                id: badge
                                anchors.centerIn: parent
                                text: Notifs.count > 99 ? "99+" : Notifs.count
                                color: Theme.onAccent
                                font.pixelSize: Theme.fontSmall
                                font.bold: true
                            }
                        }
                    }
                }

                // REC + stop. A normal bar item now, so Settings > Bar can
                // reorder it within the right side or hide it; the loader only
                // instantiates it while a recording is running.
                Component {
                    id: recordingComp
                    Pill {
                        solid: true
                        padding: 8
                        onClicked: Recorder.stop()

                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            color: Theme.red

                            SequentialAnimation on opacity {
                                running: Theme.anim > 0 && Recorder.recording
                                loops: Animation.Infinite
                                NumberAnimation {
                                    to: 0.3
                                    duration: 650
                                    easing.type: Easing.InOutSine
                                }
                                NumberAnimation {
                                    to: 1
                                    duration: 650
                                    easing.type: Easing.InOutSine
                                }
                            }
                        }
                        Txt {
                            text: "REC"
                            color: Theme.red
                            font.bold: true
                            font.pixelSize: Theme.fontSmall + 1
                        }
                        Txt {
                            text: Recorder.elapsedLabel
                            font.pixelSize: Theme.fontSmall
                        }
                        Glyph {
                            text: Icons.stop
                            color: Theme.red
                            font.pixelSize: Theme.fontSmall + 2
                        }
                    }
                }
            }
        }
    }
}
