import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// Left rail: brand, new chat, search, history and the settings entry.
Rectangle {
    id: root

    property string filter: ""

    readonly property var filtered: {
        const q = root.filter.toLowerCase().trim()
        return HexinAgent.conversations.filter(c => {
            if (!q)
                return true
            return (c.title || "").toLowerCase().indexOf(q) >= 0
        }).slice().sort((a, b) => (b.updated || 0) - (a.updated || 0))
    }

    // Mirror the visible chats in a ListModel. Binding the view straight to
    // `filtered` hands the ListView a brand-new array every time the service
    // reassigns `conversations` — which happens on every streaming delta — so
    // every row is rebuilt and replays its entry animation. The mirror only
    // changes when a row is added, removed, reordered, or its text changes.
    ListModel {
        id: historyModel
    }

    function rowFor(conv) {
        const n = (conv.messages || []).length
        return {
            chatId: conv.id,
            title: conv.title || "New chat",
            subtitle: n + (n === 1 ? " message · " : " messages · ") + Qt.formatDateTime(new Date(conv.updated || 0), "d MMM")
        }
    }

    function syncHistory() {
        const list = root.filtered
        let sameRows = historyModel.count === list.length
        if (sameRows) {
            for (let i = 0; i < list.length; i++) {
                if (historyModel.get(i).chatId !== list[i].id) {
                    sameRows = false
                    break
                }
            }
        }
        if (!sameRows) {
            historyModel.clear()
            for (let i = 0; i < list.length; i++)
                historyModel.append(root.rowFor(list[i]))
            return
        }
        for (let i = 0; i < list.length; i++) {
            const row = root.rowFor(list[i])
            const cur = historyModel.get(i)
            if (cur.title !== row.title)
                historyModel.setProperty(i, "title", row.title)
            if (cur.subtitle !== row.subtitle)
                historyModel.setProperty(i, "subtitle", row.subtitle)
        }
    }

    onFilteredChanged: syncHistory()
    Component.onCompleted: syncHistory()

    implicitWidth: 258
    color: Qt.alpha(Theme.mantle, 0.9)

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.alpha(Theme.text, 0.03)
            }
            GradientStop {
                position: 1
                color: "transparent"
            }
        }
    }

    Rectangle {
        anchors {
            right: parent.right
            top: parent.top
            bottom: parent.bottom
        }
        width: 1
        color: Theme.border
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: 12
        }
        spacing: 8

        // ───────────── brand ─────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.bottomMargin: 6
            spacing: 10

            Item {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34

                Rectangle {
                    anchors.fill: parent
                    radius: 11
                    color: Theme.accentSoft
                    border.width: 1
                    border.color: Qt.alpha(Theme.accent, 0.45)

                    SequentialAnimation on scale {
                        running: Theme.anim > 0
                        loops: Animation.Infinite
                        NumberAnimation {
                            to: 1.05
                            duration: 2600
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            to: 1
                            duration: 2600
                            easing.type: Easing.InOutSine
                        }
                    }
                }

                Logo {
                    anchors.centerIn: parent
                    size: 24
                    glyphSize: Theme.fontSize + 5
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Txt {
                    text: "HexinAgent"
                    font.bold: true
                    font.pixelSize: Theme.fontSize + 2
                }
                Txt {
                    text: "local history · BYOK"
                    color: Theme.subtext
                    font.pixelSize: Theme.fontSmall - 1
                }
            }

            IconButton {
                glyph: Icons.close
                size: 26
                glyphSize: Theme.fontSmall
                onClicked: HexinAgent.close()
            }
        }

        // ───────────── new chat ─────────────
        Rectangle {
            Layout.fillWidth: true
            height: 38
            radius: Theme.radiusSmall + 1
            color: newMa.containsMouse ? Qt.lighter(Theme.accent, 1.08) : Theme.accent
            border.width: 1
            border.color: Theme.accent

            RowLayout {
                anchors.centerIn: parent
                spacing: 7

                Glyph {
                    text: Icons.plus
                    color: Theme.onAccent
                    font.pixelSize: Theme.fontSmall + 1
                }
                Txt {
                    text: "New chat"
                    color: Theme.onAccent
                    font.bold: true
                }
            }

            MouseArea {
                id: newMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: HexinAgent.newChat()
            }
        }

        // ───────────── search ─────────────
        Rectangle {
            Layout.fillWidth: true
            height: 34
            radius: Theme.radiusSmall
            color: Theme.card
            border.width: 1
            border.color: searchInput.activeFocus ? Theme.accent : Theme.border

            Behavior on border.color {
                ColorAnimation {
                    duration: Theme.animFast
                }
            }

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 10
                    rightMargin: 10
                }
                spacing: 7

                Glyph {
                    text: Icons.search
                    color: Theme.subtext
                    font.pixelSize: Theme.fontSmall
                }

                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    clip: true
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSmall + 1
                    selectionColor: Theme.accentSoft
                    selectedTextColor: Theme.text
                    onTextChanged: root.filter = text

                    Text {
                        anchors.fill: parent
                        visible: searchInput.text.length === 0
                        text: "Search chats"
                        color: Theme.subtext
                        opacity: 0.7
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSmall + 1
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        Txt {
            visible: root.filtered.length > 0
            text: "Recent"
            color: Theme.subtext
            font.pixelSize: Theme.fontSmall - 1
            font.letterSpacing: 1
            font.capitalization: Font.AllUppercase
            Layout.leftMargin: 6
            Layout.topMargin: 4
        }

        // ───────────── history ─────────────
        ListView {
            id: historyList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            model: historyModel
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: row

                required property string chatId
                required property string title
                required property string subtitle
                required property int index

                readonly property bool active: HexinAgent.activeId === chatId
                readonly property bool hot: rowMa.containsMouse

                width: historyList.width
                height: 48
                radius: Theme.radiusSmall
                color: active ? Theme.accentSoft : (hot ? Theme.hover : "transparent")

                opacity: 0
                transform: Translate {
                    id: rowShift
                    x: -10
                }

                Component.onCompleted: {
                    if (Theme.anim <= 0) {
                        row.opacity = 1;
                        rowShift.x = 0;
                        return;
                    }
                    rowIn.start();
                }

                SequentialAnimation {
                    id: rowIn
                    PauseAnimation {
                        duration: Math.min(index, 9) * 32
                    }
                    ParallelAnimation {
                        NumberAnimation {
                            target: row
                            property: "opacity"
                            to: 1
                            duration: 240
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            target: rowShift
                            property: "x"
                            to: 0
                            duration: 280
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                ColumnLayout {
                    anchors {
                        fill: parent
                        leftMargin: 10
                        rightMargin: 30
                    }
                    spacing: 2

                    Item {
                        Layout.fillHeight: true
                    }

                    Txt {
                        text: row.title
                        font.pixelSize: Theme.fontSmall + 1
                        font.bold: row.active
                        color: row.active ? Theme.accent : Theme.text
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Txt {
                        text: row.subtitle
                        color: Theme.subtext
                        font.pixelSize: Theme.fontSmall - 1
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }

                // delete
                Rectangle {
                    z: 2
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        rightMargin: 6
                    }
                    width: 24
                    height: 24
                    radius: 6
                    visible: row.hot || row.active
                    color: delMa.containsMouse ? Qt.alpha(Theme.red, 0.2) : "transparent"

                    Glyph {
                        anchors.centerIn: parent
                        text: Icons.trash
                        color: delMa.containsMouse ? Theme.red : Theme.subtext
                        font.pixelSize: Theme.fontSmall
                    }

                    MouseArea {
                        id: delMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: HexinAgent.deleteChat(row.chatId)
                    }
                }

                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: HexinAgent.selectChat(row.chatId)
                }
            }
        }

        // No results
        Txt {
            visible: root.filtered.length === 0
            Layout.fillWidth: true
            text: root.filter.length ? "No chats match “" + root.filter + "”" : "No chats yet"
            color: Theme.subtext
            font.pixelSize: Theme.fontSmall
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            Layout.topMargin: 10
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.border
        }

        // ───────────── settings ─────────────
        Rectangle {
            Layout.fillWidth: true
            height: 48
            radius: Theme.radiusSmall
            color: HexinAgent.view === "settings" ? Theme.accentSoft : (settingsMa.containsMouse ? Theme.hover : "transparent")

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 10
                    rightMargin: 10
                }
                spacing: 10

                Glyph {
                    text: Icons.cog
                    color: HexinAgent.view === "settings" ? Theme.accent : Theme.subtext
                    font.pixelSize: Theme.fontSmall + 2
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Txt {
                        text: "Settings"
                        font.bold: HexinAgent.view === "settings"
                        color: HexinAgent.view === "settings" ? Theme.accent : Theme.text
                    }
                    Txt {
                        text: HexinAgent.provider ? HexinAgent.provider.name : "No provider"
                        color: Theme.subtext
                        font.pixelSize: Theme.fontSmall - 1
                    }
                }
            }

            MouseArea {
                id: settingsMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: HexinAgent.view === "settings" ? HexinAgent.showChat() : HexinAgent.showSettings()
            }
        }
    }
}
