import QtQuick
import qs.config

Rectangle {
    id: root

    property string glyph: ""
    property bool active: false
    property int size: 32
    property color iconColor: active ? Theme.accent : Theme.text
    property alias glyphSize: g.font.pixelSize

    signal clicked

    implicitWidth: size
    implicitHeight: size
    radius: Theme.radiusSmall
    color: ma.pressed ? Theme.pressed : (ma.containsMouse ? Theme.hover : "transparent")
    scale: ma.pressed ? 0.9 : (ma.containsMouse ? 1.06 : 1)

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

    Glyph {
        id: g
        anchors.centerIn: parent
        text: root.glyph
        color: root.iconColor
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
