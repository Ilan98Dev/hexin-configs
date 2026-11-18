import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// The clock's panel: the current time, the full date, and the month grid.
// (Notifications live in their own panel on the right of the bar.)
Rectangle {
    id: root

    property int maxHeight: 800

    implicitWidth: 340
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

        ColumnLayout {
            Layout.fillWidth: true
            // The children are centre-aligned rather than filling, so the
            // column's derived max width would be the date's width and the
            // whole clock block would sit left of centre. Let it fill.
            Layout.maximumWidth: Number.POSITIVE_INFINITY
            spacing: 2

            Txt {
                text: Time.timeString
                font.pixelSize: 32
                font.bold: true
                color: Theme.accent
                Layout.alignment: Qt.AlignHCenter
            }
            Txt {
                text: Qt.formatDate(Time.date, "dddd d MMMM yyyy")
                color: Theme.subtext
                Layout.alignment: Qt.AlignHCenter
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.border
        }

        Calendar {
            Layout.fillWidth: true
        }
    }
}
