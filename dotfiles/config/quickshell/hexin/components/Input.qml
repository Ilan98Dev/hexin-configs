import QtQuick
import qs.config

// Single-line text field. Emits `committed` on Enter or when focus is lost.
Rectangle {
    id: root

    property string text: ""
    property string placeholder: ""
    property bool valid: true
    property bool password: false

    signal committed(string value)

    implicitWidth: 220
    implicitHeight: 34
    radius: Theme.radiusSmall
    color: Theme.card
    border.width: 1
    border.color: !valid ? Theme.red : (field.activeFocus ? Theme.accent : Theme.border)

    Behavior on border.color {
        ColorAnimation {
            duration: Theme.animFast
        }
    }

    TextInput {
        id: field
        anchors {
            fill: parent
            leftMargin: 10
            rightMargin: 10
        }
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        text: root.text
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        selectionColor: Theme.accent
        selectedTextColor: Theme.onAccent
        echoMode: root.password ? TextInput.Password : TextInput.Normal

        onAccepted: root.committed(text)
        onActiveFocusChanged: if (!activeFocus) root.committed(text)

        Txt {
            anchors.verticalCenter: parent.verticalCenter
            text: root.placeholder
            color: Theme.subtext
            opacity: field.text.length === 0 ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.animFast
                }
            }
        }
    }
}
