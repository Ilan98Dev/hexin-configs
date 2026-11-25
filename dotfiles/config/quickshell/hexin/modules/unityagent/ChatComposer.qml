import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// The centered chat field. Enter sends, Shift+Enter inserts a newline.
Rectangle {
    id: root

    property alias text: editor.text
    property bool busy: false
    property bool canStop: true
    property string hint: ""
    property string modelLabel: ""

    signal send(string text)
    signal stop()

    implicitWidth: 760
    // Enough room for the text, then the hint/model/send row underneath.
    // Without the control row in the maths the editor used to be squeezed to
    // a few pixels and the placeholder text was clipped by the top border.
    readonly property int controlRowHeight: 30
    readonly property int verticalPadding: 9
    implicitHeight: Math.min(190, Math.max(72, editor.contentHeight + controlRowHeight + verticalPadding * 2 + 4))

    radius: Theme.radius + 4
    color: Qt.alpha(Theme.surfaceHi, 0.55)
    border.width: 1
    border.color: editor.activeFocus ? Theme.accent : Theme.border

    Behavior on border.color {
        ColorAnimation {
            duration: Theme.animFast
        }
    }

    // Soft accent glow behind the field.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -5
        radius: parent.radius + 5
        color: "transparent"
        border.width: 1
        border.color: Theme.accent
        opacity: editor.activeFocus ? 0.22 : (hover.hovered ? 0.08 : 0)
        z: -1

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.anim
                easing.type: Easing.OutCubic
            }
        }
    }

    HoverHandler {
        id: hover
    }

    ColumnLayout {
        anchors {
            fill: parent
            leftMargin: 16
            rightMargin: 10
            topMargin: root.verticalPadding
            bottomMargin: root.verticalPadding
        }
        spacing: 4

        TextEdit {
            id: editor

            Layout.fillWidth: true
            Layout.fillHeight: true
            textFormat: TextEdit.PlainText
            wrapMode: TextEdit.Wrap
            selectByMouse: true
            clip: true
            color: Theme.text
            selectionColor: Theme.accentSoft
            selectedTextColor: Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.fontSize + 1
            cursorVisible: activeFocus

            Text {
                anchors.fill: parent
                visible: editor.text.length === 0
                text: "Ask UnityAgent anything…"
                color: Theme.subtext
                font.family: Theme.font
                font.pixelSize: Theme.fontSize + 1
                wrapMode: Text.Wrap
                opacity: 0.75
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (event.modifiers & Qt.ShiftModifier) {
                        // let the editor insert a newline
                        return;
                    }
                    event.accepted = true;
                    root.submit();
                    return;
                }
                if (event.key === Qt.Key_Escape) {
                    event.accepted = true;
                    editor.focus = false;
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Txt {
                text: root.hint.length
                    ? root.hint
                    : (root.text.length ? root.text.split(/\s+/).filter(w => w.length).length + " words" : "Enter to send · Shift+Enter for a new line")
                color: root.hint.length ? Theme.accent : Theme.subtext
                font.pixelSize: Theme.fontSmall - 1
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Rectangle {
                visible: root.modelLabel.length > 0
                width: modelTxt.width + 16
                height: 20
                radius: 10
                color: Theme.accentSoft

                Txt {
                    id: modelTxt
                    anchors.centerIn: parent
                    text: root.modelLabel
                    color: Theme.accent
                    font.pixelSize: Theme.fontSmall - 1
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth + 2, 200)
                }
            }

            // Send / stop button. While an approved command runs there is
            // nothing to stop (the daemon owns it), so show a spinner instead.
            Rectangle {
                width: 30
                height: 30
                radius: 15
                color: root.busy
                    ? (root.canStop ? Qt.alpha(Theme.red, 0.18) : Theme.accentSoft)
                    : (sendMa.containsMouse && root.text.trim().length ? Qt.lighter(Theme.accent, 1.12) : (root.text.trim().length ? Theme.accent : Theme.surfaceHi))
                border.width: 1
                border.color: root.busy
                    ? (root.canStop ? Qt.alpha(Theme.red, 0.6) : Qt.alpha(Theme.accent, 0.5))
                    : (root.text.trim().length ? Theme.accent : Theme.border)

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.animFast
                    }
                }

                // stop icon
                Rectangle {
                    visible: root.busy && root.canStop
                    anchors.centerIn: parent
                    width: 10
                    height: 10
                    radius: 2
                    color: Theme.red
                }

                // running a command: quiet spinner
                Glyph {
                    visible: root.busy && !root.canStop
                    anchors.centerIn: parent
                    text: Icons.refresh
                    color: Theme.accent
                    font.pixelSize: Theme.fontSmall + 1

                    RotationAnimator on rotation {
                        running: Theme.anim > 0 && root.busy && !root.canStop
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 1100
                    }
                }

                // arrow
                Text {
                    visible: !root.busy
                    anchors.centerIn: parent
                    text: "↑"
                    color: root.text.trim().length ? Theme.onAccent : Theme.subtext
                    font.pixelSize: Theme.fontSize + 5
                    font.bold: true
                }

                MouseArea {
                    id: sendMa
                    anchors.fill: parent
                    enabled: !root.busy || root.canStop
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.busy ? root.stop() : root.submit()
                }
            }
        }
    }

    function submit() {
        if (root.busy)
            return
        const value = root.text.trim()
        if (!value.length)
            return
        root.send(value)
        root.text = ""
        editor.text = ""
    }

    function focusEditor() {
        editor.forceActiveFocus();
    }
}
