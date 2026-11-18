import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// One UnityAgent feature switch in the welcome tour. Dimmed and disabled while
// the universal switch is off.
Card {
    id: root

    property string title: ""
    property string description: ""
    property bool checked: false
    property bool available: true

    signal toggled(bool value)

    padding: 10
    spacing: 0
    opacity: available ? 1 : 0.45
    enabled: available

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.animFast
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Txt {
                Layout.fillWidth: true
                text: root.title
                font.bold: true
                font.pixelSize: Theme.fontSmall + 1
                elide: Text.ElideRight
            }
            Txt {
                Layout.fillWidth: true
                text: root.description
                color: Theme.subtext
                font.pixelSize: Theme.fontSmall
                elide: Text.ElideRight
            }
        }

        Toggle {
            checked: root.checked
            onToggled: v => root.toggled(v)
        }
    }
}
