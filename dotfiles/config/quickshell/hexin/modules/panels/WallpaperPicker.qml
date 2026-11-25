import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.components

Rectangle {
    id: root
    focus: true

    property int maxHeight: 800

    readonly property string folder: Config.wallpaper.folder.replace(/^~/, Quickshell.env("HOME"))
    property var entries: []

    implicitWidth: 600
    implicitHeight: Math.min(maxHeight, 448)
    radius: Theme.radius
    color: Theme.bgSolid
    border.width: 1
    border.color: Theme.border

    Behavior on color {
        ColorAnimation {
            duration: Theme.anim
        }
    }
    Behavior on border.color {
        ColorAnimation {
            duration: Theme.anim
        }
    }
    clip: true

    function useDefault() {
        Config.wallpaper.type = "default"
        Theme.requestMatugen(true)
    }

    function useImage(path) {
        Config.wallpaper.image = path
        Config.wallpaper.type = "image"
        Theme.requestMatugen(true)
    }

    function refresh() {
        lister.running = false
        lister.running = true
    }

    MouseArea {
        anchors.fill: parent
    }

    Process {
        id: lister
        running: true
        command: ["sh", "-c", "find \"$1\" -maxdepth 1 -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.bmp' \\) -print 2>/dev/null | sort", "sh", root.folder]
        stdout: StdioCollector {
            onStreamFinished: root.entries = text.split("\n").filter(function(line) { return line.length > 0 })
        }
    }

    Item {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 16
        height: 38

        RowLayout {
            anchors.fill: parent
            spacing: 8

            ColumnLayout {
                spacing: 0
                Txt {
                    text: "Wallpaper"
                    font.bold: true
                    font.pixelSize: Theme.fontLarge
                }
                Txt {
                    text: (root.entries.length > 0 ? root.entries.length + (root.entries.length === 1 ? " image" : " images") + " · " : "no images · ") + root.folder
                    color: Theme.subtext
                    font.pixelSize: Theme.fontSmall
                    elide: Text.ElideMiddle
                    Layout.maximumWidth: 320
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                width: 34
                height: 34
                radius: Theme.radiusSmall
                color: refreshMa.containsMouse ? Theme.hover : "transparent"
                Behavior on color {
                    ColorAnimation {
                        duration: Theme.animFast
                    }
                }
                Glyph { anchors.centerIn: parent; text: Icons.refresh }
                MouseArea { id: refreshMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.refresh() }
            }
            Rectangle {
                width: 34
                height: 34
                radius: Theme.radiusSmall
                color: closeMa.containsMouse ? Theme.hover : "transparent"
                Behavior on color {
                    ColorAnimation {
                        duration: Theme.animFast
                    }
                }
                Glyph { anchors.centerIn: parent; text: Icons.close }
                MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Panels.close() }
            }
        }
    }

    GridView {
        id: grid
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.bottomMargin: 12
        anchors.topMargin: 4
        clip: true
        cellWidth: 182
        cellHeight: 108
        model: root.entries.length + 1
        boundsBehavior: Flickable.StopAtBounds
        keyNavigationEnabled: true
        focus: true

        delegate: Rectangle {
            id: cell
            required property int index
            readonly property bool isDefault: cell.index === 0
            readonly property string path: cell.isDefault ? "" : root.entries[cell.index - 1]
            readonly property string source: cell.isDefault ? Config.defaultWallpaper.toString() : "file://" + cell.path
            readonly property bool selected: cell.isDefault ? Config.wallpaper.type === "default" : (Config.wallpaper.type === "image" && Config.wallpaper.image === cell.path)
            readonly property bool current: grid.currentIndex === cell.index
            readonly property bool hovered: cellMa.containsMouse

            width: grid.cellWidth - 10
            height: grid.cellHeight - 10
            radius: Theme.radiusSmall
            color: cell.hovered ? Theme.surfaceHi : Theme.card
            border.width: cell.current || cell.selected ? 2 : 1
            border.color: cell.current || cell.selected ? Theme.accent : (cell.hovered ? Qt.alpha(Theme.accent, 0.6) : Theme.border)

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

            Image {
                anchors.fill: parent
                anchors.margins: 4
                source: cell.source
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize.width: 320
                sourceSize.height: 200
                opacity: status === Image.Ready ? 0.95 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.anim
                    }
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: cell.border.width + 4
                height: 20
                color: Qt.rgba(0, 0, 0, 0.55)
                Txt {
                    anchors.fill: parent
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    text: cell.isDefault ? "Default" : cell.path.split("/").pop()
                    color: "#ffffff"
                    font.pixelSize: Theme.fontSmall
                    elide: Text.ElideMiddle
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            MouseArea {
                id: cellMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    grid.currentIndex = cell.index
                    if (cell.isDefault) root.useDefault()
                    else if (cell.path && cell.path.length) root.useImage(cell.path)
                    Panels.close()
                }
            }
        }
    }

    Keys.onEscapePressed: Panels.close()
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            var c = grid.currentItem
            if (c) {
                if (c.isDefault) root.useDefault()
                else if (c.path && c.path.length) root.useImage(c.path)
                Panels.close()
            }
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Left) { grid.moveCurrentIndexLeft(); event.accepted = true; return }
        if (event.key === Qt.Key_Right) { grid.moveCurrentIndexRight(); event.accepted = true; return }
        if (event.key === Qt.Key_Up) { grid.moveCurrentIndexUp(); event.accepted = true; return }
        if (event.key === Qt.Key_Down) { grid.moveCurrentIndexDown(); event.accepted = true; return }
    }

    ColumnLayout {
        anchors.horizontalCenter: grid.horizontalCenter
        anchors.top: grid.top
        anchors.topMargin: grid.cellHeight + 12
        spacing: 4
        visible: root.entries.length === 0

        Glyph {
            text: Icons.image
            color: Theme.subtext
            font.pixelSize: 34
            Layout.alignment: Qt.AlignHCenter
        }
        Txt {
            text: "No pictures in this folder"
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }
        Txt {
            text: "Set the folder in Settings ▸ Wallpaper"
            color: Theme.subtext
            font.pixelSize: Theme.fontSmall
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
