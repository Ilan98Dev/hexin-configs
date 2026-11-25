import QtQuick
import QtQuick.Layouts
import qs.config

// A clickable bar segment. Children are laid out in a row.
Rectangle {
    id: root

    default property alias content: row.data
    property bool active: false
    property bool interactive: true
    property bool solid: false
    property int padding: 10
    readonly property bool hovered: ma.containsMouse

    signal clicked
    signal rightClicked
    signal middleClicked
    signal wheel(var event)

    implicitWidth: row.implicitWidth + padding * 2
    implicitHeight: Math.min(Config.bar.height - 8, Theme.fontSize + 15)
    radius: Theme.radiusSmall
    color: active ? Theme.accentSoft : (interactive && ma.containsMouse ? Theme.hover : (solid ? Theme.card : "transparent"))
    scale: ma.pressed ? 0.97 : 1

    Behavior on color {
        ColorAnimation {
            duration: Theme.animFast
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: Theme.animFast
            easing.type: Easing.OutCubic
        }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                root.rightClicked();
            else if (mouse.button === Qt.MiddleButton)
                root.middleClicked();
            else
                root.clicked();
        }
        onWheel: wheel => root.wheel(wheel)
    }
}
