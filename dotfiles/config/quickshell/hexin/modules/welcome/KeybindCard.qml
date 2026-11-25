import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// A shortcut row in the welcome tour: key caps on the left, what they do on
// the right.
Card {
    id: root

    property var keys: []
    property string label: ""
    property string hint: ""

    padding: 12
    spacing: 0

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        Row {
            spacing: 4

            Repeater {
                model: root.keys

                KeyCap {
                    text: modelData
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Txt {
                Layout.fillWidth: true
                text: root.label
                font.bold: true
                elide: Text.ElideRight
            }
            Txt {
                Layout.fillWidth: true
                text: root.hint
                color: Theme.subtext
                font.pixelSize: Theme.fontSmall
                elide: Text.ElideRight
            }
        }
    }
}
