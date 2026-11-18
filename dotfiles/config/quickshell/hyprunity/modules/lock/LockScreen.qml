// =====================================================================
//  LockScreen.qml — hyprunity's built-in session lock.
//
//  Rendered inside the WlSessionLockSurface declared in shell.qml. Password
//  verification goes through PAM, exactly like a login prompt. Styled to the
//  active theme: an accent glow rising from the bottom-left, a secondary
//  (purple) one in the top-right, and a gradient-ringed avatar.
// =====================================================================
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import qs.config
import qs.services

Rectangle {
    id: root

    color: Theme.base

    Behavior on color {
        ColorAnimation {
            duration: Theme.anim
        }
    }

    /// Password waiting to be handed to PAM.
    property string pending: ""
    property string message: ""
    property string userName: ""

    readonly property string displayName: root.userName.length > 0 ? root.userName : (Quickshell.env("USER") || "user")

    readonly property string initials: {
        const parts = root.displayName.split(/\s+/).filter(p => p.length > 0);
        if (parts.length === 0)
            return "?";
        if (parts.length === 1)
            return parts[0].charAt(0).toUpperCase();
        return (parts[0].charAt(0) + parts[1].charAt(0)).toUpperCase();
    }

    readonly property bool failed: root.message.length > 0 && root.message !== "Authenticating\u2026"

    readonly property color accentSoft: Qt.alpha(Theme.accent, 0.20)
    readonly property color accentNone: Qt.alpha(Theme.accent, 0.0)
    readonly property color brandSoft: Qt.alpha(Theme.blue, 0.16)
    readonly property color brandNone: Qt.alpha(Theme.blue, 0.0)

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    // Real name from the passwd GECOS field ("Ilhan Zafar").
    Process {
        id: whoami
        command: ["sh", "-c", "getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1"]
        running: true

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const t = this.text.trim();
                if (t.length > 0)
                    root.userName = t;
            }
        }
    }

    PamContext {
        id: pam

        onPamMessage: {
            if (pam.responseRequired && root.pending.length > 0) {
                pam.respond(root.pending);
                root.pending = "";
            }
        }

        onCompleted: (result) => {
            if (result === PamResult.Success) {
                root.pending = "";
                root.message = "";
                input.text = "";
                Lock.unlock();
            } else {
                root.message = result === PamResult.MaxTries ? "Too many attempts" : "Incorrect password";
                root.pending = "";
                input.text = "";
                pam.abort();
            }
        }

        onError: (error) => {
            root.message = "Authentication error (" + PamError.toString(error) + ")";
            root.pending = "";
        }
    }

    function tryUnlock() {
        if (input.text.length === 0)
            return;

        root.message = "Authenticating\u2026";
        root.pending = input.text;
        input.text = "";

        if (!pam.active) {
            if (!pam.start())
                root.message = "Could not start authentication";
        } else if (pam.responseRequired) {
            pam.respond(root.pending);
            root.pending = "";
        }
    }

    Component.onCompleted: {
        Qt.callLater(() => input.forceActiveFocus());
        if (Theme.anim > 0) {
            enterAnim.start();
        } else {
            content.opacity = 1;
            contentShift.y = 0;
        }
    }

    // Wrong password: nudge the field side to side.
    property real shakeX: 0

    onFailedChanged: if (failed) shakeAnim.restart()

    SequentialAnimation {
        id: shakeAnim
        NumberAnimation {
            target: root
            property: "shakeX"
            to: -9
            duration: 45
        }
        NumberAnimation {
            target: root
            property: "shakeX"
            to: 8
            duration: 55
        }
        NumberAnimation {
            target: root
            property: "shakeX"
            to: -5
            duration: 55
        }
        NumberAnimation {
            target: root
            property: "shakeX"
            to: 4
            duration: 55
        }
        NumberAnimation {
            target: root
            property: "shakeX"
            to: 0
            duration: 55
            easing.type: Easing.OutCubic
        }
    }

    // ── brand glow ──────────────────────────────────────────────────
    Shape {
        anchors.fill: parent

        ShapePath {
            strokeWidth: 0
            fillGradient: RadialGradient {
                centerX: root.width * 0.12
                centerY: root.height * 1.02
                centerRadius: root.width * 0.85
                focalX: centerX
                focalY: centerY
                GradientStop {
                    position: 0.0
                    color: root.accentSoft
                }
                GradientStop {
                    position: 1.0
                    color: root.accentNone
                }
            }
            startX: 0
            startY: 0
            PathLine {
                x: root.width
                y: 0
            }
            PathLine {
                x: root.width
                y: root.height
            }
            PathLine {
                x: 0
                y: root.height
            }
            PathLine {
                x: 0
                y: 0
            }
        }
    }

    Shape {
        anchors.fill: parent

        ShapePath {
            strokeWidth: 0
            fillGradient: RadialGradient {
                centerX: root.width * 0.95
                centerY: root.height * -0.05
                centerRadius: root.width * 0.8
                focalX: centerX
                focalY: centerY
                GradientStop {
                    position: 0.0
                    color: root.brandSoft
                }
                GradientStop {
                    position: 1.0
                    color: root.brandNone
                }
            }
            startX: 0
            startY: 0
            PathLine {
                x: root.width
                y: 0
            }
            PathLine {
                x: root.width
                y: root.height
            }
            PathLine {
                x: 0
                y: root.height
            }
            PathLine {
                x: 0
                y: 0
            }
        }
    }

    // ── content ─────────────────────────────────────────────────────
    Column {
        id: content
        anchors.centerIn: parent
        spacing: 10
        opacity: 0

        transform: Translate {
            id: contentShift
            y: 14
        }

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 96
            height: 96

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0.0
                        color: Theme.accent
                    }
                    GradientStop {
                        position: 1.0
                        color: Theme.blue
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + 18
                    height: parent.height + 18
                    radius: width / 2
                    z: -1
                    color: Qt.alpha(Theme.accent, 0.10)
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: parent.width - 6
                height: parent.height - 6
                radius: width / 2
                color: Theme.surfaceHi

                Text {
                    anchors.centerIn: parent
                    text: root.initials
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 34
                    font.bold: true
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.displayName
            color: Theme.subtext
            font.family: Theme.font
            font.pixelSize: Theme.fontSize + 1
        }

        Item {
            width: 1
            height: 8
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 76
            font.bold: true
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy")
            color: Theme.subtext
            font.family: Theme.font
            font.pixelSize: Theme.fontSize + 4
        }

        Item {
            width: 1
            height: 22
        }

        Rectangle {
            id: field
            anchors.horizontalCenter: parent.horizontalCenter
            width: 310
            height: 46
            radius: Theme.radius
            color: Theme.surfaceHi

            transform: Translate {
                x: root.shakeX
            }

            border.width: 1
            border.color: root.failed ? Qt.alpha(Theme.red, 0.75) : input.activeFocus ? Theme.accent : Theme.border

            Behavior on border.color {
                ColorAnimation {
                    duration: Theme.animFast
                }
            }

            Text {
                id: lockIcon
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.lock
                color: input.activeFocus ? Theme.accent : Theme.subtext
                font.family: Theme.iconFont
                font.pixelSize: 15

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.animFast
                    }
                }
            }

            TextInput {
                id: input
                anchors.left: lockIcon.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                echoMode: TextInput.Password
                passwordCharacter: "\u2022"
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.fontSize + 3
                selectionColor: Theme.accent
                selectedTextColor: Theme.onAccent
                passwordMaskDelay: 300
                clip: true

                onAccepted: root.tryUnlock()

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text.length === 0
                    text: "Password"
                    color: Theme.subtext
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize + 2
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            height: 18
            text: root.message
            color: root.failed ? Theme.red : Theme.subtext
            font.family: Theme.font
            font.pixelSize: Theme.fontSmall
            opacity: root.message.length > 0 ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.animFast
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: Theme.animFast
                }
            }
        }
    }

    // ── footer ──────────────────────────────────────────────────────
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 30
        spacing: 8

        Text {
            text: Icons.lock
            color: Theme.accent
            font.family: Theme.iconFont
            font.pixelSize: Theme.fontSmall
        }

        Text {
            text: "hyprunity  \u2022  press Enter to unlock"
            color: Theme.subtext
            font.family: Theme.font
            font.pixelSize: Theme.fontSmall
        }
    }

    // Content settles in when the lock surface appears.
    ParallelAnimation {
        id: enterAnim
        NumberAnimation {
            target: content
            property: "opacity"
            from: 0
            to: 1
            duration: Theme.anim + 120
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: contentShift
            property: "y"
            from: 14
            to: 0
            duration: Theme.anim + 160
            easing.type: Easing.OutCubic
        }
    }
}
