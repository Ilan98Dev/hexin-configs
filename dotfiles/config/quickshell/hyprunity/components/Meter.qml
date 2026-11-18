import QtQuick
import QtQuick.Layouts
import qs.config

RowLayout {
    id: root

    property string glyph: ""
    property string label: ""
    property real value: 0          // 0..1
    property string valueText: ""
    property color barColor: Theme.accent

    spacing: 10

    Item {
        Layout.preferredWidth: 20
        Layout.preferredHeight: meterGlyph.implicitHeight

        Glyph {
            id: meterGlyph
            anchors.centerIn: parent
            text: root.glyph
            color: root.barColor
        }
    }
    Txt {
        visible: root.label && root.label !== ""
        text: root.label
        color: Theme.subtext
        Layout.preferredWidth: visible ? 46 : 0
    }
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 6
        radius: 3
        color: Theme.surfaceHi

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, root.value))
            height: parent.height
            radius: 3
            color: root.barColor

            Behavior on width {
                NumberAnimation {
                    duration: Theme.anim
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
    Txt {
        text: root.valueText
        horizontalAlignment: Text.AlignRight
        Layout.preferredWidth: 48
    }
}
