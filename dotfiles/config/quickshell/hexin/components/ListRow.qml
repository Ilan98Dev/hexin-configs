import QtQuick
import QtQuick.Layouts
import qs.config

Rectangle {
    id: root

    property string glyph: ""
    property string title: ""
    property string subtitle: ""
    property string trailing: ""
    property bool active: false

    signal clicked

    implicitHeight: 44
    radius: Theme.radiusSmall
    color: ma.containsMouse ? Theme.hover : (active ? Theme.accentSoft : "transparent")

    Behavior on color {
        ColorAnimation {
            duration: Theme.animFast
        }
    }

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 10
            rightMargin: 10
        }
        spacing: 10

        Item {
            Layout.preferredWidth: 22
            Layout.preferredHeight: glyphItem.implicitHeight

            Glyph {
                id: glyphItem
                anchors.centerIn: parent
                text: root.glyph
                color: root.active ? Theme.accent : Theme.text
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Txt {
                text: root.title
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Txt {
                visible: text !== ""
                text: root.subtitle
                color: Theme.subtext
                font.pixelSize: Theme.fontSmall
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
        Glyph {
            visible: root.trailing !== ""
            text: root.trailing
            color: Theme.subtext
            font.pixelSize: Theme.fontSmall
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
