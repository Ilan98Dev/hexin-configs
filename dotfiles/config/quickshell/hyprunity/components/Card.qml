import QtQuick
import QtQuick.Layouts
import qs.config

// Rounded surface; children are stacked in a column.
Rectangle {
    id: root

    default property alias content: lay.data
    property int padding: 12
    property alias spacing: lay.spacing

    implicitHeight: lay.implicitHeight + padding * 2
    radius: Theme.radiusSmall + 2
    color: Theme.card

    Behavior on color {
        ColorAnimation {
            duration: Theme.anim
        }
    }

    ColumnLayout {
        id: lay
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: root.padding
        }
        spacing: 8
    }
}
