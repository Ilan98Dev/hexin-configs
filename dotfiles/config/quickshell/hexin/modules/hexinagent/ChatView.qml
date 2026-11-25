import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// The chat page: conversation header, message stream and the centered composer.
Item {
    id: root

    readonly property bool empty: HexinAgent.messages.length === 0
    readonly property var suggestions: [
        "What is using my CPU?",
        "Update my system safely",
        "Write a screenshot keybind"
    ]

    // ───────────── message model ─────────────
    // A ListModel mirrors HexinAgent.messages so appending or updating one
    // message touches only that row. Binding the Repeater straight to the
    // service array would regenerate every delegate on each change, which
    // replays the entry animation for the whole conversation.
    ListModel {
        id: messageModel
    }

    // True while several rows are added at once (first open, chat switch), so
    // the rows can stagger their entry; a single new message appears at once.
    property bool bulkAppend: true

    // Last synced message objects, kept by reference so we can tell an actual
    // change from a rebuild of the service array.
    property var syncedMessages: []

    function syncMessages() {
        const msgs = HexinAgent.messages || []
        while (messageModel.count > msgs.length)
            messageModel.remove(messageModel.count - 1)

        const added = msgs.length - messageModel.count
        if (added > 1)
            bulkAppend = true
        else if (added === 1)
            bulkAppend = false

        for (let i = 0; i < msgs.length; i++) {
            if (i < messageModel.count) {
                if (syncedMessages[i] !== msgs[i])
                    messageModel.setProperty(i, "msg", msgs[i])
            } else {
                messageModel.append({ msg: msgs[i] })
            }
        }
        syncedMessages = msgs.slice()
    }

    Component.onCompleted: syncMessages()

    Connections {
        target: HexinAgent
        function onMessagesChanged() {
            root.syncMessages();
        }
    }

    // ───────────── header ─────────────
    Rectangle {
        id: header
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        height: 64
        color: "transparent"

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Theme.border
        }

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 26
                rightMargin: 22
            }
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Txt {
                    text: HexinAgent.activeTitle
                    font.pixelSize: Theme.fontLarge
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Txt {
                    text: HexinAgent.provider ? (HexinAgent.provider.name + " · " + (HexinAgent.settings.model || "no model")) : "No provider"
                    color: Theme.subtext
                    font.pixelSize: Theme.fontSmall
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            Txt {
                text: !HexinAgent.enabled ? "off" : (HexinAgent.runningCommand ? "running…" : (HexinAgent.busy ? "thinking…" : (HexinAgent.modelReady ? "ready" : "needs a key")))
                color: HexinAgent.enabled ? Theme.subtext : Theme.red
                font.pixelSize: Theme.fontSmall
            }

            IconButton {
                glyph: Icons.plus
                size: 32
                onClicked: HexinAgent.newChat()
            }
        }
    }

    // ───────────── messages ─────────────
    // A Flickable + Column instead of a ListView: chat rows change height while
    // they lay out (a command card gains its output, a reply streams in), and a
    // recycling view can drop such a row mid-polish and rebuild it forever.
    Flickable {
        id: list
        anchors {
            left: parent.left
            right: parent.right
            top: header.bottom
            bottom: parent.bottom
            bottomMargin: composerDock.height + 48
        }
        visible: !root.empty && HexinAgent.enabled
        clip: true
        contentWidth: width
        contentHeight: stream.implicitHeight + 28
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        Column {
            id: stream

            y: 18
            width: list.width
            spacing: 18

            Repeater {
                model: messageModel

                onCountChanged: {
                    list.follow = true;
                    Qt.callLater(list.pinToEnd);
                }

                delegate: Item {
                    id: delegateRoot

                    required property var msg
                    required property int index

                    width: stream.width
                    height: bubble.implicitHeight

                    ChatBubble {
                        id: bubble
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(820, parent.width - 48)
                        maxWidth: width
                        message: delegateRoot.msg
                        index: delegateRoot.index
                        stagger: root.bulkAppend
                        showTime: true
                        onRunRequested: code => HexinAgent.approveCommand(code)
                        onToolDecision: (callId, approved) => HexinAgent.approveTool(callId, approved)
                        onInputSubmitted: (callId, value, cancelled) => HexinAgent.submitInput(callId, value, cancelled)
                    }
                }
            }
        }

        // Rows grow in place (a command card gains its output, a reply streams
        // in), so keep the view pinned to the bottom while the user is there.
        // Scrolling up releases the pin until the next message arrives.
        property bool follow: true

        function pinToEnd() {
            if (!follow)
                return;
            contentY = Math.max(0, contentHeight - height);
        }

        onContentHeightChanged: Qt.callLater(list.pinToEnd)
        onHeightChanged: Qt.callLater(list.pinToEnd)
        onContentYChanged: {
            if (contentY < Math.max(0, contentHeight - height) - 8)
                follow = false;
        }
        onMovementEnded: follow = atYEnd
    }

    // Fade the stream out under the composer.
    Rectangle {
        anchors {
            left: parent.left
            right: parent.right
            bottom: composerDock.top
            bottomMargin: 2
        }
        height: 40
        visible: !root.empty && HexinAgent.enabled
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.alpha(Theme.base, 0)
            }
            GradientStop {
                position: 1
                color: Qt.alpha(Theme.base, 0.95)
            }
        }
    }

    // ───────────── empty state ─────────────
    ColumnLayout {
        id: heroCol
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: composerDock.top
            bottomMargin: 30
        }
        width: Math.min(680, parent.width - 80)
        spacing: 12
        visible: root.empty && HexinAgent.enabled
        opacity: 0

        Component.onCompleted: {
            if (Theme.anim <= 0) {
                opacity = 1;
                return;
            }
            heroIn.start();
        }

        ParallelAnimation {
            id: heroIn
            NumberAnimation {
                target: heroCol
                property: "opacity"
                to: 1
                duration: 460
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: heroShift
                property: "y"
                to: 0
                duration: 520
                easing.type: Easing.OutCubic
            }
        }

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 74
            Layout.preferredHeight: 74
            transform: Translate {
                id: heroShift
                y: 16
            }

            Rectangle {
                anchors.centerIn: parent
                width: 74
                height: 74
                radius: 23
                color: Theme.accentSoft
                border.width: 1
                border.color: Qt.alpha(Theme.accent, 0.5)

                SequentialAnimation on scale {
                    running: Theme.anim > 0
                    loops: Animation.Infinite
                    NumberAnimation {
                        to: 1.06
                        duration: 2200
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: 1
                        duration: 2200
                        easing.type: Easing.InOutSine
                    }
                }
            }

            Logo {
                anchors.centerIn: parent
                size: 48
                glyphSize: 30
            }
        }

        Txt {
            Layout.fillWidth: true
            text: "How can I help?"
            font.pixelSize: Theme.fontLarge + 10
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
        }

        Txt {
            Layout.fillWidth: true
            text: "Ask a question, plan a change, or paste an error. HexinAgent can read files, search the web and run commands — anything that changes your system waits for your approval."
            color: Theme.subtext
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            Layout.leftMargin: 30
            Layout.rightMargin: 30
        }
    }

    // ───────────── off state ─────────────
    // The window still opens when the universal switch is off, so the agent is
    // findable and the reason is obvious. The composer, history and neon are
    // hidden; Settings > HexinAgent is one click away.
    Item {
        id: offState
        anchors {
            left: parent.left
            right: parent.right
            top: header.bottom
            bottom: parent.bottom
        }
        visible: !HexinAgent.enabled

        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(480, parent.width - 60)
            spacing: 14

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 76
                implicitHeight: 76
                radius: 24
                color: Theme.surfaceHi
                border.width: 1
                border.color: Theme.border

                Logo {
                    anchors.centerIn: parent
                    size: 48
                    glyphSize: 30
                    opacity: 0.45
                }
            }

            Txt {
                Layout.fillWidth: true
                text: "HexinAgent is turned off"
                font.pixelSize: Theme.fontLarge + 8
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
            }

            Txt {
                Layout.fillWidth: true
                text: "Turn it back on in Settings → HexinAgent. The same page has the per-feature switches, including project creation, package management and the weekly update check."
                color: Theme.subtext
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
            }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 4
                implicitWidth: offLbl.implicitWidth + 30
                implicitHeight: 36
                radius: Theme.radiusSmall
                color: offMa.containsMouse ? Theme.accent : Theme.surfaceHi
                border.width: 1
                border.color: offMa.containsMouse ? Theme.accent : Theme.border

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.animFast
                    }
                }

                Txt {
                    id: offLbl
                    anchors.centerIn: parent
                    text: "Open Settings → HexinAgent"
                    color: offMa.containsMouse ? Theme.onAccent : Theme.text
                    font.bold: true
                }
                MouseArea {
                    id: offMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        HexinAgent.close();
                        Panels.settingsPage = "hexinagent";
                        Panels.openSettings();
                    }
                }
            }
        }
    }

    // ───────────── composer ─────────────
    // Starts in the middle of the page and glides down once the chat has
    // messages, so the first thing you see really is a centered chat field.
    Item {
        id: composerDock
        width: parent.width
        height: composer.height
        visible: HexinAgent.enabled
        y: (root.height - composer.height) / 2 + 62

        states: State {
            name: "docked"
            when: !root.empty
            PropertyChanges {
                target: composerDock
                y: root.height - composerDock.height - 20
            }
        }

        transitions: Transition {
            NumberAnimation {
                target: composerDock
                property: "y"
                duration: Math.max(1, Theme.anim + 160)
                easing.type: Easing.OutCubic
            }
        }

        ChatComposer {
            id: composer
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(820, parent.width - 48)
            busy: HexinAgent.busy || HexinAgent.runningCommand
            canStop: HexinAgent.busy && !HexinAgent.runningCommand
            hint: HexinAgent.runningCommand ? "Running the approved command…" : ""
            modelLabel: HexinAgent.settings.model || ""
            onSend: text => HexinAgent.sendMessage(text)
            onStop: HexinAgent.stop()
        }
    }

    // Suggestions sit under the composer while the chat is empty, aligned to
    // the field so the whole block reads as one column.
    Flow {
        visible: root.empty && HexinAgent.enabled
        x: composer.x
        width: composer.width
        anchors {
            top: composerDock.bottom
            topMargin: 14
        }
        spacing: 8

        Repeater {
            model: root.suggestions

            delegate: Rectangle {
                required property string modelData
                readonly property bool hot: sugMa.containsMouse

                width: sugTxt.implicitWidth + 22
                height: 30
                radius: 15
                color: hot ? Theme.accentSoft : Theme.card
                border.width: 1
                border.color: hot ? Qt.alpha(Theme.accent, 0.55) : Theme.border

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.animFast
                    }
                }

                Txt {
                    id: sugTxt
                    anchors.centerIn: parent
                    text: modelData
                    color: hot ? Theme.accent : Theme.subtext
                    font.pixelSize: Theme.fontSmall
                }

                MouseArea {
                    id: sugMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        composer.text = modelData;
                        composer.focusEditor();
                    }
                }
            }
        }
    }

    function focusComposer() {
        composer.focusEditor();
    }
}
