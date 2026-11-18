import QtQuick
import qs.config

Item {
    id: root

    property real from: 0
    property real to: 1
    property real value: 0
    property real step: 0
    property color fillColor: Theme.accent

    signal moved(real newValue)

    implicitWidth: 160
    implicitHeight: 24

    readonly property real ratio: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0
    readonly property int knob: 16

    function emitFor(mx) {
        const r = Math.max(0, Math.min(1, (mx - knob / 2) / Math.max(1, width - knob)));
        let v = from + r * (to - from);
        if (step > 0)
            v = Math.round(v / step) * step;
        root.moved(Math.max(from, Math.min(to, v)));
    }

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 8
        radius: 4
        color: Theme.surfaceHi

        Rectangle {
            width: knobRect.x + root.knob / 2
            height: parent.height
            radius: 4
            color: root.fillColor
        }
    }

    Rectangle {
        id: knobRect
        width: root.knob
        height: root.knob
        radius: root.knob / 2
        anchors.verticalCenter: parent.verticalCenter
        x: (root.width - root.knob) * root.ratio
        color: Theme.text
        scale: ma.pressed ? 1.2 : 1

        Behavior on x {
            NumberAnimation {
                duration: Theme.animFast
                easing.type: Easing.OutCubic
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: Theme.animFast
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Theme.animFast
            }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => root.emitFor(mouse.x)
        onPositionChanged: mouse => {
            if (pressed)
                root.emitFor(mouse.x);
        }
        onWheel: wheel => {
            const inc = root.step > 0 ? root.step : (root.to - root.from) * 0.02;
            root.moved(Math.max(root.from, Math.min(root.to, root.value + (wheel.angleDelta.y > 0 ? inc : -inc))));
        }
    }
}
