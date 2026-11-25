import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.components

// Clipboard history — the built-in replacement for
// `fuzzel --dinput | cliphist decode | wl-copy`.
//
//   type to filter · Up/Down to pick · Enter to copy · Delete to forget · Esc
//
// History comes from cliphist on open; copying goes back through
// `cliphist decode <id> | wl-copy`.
Rectangle {
    id: root

    property int maxHeight: 800
    property var entries: []          // [{ id, preview }]
    property string query: ""
    property int selected: 0

    readonly property var filtered: {
        const q = query.trim().toLowerCase();
        if (q === "")
            return entries;
        return entries.filter(e => e.preview.toLowerCase().includes(q));
    }

    readonly property int visibleRows: Math.max(1, Math.min(filtered.length, 7))

    function pretty(text) {
        return String(text).replace(/\s+/g, " ").trim();
    }

    function parse(text) {
        const out = [];
        for (const line of String(text).split("\n")) {
            if (line === "")
                continue;
            const tab = line.indexOf("\t");
            if (tab < 0)
                continue;
            out.push({
                id: line.slice(0, tab).trim(),
                preview: root.pretty(line.slice(tab + 1))
            });
        }
        entries = out;
        selected = 0;
    }

    function copy(entry) {
        if (!entry)
            return;
        Panels.close();
        Quickshell.execDetached(["sh", "-c", "cliphist decode " + entry.id + " | wl-copy"]);
    }

    function remove(entry) {
        if (!entry)
            return;
        // cliphist delete reads `list`-style lines, so hand it the entry's
        // own line (avoids having to quote arbitrary clipboard text).
        Quickshell.execDetached(["sh", "-c", "cliphist list | awk -F'\\t' '$1==\"" + entry.id + "\"' | cliphist delete"]);
        const left = entries.filter(e => e.id !== entry.id);
        entries = left;
        selected = Math.max(0, Math.min(selected, left.length - 1));
    }

    function wipe() {
        entries = [];
        Quickshell.execDetached(["cliphist", "wipe"]);
    }

    function move(delta) {
        if (filtered.length === 0)
            return;
        selected = Math.max(0, Math.min(filtered.length - 1, selected + delta));
    }

    Process {
        id: listProc
        command: ["cliphist", "list"]
        running: true
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.parse(this.text)
        }
    }

    implicitWidth: 480
    implicitHeight: Math.min(maxHeight, col.implicitHeight + 28)

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Theme.anim
            easing.type: Easing.OutCubic
        }
    }
    radius: Theme.radius
    color: Theme.bg
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

    MouseArea {
        anchors.fill: parent
    }

    ColumnLayout {
        id: col
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 14
        }
        spacing: 10

        // ── header ──────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Txt {
                text: "Clipboard"
                font.pixelSize: Theme.fontLarge
                font.bold: true
                Layout.fillWidth: true
            }

            Txt {
                visible: entries.length > 0
                text: entries.length + (entries.length === 1 ? " item" : " items")
                color: Theme.subtext
                font.pixelSize: Theme.fontSmall
            }

            Rectangle {
                visible: entries.length > 0
                implicitWidth: wipeLbl.implicitWidth + 18
                implicitHeight: 28
                radius: Theme.radiusSmall
                color: wipeMa.containsMouse ? Theme.hover : "transparent"

                Txt {
                    id: wipeLbl
                    anchors.centerIn: parent
                    text: "Clear all"
                    color: Theme.accent
                    font.pixelSize: Theme.fontSmall
                }
                MouseArea {
                    id: wipeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.wipe()
                }
            }
        }

        // ── search ──────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 38
            radius: Theme.radiusSmall
            color: Theme.card
            border.width: 1
            border.color: field.activeFocus ? Theme.accent : Theme.border

            Behavior on border.color {
                ColorAnimation {
                    duration: Theme.animFast
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: field.forceActiveFocus()
            }

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 12
                    rightMargin: 12
                }
                spacing: 9

                Glyph {
                    text: Icons.search
                    color: Theme.subtext
                    font.pixelSize: Theme.fontSize
                }

                TextInput {
                    id: field
                    Layout.fillWidth: true
                    focus: true
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.onAccent
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true

                    onTextChanged: {
                        root.query = text;
                        root.selected = 0;
                    }
                    onAccepted: root.copy(root.filtered[root.selected])

                    Keys.onUpPressed: root.move(-1)
                    Keys.onDownPressed: root.move(1)
                    Keys.onEscapePressed: Panels.close()

                    Component.onCompleted: forceActiveFocus()

                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: field.text.length === 0
                        text: "Filter clipboard history…"
                        color: Theme.subtext
                    }
                }
            }
        }

        // ── history ─────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.visibleRows * 42

            ListView {
                id: list
                anchors.fill: parent
                visible: root.filtered.length > 0
                model: root.filtered
                currentIndex: root.selected
                onCurrentIndexChanged: if (currentIndex >= 0 && currentIndex < root.filtered.length) positionViewAtIndex(currentIndex, ListView.Contain)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                spacing: 2

                add: Transition {
                    NumberAnimation {
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Theme.anim
                    }
                }
                displaced: Transition {
                    NumberAnimation {
                        properties: "y"
                        duration: Theme.anim
                        easing.type: Easing.OutCubic
                    }
                }

                delegate: Rectangle {
                    id: row

                    required property var modelData
                    required property int index

                    readonly property bool current: index === root.selected
                    readonly property bool isImage: modelData.preview.startsWith("[[ binary data")

                    width: list.width
                    height: 42
                    radius: Theme.radiusSmall
                    color: current ? Theme.accentSoft : (rowMa.containsMouse ? Theme.hover : "transparent")

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.animFast
                        }
                    }

                    MouseArea {
                        id: rowMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.selected = row.index
                        onClicked: root.copy(row.modelData)
                    }

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 10
                            rightMargin: 8
                        }
                        spacing: 9

                        Glyph {
                            text: row.isImage ? Icons.image : Icons.clipboard
                            color: row.isImage ? Theme.blue : Theme.subtext
                            font.pixelSize: Theme.fontSize
                        }

                        Txt {
                            text: modelData.preview
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        IconButton {
                            glyph: Icons.close
                            size: 24
                            glyphSize: Theme.fontSmall - 1
                            iconColor: Theme.subtext
                            opacity: rowMa.containsMouse || index === root.selected ? 1 : 0
                            onClicked: root.remove(modelData)

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.animFast
                                }
                            }
                        }
                    }
                }
            }

            Txt {
                anchors.centerIn: parent
                visible: root.filtered.length === 0
                text: root.entries.length === 0 ? "Clipboard history is empty" : "No matching entries"
                color: Theme.subtext
            }
        }

        // ── footer ──────────────────────────────────────────────────────
        Txt {
            Layout.fillWidth: true
            text: "Enter to copy · × to delete · Esc to close"
            color: Theme.subtext
            font.pixelSize: Theme.fontSmall
        }
    }
}
