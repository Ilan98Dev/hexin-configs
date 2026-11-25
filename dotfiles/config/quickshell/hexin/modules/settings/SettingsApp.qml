import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import qs.components

// The settings app: a normal floating window. Opened from the control panel,
// `qs ipc call settings toggle`, or the quickshell:settings global shortcut.
LazyLoader {
    active: Panels.settingsOpen

    FloatingWindow {
        id: win

        property int page: 0
        readonly property var pages: [
            {
                key: "appearance",
                name: "Appearance",
                glyph: Icons.paint
            },
            {
                key: "wallpaper",
                name: "Wallpaper",
                glyph: Icons.image
            },
            {
                key: "bar",
                name: "Bar",
                glyph: Icons.bars
            },
            {
                key: "notifications",
                name: "Notifications",
                glyph: Icons.bell
            },
            {
                key: "unityagent",
                name: "UnityAgent",
                glyph: Icons.star
            },
            {
                key: "control",
                name: "Control Panel",
                glyph: Icons.sliders
            },
            {
                key: "hyprland",
                name: "Hyprland",
                glyph: Icons.layout
            },
            {
                key: "commands",
                name: "Commands",
                glyph: Icons.terminal
            },
            {
                key: "general",
                name: "General",
                glyph: Icons.cog
            }
        ]

        function revealRequestedPage() {
            if (!Panels.settingsPage.length)
                return;
            const wanted = Panels.settingsPage;
            Panels.settingsPage = "";
            const i = pages.findIndex(p => p.key === wanted);
            if (i >= 0)
                page = i;
        }

        Component.onCompleted: revealRequestedPage()

        Connections {
            target: Panels
            function onSettingsPageChanged() {
                if (Panels.settingsPage.length)
                    win.revealRequestedPage();
            }
        }

        title: "Shell Settings"
        color: Theme.base
        implicitWidth: 1170
        implicitHeight: 680
        visible: true

        onVisibleChanged: if (!visible) Panels.settingsOpen = false

        // Escape closes the window, like the panels and the welcome tour.
        Shortcut {
            sequence: "Escape"
            onActivated: Panels.settingsOpen = false
        }

        onPageChanged: if (Theme.anim > 0) pageAnim.restart()

        RowLayout {
            id: layout
            anchors.fill: parent
            spacing: 0
            opacity: 0

            transform: Translate {
                id: openShift
                y: 10
            }

            Component.onCompleted: {
                if (Theme.anim > 0) {
                    openAnim.start();
                } else {
                    layout.opacity = 1;
                    openShift.y = 0;
                }
            }

            // ───── sidebar ─────
            Rectangle {
                Layout.fillHeight: true
                // Wide enough for the longest label and the footer note, which
                // used to run into the right edge at 230.
                Layout.preferredWidth: 252
                color: Theme.mantle

                ColumnLayout {
                    anchors {
                        fill: parent
                        margins: 14
                    }
                    spacing: 4

                    Txt {
                        text: "Settings"
                        font.pixelSize: Theme.fontLarge + 4
                        font.bold: true
                        Layout.leftMargin: 8
                        Layout.topMargin: 6
                        Layout.bottomMargin: 14
                    }

                    Repeater {
                        model: win.pages

                        Rectangle {
                            id: item

                            required property var modelData
                            required property int index
                            readonly property bool on: win.page === index

                            Layout.fillWidth: true
                            implicitHeight: 40
                            radius: Theme.radiusSmall
                            color: on ? Theme.accentSoft : (ma.containsMouse ? Theme.hover : "transparent")

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.animFast
                                }
                            }

                            RowLayout {
                                anchors {
                                    fill: parent
                                    leftMargin: 12
                                }
                                spacing: 12

                                Item {
                                    Layout.preferredWidth: 22
                                    Layout.preferredHeight: navGlyph.implicitHeight

                                    Glyph {
                                        id: navGlyph
                                        anchors.centerIn: parent
                                        text: item.modelData.glyph
                                        color: item.on ? Theme.accent : Theme.subtext
                                    }
                                }
                                Txt {
                                    text: item.modelData.name
                                    font.bold: item.on
                                    Layout.fillWidth: true
                                }
                            }
                            Rectangle {
                                width: item.on ? 3 : 0
                                height: parent.height - 16
                                radius: 1.5
                                anchors {
                                    left: parent.left
                                    leftMargin: 5
                                    verticalCenter: parent.verticalCenter
                                }
                                color: Theme.accent

                                Behavior on width {
                                    NumberAnimation {
                                        duration: Theme.animFast
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                            MouseArea {
                                id: ma
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.page = item.index
                            }
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    Txt {
                        text: "Changes are saved automatically"
                        color: Theme.subtext
                        font.pixelSize: Theme.fontSmall
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8
                        // Same breathing room as the left indent, so the note
                        // never looks pinned to the bottom edge.
                        Layout.bottomMargin: 8
                    }
                }
            }

            // ───── pages ─────
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                StackLayout {
                    id: stack
                    anchors.fill: parent
                    currentIndex: win.page

                    transform: Translate {
                        id: pageShift
                    }

                    AppearancePage {}
                    WallpaperPage {}
                    BarPage {}
                    NotificationsPage {}
                    UnityAgentPage {}
                    ControlPage {}
                    HyprPage {}
                    AppsPage {}
                    GeneralPage {}
                }
            }
        }

        SequentialAnimation {
            id: pageAnim
            ParallelAnimation {
                NumberAnimation {
                    target: stack
                    property: "opacity"
                    from: 0.35
                    to: 1
                    duration: Theme.anim
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: pageShift
                    property: "y"
                    from: 8
                    to: 0
                    duration: Theme.anim
                    easing.type: Easing.OutCubic
                }
            }
        }

        ParallelAnimation {
            id: openAnim
            NumberAnimation {
                target: layout
                property: "opacity"
                from: 0
                to: 1
                duration: Theme.anim + 80
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: openShift
                property: "y"
                from: 10
                to: 0
                duration: Theme.anim + 120
                easing.type: Easing.OutCubic
            }
        }
    }
}
