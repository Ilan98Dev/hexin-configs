import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// Session action button. Destructive ones need a second click within 3s.
Rectangle {
    id: root

    property string glyph: ""
    property string label: ""
    property bool confirm: false
    property bool armed: false

    signal activated

    implicitHeight: 52
    radius: Theme.radiusSmall + 2
    color: armed ? Theme.red : (ma.containsMouse ? Theme.surfaceHi : Theme.card)
    scale: ma.pressed ? 0.95 : 1

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

    Timer {
        id: disarm
        interval: 3000
        onTriggered: root.armed = false
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 2

        Glyph {
            text: root.glyph
            color: root.armed ? Theme.base : Theme.text
            Layout.alignment: Qt.AlignHCenter
        }
        Txt {
            text: root.armed ? "Sure?" : root.label
            color: root.armed ? Theme.base : Theme.subtext
            font.pixelSize: Theme.fontSmall
            Layout.alignment: Qt.AlignHCenter
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.confirm && !root.armed) {
                root.armed = true;
                disarm.restart();
            } else {
                root.armed = false;
                root.activated();
            }
        }
    }
}
