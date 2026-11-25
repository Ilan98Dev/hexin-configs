import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// SUPER + K — searchable keybind cheatsheet.
//
// Type to filter by keys, action, command or section · Up/Down to move ·
// Enter/Esc to close. The list comes from Keybinds, which re-reads
// 90-keybinds.lua whenever the file changes.
Rectangle {
    id: root

    property int maxHeight: 800
    property string query: ""
    property int selected: 0

    readonly property var results: {
        const q = query.trim().toLowerCase();
        if (!q.length)
            return Keybinds.binds;
        const tokens = q.split(/\s+/).filter(t => t.length && t !== "+");
        if (!tokens.length)
            return Keybinds.binds;
        return Keybinds.binds.filter(b => tokens.every(t => b.search.includes(t)));
    }
    readonly property int visibleRows: Math.max(1, Math.min(results.length, 9))

    function move(delta) {
        if (results.length === 0)
            return;
        selected = Math.max(0, Math.min(results.length - 1, selected + delta));
    }

    implicitWidth: 760
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

    // swallow clicks so they don't reach the click-outside layer
    MouseArea {
        anchors.fill: parent
    }

    Connections {
        target: Keybinds
        function onBindsChanged() {
            root.selected = 0;
        }
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
            spacing: 9

            Glyph {
                text: Icons.keyboard
                color: Theme.accent
                font.pixelSize: Theme.fontSize + 5
            }
            Txt {
                text: "Keybinds"
                font.pixelSize: Theme.fontLarge
                font.bold: true
            }

            Item {
                Layout.fillWidth: true
            }

            Txt {
                text: root.results.length + (root.results.length === 1 ? " bind" : " binds")
                color: Theme.subtext
                font.pixelSize: Theme.fontSmall
            }
        }

        // ── search field ────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 42
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
                    font.pixelSize: Theme.fontSize + 1
                }

                TextInput {
                    id: field
                    Layout.fillWidth: true
                    focus: true
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize + 1
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.onAccent
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true

                    onTextChanged: {
                        root.query = text;
                        root.selected = 0;
                    }
                    onAccepted: Panels.close()

                    Keys.onUpPressed: root.move(-1)
                    Keys.onDownPressed: root.move(1)
                    Keys.onEscapePressed: Panels.close()

                    Component.onCompleted: forceActiveFocus()

                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: field.text.length === 0
                        text: "Search keybinds — keys, actions, sections…"
                        color: Theme.subtext
                    }
                }
            }
        }

        // ── results ─────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.visibleRows * 46

            ListView {
                id: list
                anchors.fill: parent
                visible: root.results.length > 0
                model: root.results
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                currentIndex: root.selected
                onCurrentIndexChanged: if (currentIndex >= 0)
                    positionViewAtIndex(currentIndex, ListView.Contain)

                delegate: Rectangle {
                    id: row

                    required property var modelData
                    required property int index

                    readonly property bool current: index === root.selected

                    width: list.width
                    height: 44
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
                        onClicked: Panels.close()
                    }

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 10
                            rightMargin: 10
                        }
                        spacing: 12

                        Item {
                            Layout.preferredWidth: 186
                            Layout.fillHeight: true

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4

                                Repeater {
                                    model: row.modelData.caps

                                    Rectangle {
                                        id: keyCap

                                        required property string modelData

                                        implicitWidth: capLabel.implicitWidth + 12
                                        implicitHeight: 22
                                        radius: 5
                                        color: Theme.surfaceHi
                                        border.width: 1
                                        border.color: Theme.border

                                        Txt {
                                            id: capLabel
                                            anchors.centerIn: parent
                                            text: keyCap.modelData
                                            font.pixelSize: Theme.fontSmall - 1
                                            font.bold: true
                                        }
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Txt {
                                Layout.fillWidth: true
                                text: row.modelData.label
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            Txt {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: row.modelData.hint
                                color: Theme.subtext
                                font.pixelSize: Theme.fontSmall
                                elide: Text.ElideRight
                            }
                        }

                        Txt {
                            Layout.alignment: Qt.AlignVCenter
                            text: row.modelData.section
                            color: Theme.subtext
                            font.pixelSize: Theme.fontSmall
                        }
                    }
                }
            }

            Txt {
                anchors.centerIn: parent
                width: parent.width - 40
                visible: root.results.length === 0
                text: Keybinds.error.length
                    ? Keybinds.error
                    : (Keybinds.loaded ? "No keybinds match" : "Loading keybinds…")
                color: Keybinds.error.length ? Theme.red : Theme.subtext
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
            }
        }

        // ── footer ──────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Item {
                Layout.fillWidth: true
            }

            Txt {
                text: "↑↓ browse · Enter/Esc close"
                color: Theme.subtext
                font.pixelSize: Theme.fontSmall
            }
        }
    }
}
