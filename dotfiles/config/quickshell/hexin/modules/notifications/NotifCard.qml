import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import qs.config
import qs.services
import qs.components

// One notification. Used for toasts (popup: true) and in the notification center.
Rectangle {
    id: root

    required property var notif
    property bool popup: false

    readonly property var n: notif.notification
    readonly property bool critical: n.urgency === NotificationUrgency.Critical

    implicitHeight: content.implicitHeight + 24
    radius: Theme.radiusSmall + 4
    color: popup ? Theme.bgSolid : Theme.card
    border.width: popup || critical ? 1 : 0
    border.color: critical ? Theme.red : Theme.border

    Behavior on color {
        ColorAnimation {
            duration: Theme.animFast
        }
    }
    Behavior on border.color {
        ColorAnimation {
            duration: Theme.animFast
        }
    }

    // Slide/fade in. Toasts rise from the screen edge; cards in the centre
    // settle upward from a few pixels lower.
    opacity: 0
    property real slide: popup ? 14 : 8

    transform: Translate {
        y: root.slide
    }

    ParallelAnimation {
        id: enter
        NumberAnimation {
            target: root
            property: "opacity"
            from: 0
            to: 1
            duration: Theme.anim
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root
            property: "slide"
            from: root.popup ? 14 : 8
            to: 0
            duration: Math.max(1, Theme.anim + 60)
            easing.type: Easing.OutCubic
        }
    }

    Component.onCompleted: {
        if (Theme.anim <= 0) {
            root.opacity = 1;
            root.slide = 0;
        } else {
            enter.start();
        }
    }

    function defaultAction() {
        const a = n.actions;
        for (let i = 0; i < a.length; i++) {
            if (a[i].identifier === "default")
                return a[i];
        }
        return null;
    }

    HoverHandler {
        onHoveredChanged: root.notif.hovered = hovered
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                Notifs.dismiss(root.notif);
                return;
            }
            const act = root.defaultAction();
            if (act) {
                act.invoke();
                if (!root.n.resident)
                    Notifs.dismiss(root.notif);
            } else if (root.popup) {
                root.notif.popup = false;
            }
        }
    }

    // urgency stripe
    Rectangle {
        visible: root.critical
        width: 3
        height: parent.height - 20
        radius: 2
        anchors {
            left: parent.left
            leftMargin: 4
            verticalCenter: parent.verticalCenter
        }
        color: Theme.red
    }

    RowLayout {
        id: content
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 12
        }
        spacing: 12

        // image / app icon
        Item {
            Layout.preferredWidth: 44
            Layout.preferredHeight: 44
            Layout.alignment: Qt.AlignTop

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusSmall
                color: Theme.surfaceHi
            }
            Image {
                id: img
                anchors.fill: parent
                // Icons.src filters out unresolved image://icon/... URLs; the
                // provider would otherwise paint a checkerboard for them.
                source: Icons.src(root.n.image)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }
            Image {
                id: appIcon
                anchors.centerIn: parent
                width: 28
                height: 28
                source: Icons.src(root.n.appIcon)
                sourceSize: Qt.size(56, 56)
                asynchronous: true
                visible: img.status !== Image.Ready && status === Image.Ready
            }
            Glyph {
                anchors.centerIn: parent
                visible: img.status !== Image.Ready && appIcon.status !== Image.Ready
                text: Icons.bell
                color: Theme.subtext
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Txt {
                    text: root.n.appName
                    color: Theme.subtext
                    font.pixelSize: Theme.fontSmall
                    elide: Text.ElideRight
                    Layout.maximumWidth: 140
                }
                Txt {
                    text: "·  " + Time.ago(root.notif.time)
                    color: Theme.subtext
                    font.pixelSize: Theme.fontSmall
                }
                Item {
                    Layout.fillWidth: true
                }
                IconButton {
                    glyph: Icons.close
                    size: 22
                    glyphSize: Theme.fontSmall
                    iconColor: Theme.subtext
                    onClicked: Notifs.dismiss(root.notif)
                }
            }

            Txt {
                visible: text !== ""
                text: root.n.summary
                font.bold: true
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Txt {
                visible: text !== ""
                text: root.n.body
                textFormat: Text.StyledText
                color: Theme.subtext
                wrapMode: Text.Wrap
                maximumLineCount: root.popup ? 3 : 6
                elide: Text.ElideRight
                Layout.fillWidth: true
                onLinkActivated: link => Qt.openUrlExternally(link)
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 6
                visible: actionRepeater.count > 0

                Repeater {
                    id: actionRepeater
                    model: root.n.actions

                    Rectangle {
                        id: actionBtn
                        required property var modelData
                        visible: modelData.identifier !== "default"
                        implicitHeight: 28
                        implicitWidth: actionLabel.implicitWidth + 24
                        radius: Theme.radiusSmall
                        color: actionMa.containsMouse ? Theme.accent : Theme.surfaceHi

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.animFast
                            }
                        }

                        Txt {
                            id: actionLabel
                            anchors.centerIn: parent
                            text: actionBtn.modelData.text
                            color: actionMa.containsMouse ? Theme.onAccent : Theme.text
                            font.pixelSize: Theme.fontSmall + 1
                        }
                        MouseArea {
                            id: actionMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const action = actionBtn.modelData;
                                action.invoke();
                                Notifs.dismissAction(action);
                            }
                        }
                    }
                }
                Item {
                    Layout.fillWidth: true
                }
            }
        }
    }
}
