import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import qs.components

SettingsPage {
    title: "General"
    subtitle: "Calendar, on-screen display, and maintenance."

    SectionLabel {
        text: "Calendar"
    }

    SettingRow {
        title: "Week starts on Monday"

        Toggle {
            checked: Config.general.weekStartsMonday
            onToggled: v => Config.general.weekStartsMonday = v
        }
    }

    SectionLabel {
        text: "On-screen display"
    }

    SettingRow {
        title: "Volume / brightness OSD"

        Toggle {
            checked: Config.general.osd
            onToggled: v => Config.general.osd = v
        }
    }
    SettingRow {
        title: "OSD duration"

        ValueSlider {
            from: 500
            to: 5000
            step: 100
            suffix: " ms"
            value: Config.general.osdTimeout
            onMoved: v => Config.general.osdTimeout = Math.round(v)
        }
    }

    SectionLabel {
        text: "Getting started"
    }

    SettingRow {
        title: "Welcome tour"
        description: "Show the five-page first-run tour again: keybinds, personalisation and the HexinAgent setup."

        Rectangle {
            implicitWidth: welcomeLbl.implicitWidth + 24
            implicitHeight: 32
            radius: Theme.radiusSmall
            color: welcomeMa.containsMouse ? Theme.accent : Theme.surfaceHi

            Behavior on color {
                ColorAnimation {
                    duration: Theme.animFast
                }
            }

            Txt {
                id: welcomeLbl
                anchors.centerIn: parent
                text: "Show"
                color: welcomeMa.containsMouse ? Theme.onAccent : Theme.text
            }
            MouseArea {
                id: welcomeMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Panels.settingsOpen = false;
                    Onboarding.show();
                }
            }
        }
    }

    SectionLabel {
        text: "Maintenance"
    }

    SettingRow {
        title: "Settings file"
        description: Config.path

        Rectangle {
            implicitWidth: t1.implicitWidth + 24
            implicitHeight: 32
            radius: Theme.radiusSmall
            color: Theme.surfaceHi

            Txt {
                id: t1
                anchors.centerIn: parent
                text: "Reload shell"
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.reload(false)
            }
        }
    }
    SettingRow {
        title: "Reset all settings"
        description: "Restore every option to its default and reload the shell."

        Rectangle {
            id: resetBtn
            property bool armed: false
            implicitWidth: t2.implicitWidth + 24
            implicitHeight: 32
            radius: Theme.radiusSmall
            color: armed ? Theme.red : Theme.surfaceHi

            Timer {
                id: disarm
                interval: 3000
                onTriggered: resetBtn.armed = false
            }
            Txt {
                id: t2
                anchors.centerIn: parent
                text: resetBtn.armed ? "Click again to confirm" : "Reset"
                color: resetBtn.armed ? Theme.base : Theme.text
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (!resetBtn.armed) {
                        resetBtn.armed = true;
                        disarm.restart();
                    } else {
                        Config.resetAll();
                    }
                }
            }
        }
    }

    SectionLabel {
        text: "Keybinds & IPC"
    }

    Card {
        Layout.fillWidth: true

        Txt {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Theme.subtext
            font.family: "monospace"
            font.pixelSize: Theme.fontSmall + 1
            text: "qs ipc call panels toggle control\nqs ipc call panels toggle notifications\nqs ipc call settings toggle\nqs ipc call audio up | down | mute | micMute\nqs ipc call brightness up | down\nqs ipc call notifications toggleDnd | clear\nqs ipc call media playPause | next | previous\n\nGlobal shortcuts (hyprland.lua):\nhl.bind(\"SUPER + A\", hl.dsp.global(\"quickshell:controlPanel\"))\nhl.bind(\"SUPER + N\", hl.dsp.global(\"quickshell:notificationCenter\"))\nhl.bind(\"SUPER + W\", hl.dsp.global(\"quickshell:wallpaper\"))\nhl.bind(\"SUPER + comma\", hl.dsp.global(\"quickshell:settings\"))\nhl.bind(\"SUPER + SHIFT + N\", hl.dsp.global(\"quickshell:dnd\"))\nhl.bind(\"SUPER + L\", hl.dsp.global(\"quickshell:lock\"))"
        }
    }
}
