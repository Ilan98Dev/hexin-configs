import QtQuick
import qs.config

// Segmented chooser. options: [{ label: "Top", value: "top" }, ...]
Rectangle {
    id: root

    property var options: []
    property var current

    signal selected(var value)

    implicitWidth: row.implicitWidth + 8
    implicitHeight: 34
    radius: Theme.radiusSmall
    color: Theme.card

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: root.options

            Rectangle {
                id: seg
                required property var modelData
                readonly property bool on: root.current === modelData.value

                width: lbl.implicitWidth + 24
                height: 26
                radius: Math.max(3, Theme.radiusSmall - 2)
                color: on ? Theme.accent : (ma.containsMouse ? Theme.hover : "transparent")

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.animFast
                    }
                }

                Txt {
                    id: lbl
                    anchors.centerIn: parent
                    text: seg.modelData.label
                    color: seg.on ? Theme.onAccent : Theme.text
                    font.pixelSize: Theme.fontSmall + 1
                }
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selected(seg.modelData.value)
                }
            }
        }
    }
}
