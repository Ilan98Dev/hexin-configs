import QtQuick
import QtQuick.Layouts
import qs.config

// Quick-settings toggle tile.
Rectangle {
    id: root

    property string glyph: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property bool danger: false
    property bool expandable: false
    property bool expanded: false
    readonly property color fg: active ? (danger ? Theme.base : Theme.onAccent) : Theme.text

    signal clicked
    signal expand

    implicitHeight: 58
    radius: Theme.radiusSmall + 2
    color: active ? (danger ? Theme.red : Theme.accent) : (ma.containsMouse ? Theme.surfaceHi : Theme.card)
    scale: ma.pressed ? 0.98 : 1

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

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 12
            rightMargin: root.expandable ? 2 : 12
        }
        spacing: 10

        Item {
            Layout.preferredWidth: 24
            Layout.preferredHeight: tileGlyph.implicitHeight

            Glyph {
                id: tileGlyph
                anchors.centerIn: parent
                text: root.glyph
                color: root.fg
                font.pixelSize: Theme.fontSize + 6
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Txt {
                text: root.title
                color: root.fg
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Txt {
                text: root.subtitle
                color: Qt.alpha(root.fg, 0.75)
                font.pixelSize: Theme.fontSmall
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        Item {
            visible: root.expandable
            Layout.preferredWidth: 30
            Layout.fillHeight: true

            Glyph {
                anchors.centerIn: parent
                text: root.expanded ? Icons.chevronUp : Icons.chevronDown
                color: root.fg
                font.pixelSize: Theme.fontSmall
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.expand()
            }
        }
    }
}
