import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

Card {
    id: root

    readonly property var p: Media.player

    visible: p !== null
    opacity: visible ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.anim
            easing.type: Easing.OutCubic
        }
    }

    // MPRIS doesn't push position updates; poke it while we're on screen.
    Timer {
        running: root.visible && root.p !== null && root.p.isPlaying
        interval: 1000
        repeat: true
        onTriggered: root.p.positionChanged()
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        Item {
            Layout.preferredWidth: 60
            Layout.preferredHeight: 60

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusSmall
                color: Theme.surfaceHi
            }
            Image {
                id: art
                anchors.fill: parent
                source: Media.art
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
                opacity: status === Image.Ready ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.anim
                    }
                }
            }
            Glyph {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                text: Icons.music
                color: Theme.subtext
                font.pixelSize: Theme.fontLarge + 6
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Txt {
                text: Media.title !== "" ? Media.title : "Nothing playing"
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Txt {
                text: Media.artist
                color: Theme.subtext
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Txt {
                text: root.p ? root.p.identity : ""
                color: Theme.subtext
                font.pixelSize: Theme.fontSmall
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: root.p !== null && root.p.length > 0
        spacing: 8

        Txt {
            text: root.p ? Time.duration(root.p.position) : ""
            color: Theme.subtext
            font.pixelSize: Theme.fontSmall
        }
        SliderBar {
            Layout.fillWidth: true
            from: 0
            to: root.p ? Math.max(1, root.p.length) : 1
            value: root.p ? root.p.position : 0
            onMoved: v => {
                if (root.p && root.p.canSeek)
                    root.p.position = v;
            }
        }
        Txt {
            text: root.p ? Time.duration(root.p.length) : ""
            color: Theme.subtext
            font.pixelSize: Theme.fontSmall
        }
    }

    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: 10

        IconButton {
            glyph: Icons.prev
            enabled: root.p !== null && root.p.canGoPrevious
            opacity: enabled ? 1 : 0.35
            onClicked: root.p.previous()
        }
        Rectangle {
            implicitWidth: 40
            implicitHeight: 40
            radius: 20
            color: Theme.accent
            opacity: root.p !== null && root.p.canTogglePlaying ? 1 : 0.4
            scale: playMa.pressed ? 0.9 : (playMa.containsMouse ? 1.05 : 1)

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.animFast
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: Theme.animFast
                    easing.type: Easing.OutCubic
                }
            }

            Glyph {
                anchors.centerIn: parent
                text: Media.playing ? Icons.pause : Icons.play
                color: Theme.onAccent
            }
            MouseArea {
                id: playMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.p && root.p.canTogglePlaying) root.p.togglePlaying()
            }
        }
        IconButton {
            glyph: Icons.next
            enabled: root.p !== null && root.p.canGoNext
            opacity: enabled ? 1 : 0.35
            onClicked: root.p.next()
        }
    }
}
