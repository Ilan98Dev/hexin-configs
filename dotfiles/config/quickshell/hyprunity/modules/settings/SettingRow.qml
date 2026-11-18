import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// A labelled setting. The control goes inside as a child.
Rectangle {
    id: root

    property string title: ""
    property string description: ""
    default property alias control: ctl.data

    Layout.fillWidth: true
    implicitHeight: Math.max(56, lbl.implicitHeight + 24)
    radius: Theme.radiusSmall
    color: Theme.card

    Behavior on color {
        ColorAnimation {
            duration: Theme.anim
        }
    }

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 16
            rightMargin: 16
        }
        spacing: 16

        ColumnLayout {
            id: lbl
            Layout.fillWidth: true
            spacing: 1

            Txt {
                text: root.title
                font.bold: true
                Layout.fillWidth: true
            }
            Txt {
                visible: root.description !== ""
                text: root.description
                color: Theme.subtext
                font.pixelSize: Theme.fontSmall + 1
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
        }

        RowLayout {
            id: ctl
            spacing: 8
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
