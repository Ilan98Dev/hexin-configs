import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components
import qs.modules.notifications

Rectangle {
    id: root

    property int maxHeight: 800

    implicitWidth: 420
    implicitHeight: Math.min(maxHeight, col.implicitHeight + 32)

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Theme.anim
            easing.type: Easing.OutCubic
        }
    }
    radius: Theme.radius
    color: Theme.bg
    border.width: 1
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
    clip: true

    // swallow clicks so they don't reach the click-outside layer
    MouseArea {
        anchors.fill: parent
    }

    ColumnLayout {
        id: col
        anchors {
            fill: parent
            margins: 16
        }
        spacing: 12

        // header
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Txt {
                text: "Notifications"
                font.pixelSize: Theme.fontLarge
                font.bold: true
                Layout.fillWidth: true
            }
            IconButton {
                glyph: Notifs.dnd ? Icons.bellSlash : Icons.bell
                active: Notifs.dnd
                onClicked: Notifs.toggleDnd()
            }
            Rectangle {
                visible: Notifs.count > 0
                implicitWidth: clearLbl.implicitWidth + 20
                implicitHeight: 30
                radius: Theme.radiusSmall
                color: clearMa.containsMouse ? Theme.hover : "transparent"

                Txt {
                    id: clearLbl
                    anchors.centerIn: parent
                    text: "Clear all"
                    color: Theme.accent
                }
                MouseArea {
                    id: clearMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifs.clearAll()
                }
            }
        }

        // empty state
        ColumnLayout {
            visible: Notifs.count === 0
            Layout.fillWidth: true
            // Without this the column's max width comes from its children
            // (just the text), so it hugs the left edge instead of filling
            // the panel and centring the glyph and label.
            Layout.maximumWidth: Number.POSITIVE_INFINITY
            Layout.preferredHeight: 120
            spacing: 8
            opacity: visible ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.anim
                }
            }

            Item {
                Layout.fillHeight: true
            }
            Glyph {
                text: Notifs.dnd ? Icons.bellSlash : Icons.bell
                color: Theme.surfaceHi
                font.pixelSize: 34
                Layout.alignment: Qt.AlignHCenter
            }
            Txt {
                text: Notifs.dnd ? "Do Not Disturb is on" : "You're all caught up"
                color: Theme.subtext
                Layout.alignment: Qt.AlignHCenter
            }
            Item {
                Layout.fillHeight: true
            }
        }

        // list
        Flickable {
            id: flick
            visible: Notifs.count > 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 80
            Layout.preferredHeight: Math.min(listCol.implicitHeight, 380)
            contentHeight: listCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            opacity: visible ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.anim
                }
            }

            ColumnLayout {
                id: listCol
                width: flick.width
                spacing: 8

                Repeater {
                    model: Notifs.list

                    NotifCard {
                        required property var modelData
                        Layout.fillWidth: true
                        notif: modelData
                    }
                }
            }
        }
    }
}
