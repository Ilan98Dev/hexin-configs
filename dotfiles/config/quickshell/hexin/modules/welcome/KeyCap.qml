import QtQuick
import qs.config
import qs.components

// One keyboard key in the welcome tour's shortcut cards.
Rectangle {
    id: root

    property string text: ""

    implicitWidth: label.implicitWidth + 14
    implicitHeight: 24
    radius: 6
    color: Theme.surfaceHi
    border.width: 1
    border.color: Theme.border

    Txt {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.pixelSize: Theme.fontSmall
        font.bold: true
    }
}
