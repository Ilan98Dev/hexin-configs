import QtQuick
import qs.config
import qs.components

// Secondary / primary pill button used by the welcome tour's footer and pages.
Rectangle {
    id: root

    property string text: ""
    property bool primary: false

    signal clicked

    implicitWidth: label.implicitWidth + 30
    implicitHeight: 36
    radius: Theme.radiusSmall
    color: primary
        ? (ma.containsMouse ? Qt.lighter(Theme.accent, 1.08) : Theme.accent)
        : (ma.containsMouse ? Theme.hover : Theme.card)
    border.width: primary ? 0 : 1
    border.color: Theme.border

    Behavior on color {
        ColorAnimation {
            duration: Theme.animFast
        }
    }

    Txt {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.primary ? Theme.onAccent : Theme.text
        font.bold: root.primary
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
