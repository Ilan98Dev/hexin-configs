import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import qs.components

// The UnityAgent window. A real floating window (not a layer-shell drawer)
// with a staggered reveal: the frame blooms, the sidebar rows cascade, the
// chat column slides in, and the composer glides from the middle to the bottom
// when the first message is sent.
LazyLoader {
    id: loader

    active: UnityAgent.visible

    FloatingWindow {
        id: win

        title: "UnityAgent"
        color: "transparent"
        implicitWidth: 1100
        implicitHeight: 720
        visible: true

        onVisibleChanged: if (!visible)
            UnityAgent.close()

        Component.onCompleted: {
            if (UnityAgent.view === "chat")
                Qt.callLater(chat.focusComposer);
        }

        // Keep keyboard focus on the visible page: otherwise the hidden
        // composer keeps the focus and PageUp/PageDown do nothing in settings.
        Connections {
            target: UnityAgent
            function onViewChanged() {
                if (UnityAgent.view === "settings")
                    Qt.callLater(settingsView.forceActiveFocus)
                else
                    Qt.callLater(chat.focusComposer)
            }
        }

        Rectangle {
            id: surface

            anchors.fill: parent
            // A chat window has to be readable: keep the frame opaque even when
            // the rest of the desktop runs translucent.
            color: Theme.base
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.lighter(Theme.base, 1.10)
                }
                GradientStop {
                    position: 0.32
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

            opacity: 0
            scale: 0.94
            transformOrigin: Item.Center

            Component.onCompleted: {
                if (Theme.anim <= 0) {
                    surface.opacity = 1;
                    surface.scale = 1;
                    return;
                }
                entrance.start();
            }

            ParallelAnimation {
                id: entrance
                NumberAnimation {
                    target: surface
                    property: "opacity"
                    to: 1
                    duration: Math.max(140, Theme.anim + 80)
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: surface
                    property: "scale"
                    to: 1
                    duration: Math.max(260, Theme.anim + 220)
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.12
                }
            }

            // ───────────── ambient colour ─────────────
            Item {
                id: ambient
                anchors.fill: parent
                clip: true
                visible: Theme.anim > 0
                opacity: 0.3

                Rectangle {
                    width: 460
                    height: 460
                    radius: 230
                    color: Theme.accent
                    opacity: 0.06
                    x: -140
                    y: -180

                    SequentialAnimation on x {
                        running: Theme.anim > 0
                        loops: Animation.Infinite
                        NumberAnimation {
                            to: 120
                            duration: 9000
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            to: -140
                            duration: 9000
                            easing.type: Easing.InOutSine
                        }
                    }
                    SequentialAnimation on y {
                        running: Theme.anim > 0
                        loops: Animation.Infinite
                        NumberAnimation {
                            to: 40
                            duration: 11000
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            to: -180
                            duration: 11000
                            easing.type: Easing.InOutSine
                        }
                    }
                }

                Rectangle {
                    width: 520
                    height: 520
                    radius: 260
                    color: Theme.blue
                    opacity: 0.05
                    x: ambient.width - 300
                    y: ambient.height - 340

                    SequentialAnimation on x {
                        running: Theme.anim > 0
                        loops: Animation.Infinite
                        NumberAnimation {
                            to: ambient.width - 460
                            duration: 13000
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            to: ambient.width - 300
                            duration: 13000
                            easing.type: Easing.InOutSine
                        }
                    }
                    SequentialAnimation on y {
                        running: Theme.anim > 0
                        loops: Animation.Infinite
                        NumberAnimation {
                            to: ambient.height - 220
                            duration: 10000
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            to: ambient.height - 340
                            duration: 10000
                            easing.type: Easing.InOutSine
                        }
                    }
                }
            }

            // ───────────── top accent sweep ─────────────
            Rectangle {
                id: sweep

                width: 220
                height: 2
                y: 0
                radius: 1
                visible: Theme.anim > 0
                opacity: 0.85
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0
                        color: Qt.alpha(Theme.accent, 0)
                    }
                    GradientStop {
                        position: 0.5
                        color: Theme.accent
                    }
                    GradientStop {
                        position: 1
                        color: Qt.alpha(Theme.accent, 0)
                    }
                }

                SequentialAnimation on x {
                    running: Theme.anim > 0
                    loops: Animation.Infinite
                    NumberAnimation {
                        from: -240
                        to: surface.width + 20
                        duration: 4200
                        easing.type: Easing.InOutCubic
                    }
                    PauseAnimation {
                        duration: 2600
                    }
                }
            }

            // ───────────── drag strip ─────────────
            MouseArea {
                height: 10
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.SizeAllCursor
                onPressed: win.startSystemMove()
            }

            // ───────────── content ─────────────
            RowLayout {
                anchors {
                    fill: parent
                    margins: 1
                }
                spacing: 0

                AgentSidebar {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 258
                }

                Item {
                    id: content

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ChatView {
                        id: chat
                        anchors.fill: parent
                        visible: opacity > 0
                        opacity: UnityAgent.view === "chat" ? 1 : 0
                        transform: Translate {
                            x: UnityAgent.view === "chat" ? 0 : -22
                            Behavior on x {
                                NumberAnimation {
                                    duration: Math.max(1, Theme.anim + 40)
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Math.max(1, Theme.anim + 20)
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    AgentSettingsView {
                        id: settingsView
                        anchors.fill: parent
                        visible: opacity > 0
                        opacity: UnityAgent.view === "settings" ? 1 : 0
                        transform: Translate {
                            x: UnityAgent.view === "settings" ? 0 : 22
                            Behavior on x {
                                NumberAnimation {
                                    duration: Math.max(1, Theme.anim + 40)
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Math.max(1, Theme.anim + 20)
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }
        }

        // When the view flips, slide/fade and return focus to the composer.
        Connections {
            target: UnityAgent
            function onViewChanged() {
                if (UnityAgent.view === "chat")
                    Qt.callLater(chat.focusComposer);
                else
                    settingsView.forceActiveFocus();
            }
        }
    }
}
