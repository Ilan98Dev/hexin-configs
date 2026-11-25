import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.services
import qs.components

// Small on-screen display for volume / brightness changes.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property var modelData

        property string kind: "volume"   // volume | brightness
        property bool armed: false       // ignore the initial values at startup
        property bool shown: false
        readonly property bool focusedHere: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name === modelData.name : modelData === Quickshell.screens[0]
        readonly property real level: kind === "volume" ? (Audio.muted ? 0 : Audio.volume) : Brightness.value
        readonly property string glyph: kind === "volume" ? Audio.icon : Icons.brightness

        function show(k) {
            if (!armed || !Config.general.osd || Panels.active === "control")
                return;
            kind = k;
            shown = true;
            revealTimer.restart();
            hideTimer.restart();
        }

        screen: modelData
        visible: shown
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: 280
        implicitHeight: 56
        mask: Region {}

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-osd"

        anchors {
            bottom: true
        }
        margins.bottom: 90

        Timer {
            interval: 2500
            running: true
            onTriggered: win.armed = true
        }

        Timer {
            id: hideTimer
            interval: Config.general.osdTimeout
            onTriggered: exitAnim.restart()
        }

        // The surface has to be mapped before the fade is visible.
        Timer {
            id: revealTimer
            interval: 16
            onTriggered: if (win.shown) enterAnim.restart()
        }

        Connections {
            target: Audio
            function onVolumeChanged() {
                if (win.focusedHere)
                    win.show("volume");
            }
            function onMutedChanged() {
                if (win.focusedHere)
                    win.show("volume");
            }
        }

        Connections {
            target: Brightness
            function onValueChanged() {
                if (win.focusedHere)
                    win.show("brightness");
            }
        }

        Rectangle {
            id: osdBox
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.bgSolid
            border.width: 1
            border.color: Theme.border
            opacity: 0
            scale: 0.94
            transformOrigin: Item.Bottom

            Behavior on color {
                ColorAnimation {
                    duration: Theme.animFast
                }
            }
            Behavior on border.color {
                ColorAnimation {
                    duration: Theme.animFast
                }
            }

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 16
                    rightMargin: 16
                }
                spacing: 12

                Item {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: osdGlyph.implicitHeight

                    Glyph {
                        id: osdGlyph
                        anchors.centerIn: parent
                        text: win.glyph
                        color: Theme.accent
                        font.pixelSize: Theme.fontLarge + 2
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 8
                    radius: 4
                    color: Theme.surfaceHi

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, win.level))
                        height: parent.height
                        radius: 4
                        color: Theme.accent

                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.animFast
                            }
                        }
                    }
                }
                Txt {
                    text: Math.round(win.level * 100)
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: 30
                }
            }
        }

        ParallelAnimation {
            id: enterAnim
            NumberAnimation {
                target: osdBox
                property: "opacity"
                to: 1
                duration: Theme.animFast
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: osdBox
                property: "scale"
                to: 1
                duration: Theme.anim
                easing.type: Easing.OutCubic
            }
        }

        ParallelAnimation {
            id: exitAnim
            NumberAnimation {
                target: osdBox
                property: "opacity"
                to: 0
                duration: Theme.animFast
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: osdBox
                property: "scale"
                to: 0.96
                duration: Theme.animFast
                easing.type: Easing.InCubic
            }
            onFinished: win.shown = false
        }
    }
}
