import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// UnityAgent's own settings page: every provider in the catalogue is available
// as "bring your own key". Keys are written to the agent state directory, not to
// the shell settings file.
Flickable {
    id: root

    property bool showKey: false

    contentWidth: width
    contentHeight: col.implicitHeight + 56
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    focus: true

    onVisibleChanged: {
        if (visible) {
            contentY = 0;
            forceActiveFocus();
        }
    }

    WheelHandler {
        onWheel: event => {
            const step = event.angleDelta.y > 0 ? -90 : 90;
            root.contentY = Math.max(0, Math.min(root.contentHeight - root.height, root.contentY + step));
            event.accepted = true;
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Down) {
            contentY = Math.min(contentHeight - height, contentY + 70);
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            contentY = Math.max(0, contentY - 70);
            event.accepted = true;
        } else if (event.key === Qt.Key_PageDown) {
            contentY = Math.min(contentHeight - height, contentY + height * 0.8);
            event.accepted = true;
        } else if (event.key === Qt.Key_PageUp) {
            contentY = Math.max(0, contentY - height * 0.8);
            event.accepted = true;
        }
    }

    function commitKey() {
        const value = keyInput.text.trim();
        if (value !== UnityAgent.keyFor(UnityAgent.settings.provider))
            UnityAgent.setKey(UnityAgent.settings.provider, value);
    }

    function selectProvider(id) {
        if (id === UnityAgent.settings.provider)
            return;
        root.commitKey();
        UnityAgent.setProvider(id);
        keyInput.text = UnityAgent.keyFor(id);
        root.showKey = false;
    }

    Connections {
        target: UnityAgent
        function onSettingsChanged() {
            if (!promptInput.activeFocus)
                promptInput.text = UnityAgent.settings.systemPrompt || "";
            if (!baseInput.activeFocus)
                baseInput.text = UnityAgent.settings.baseUrl || "";
        }
    }

    ColumnLayout {
        id: col
        x: 28
        y: 24
        width: Math.min(840, root.width - 56)
        spacing: 10

        Txt {
            text: "Agent settings"
            font.pixelSize: Theme.fontLarge + 8
            font.bold: true
            Layout.fillWidth: true
        }

        Txt {
            text: "Bring your own key. Keys, model choice and chat history stay on this machine under ~/.local/state/hexin/unityagent/."
            color: Theme.subtext
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }

        Txt {
            text: "The master on/off switch and per-feature limits live in Settings → UnityAgent."
            color: Theme.accent
            wrapMode: Text.Wrap
            Layout.fillWidth: true
            Layout.bottomMargin: 16
        }

        // ───────────── provider ─────────────
        SectionLabelLocal {
            text: "Provider"
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 3
            columnSpacing: 8
            rowSpacing: 8

            Repeater {
                model: Models.providers

                delegate: Rectangle {
                    id: prov

                    required property var modelData
                    readonly property bool selected: UnityAgent.settings.provider === modelData.id
                    readonly property bool hasKey: (UnityAgent.keys[modelData.id] || "").length > 0

                    Layout.fillWidth: true
                    Layout.preferredHeight: 62
                    radius: Theme.radiusSmall
                    color: selected ? Theme.accentSoft : (provMa.containsMouse ? Theme.hover : Theme.card)
                    border.width: 1
                    border.color: selected ? Theme.accent : Theme.border

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.animFast
                        }
                    }

                    ColumnLayout {
                        anchors {
                            fill: parent
                            leftMargin: 10
                            rightMargin: 10
                        }
                        spacing: 2

                        Item {
                            Layout.fillHeight: true
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Txt {
                                Layout.fillWidth: true
                                text: prov.modelData.name
                                font.bold: prov.selected
                                font.pixelSize: Theme.fontSmall + 1
                                color: prov.selected ? Theme.accent : Theme.text
                                elide: Text.ElideRight
                            }
                        }

                        Txt {
                            Layout.fillWidth: true
                            text: prov.modelData.local ? "local · no key" : (prov.hasKey ? "key saved" : "needs a key")
                            color: Theme.subtext
                            font.pixelSize: Theme.fontSmall - 1
                            elide: Text.ElideRight
                        }

                        Item {
                            Layout.fillHeight: true
                        }
                    }

                    MouseArea {
                        id: provMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectProvider(prov.modelData.id)
                    }
                }
            }
        }

        // ───────────── model ─────────────
        SectionLabelLocal {
            text: "Model"
            Layout.topMargin: 20
        }

        Txt {
            text: "All models exposed by " + (UnityAgent.provider ? UnityAgent.provider.name : "this provider") + ". Pick a chip or add any model id by hand."
            color: Theme.subtext
            font.pixelSize: Theme.fontSmall
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }

        Flow {
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            spacing: 6

            Repeater {
                model: {
                    const list = UnityAgent.modelsForProvider(UnityAgent.settings.provider);
                    const cur = UnityAgent.settings.model;
                    if (cur && cur.length && list.indexOf(cur) < 0)
                        return [cur].concat(list);
                    return list;
                }

                delegate: Rectangle {
                    id: chip

                    required property string modelData
                    readonly property bool selected: UnityAgent.settings.model === modelData
                    readonly property bool custom: (UnityAgent.customModels[UnityAgent.settings.provider] || []).indexOf(modelData) >= 0

                    width: Math.min(280, chipTxt.implicitWidth + 22)
                    height: 32
                    radius: 9
                    color: selected ? Theme.accent : (chipMa.containsMouse ? Theme.hover : Theme.card)
                    border.width: 1
                    border.color: selected ? Theme.accent : Theme.border

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.animFast
                        }
                    }

                    Txt {
                        id: chipTxt
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, 258)
                        elide: Text.ElideRight
                        text: chip.modelData
                        color: chip.selected ? Theme.onAccent : Theme.text
                        font.pixelSize: Theme.fontSmall
                        font.bold: chip.selected
                    }

                    MouseArea {
                        id: chipMa
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                if (chip.custom)
                                    UnityAgent.removeCustomModel(chip.modelData);
                            } else {
                                UnityAgent.setModel(chip.modelData);
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 6
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                height: 36
                radius: Theme.radiusSmall
                color: Theme.card
                border.width: 1
                border.color: customModel.activeFocus ? Theme.accent : Theme.border

                TextInput {
                    id: customModel
                    anchors {
                        fill: parent
                        leftMargin: 10
                        rightMargin: 10
                    }
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSmall + 1
                    selectionColor: Theme.accentSoft
                    clip: true
                    onAccepted: {
                        UnityAgent.addCustomModel(text.trim());
                        text = "";
                    }

                    Text {
                        anchors.fill: parent
                        visible: customModel.text.length === 0
                        text: "Add a custom model id…"
                        color: Theme.subtext
                        opacity: 0.7
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSmall + 1
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            Rectangle {
                width: addTxt.implicitWidth + 24
                height: 36
                radius: Theme.radiusSmall
                color: addMa.containsMouse ? Theme.accentSoft : Theme.card
                border.width: 1
                border.color: Theme.border

                Txt {
                    id: addTxt
                    anchors.centerIn: parent
                    text: "Add model"
                    color: Theme.accent
                    font.pixelSize: Theme.fontSmall
                    font.bold: true
                }

                MouseArea {
                    id: addMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        UnityAgent.addCustomModel(customModel.text.trim());
                        customModel.text = "";
                    }
                }
            }
        }

        // ───────────── connection ─────────────
        SectionLabelLocal {
            text: "Connection"
            Layout.topMargin: 20
        }

        // API key
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: keyCol.implicitHeight + 24
            radius: Theme.radiusSmall + 2
            color: Theme.card

            ColumnLayout {
                id: keyCol
                anchors {
                    fill: parent
                    margins: 12
                }
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Txt {
                        text: "API key"
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Txt {
                        text: UnityAgent.providerNeedsKey ? (UnityAgent.provider ? UnityAgent.provider.keyHint : "") : "not required for local models"
                        color: Theme.subtext
                        font.pixelSize: Theme.fontSmall
                    }

                    Glyph {
                        text: root.showKey ? Icons.eyeSlash : Icons.eye
                        color: eyeMa.containsMouse ? Theme.accent : Theme.subtext
                        font.pixelSize: Theme.fontSmall + 1

                        MouseArea {
                            id: eyeMa
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.showKey = !root.showKey
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        height: 36
                        radius: Theme.radiusSmall
                        color: Theme.bgSolid
                        border.width: 1
                        border.color: keyInput.activeFocus ? Theme.accent : Theme.border

                        TextInput {
                            id: keyInput
                            anchors {
                                fill: parent
                                leftMargin: 10
                                rightMargin: 10
                            }
                            text: UnityAgent.keyFor(UnityAgent.settings.provider)
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: root.showKey ? TextInput.Normal : TextInput.Password
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSmall + 1
                            selectionColor: Theme.accentSoft
                            clip: true
                            onAccepted: root.commitKey()
                            onEditingFinished: root.commitKey()

                            Text {
                                anchors.fill: parent
                                visible: keyInput.text.length === 0
                                text: UnityAgent.providerNeedsKey ? "Paste your key…" : "optional"
                                color: Theme.subtext
                                opacity: 0.7
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSmall + 1
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }

                    Rectangle {
                        width: saveTxt.implicitWidth + 24
                        height: 36
                        radius: Theme.radiusSmall
                        color: saveMa.containsMouse ? Qt.lighter(Theme.accent, 1.1) : Theme.accent

                        Txt {
                            id: saveTxt
                            anchors.centerIn: parent
                            text: "Save"
                            color: Theme.onAccent
                            font.pixelSize: Theme.fontSmall
                            font.bold: true
                        }

                        MouseArea {
                            id: saveMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.commitKey()
                        }
                    }
                }

                Txt {
                    Layout.fillWidth: true
                    text: "Saved automatically to " + UnityAgent.settingsPath + " (mode 600). Never written to the shell settings."
                    color: Theme.subtext
                    font.pixelSize: Theme.fontSmall - 1
                    wrapMode: Text.Wrap
                }
            }
        }

        // Base URL
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 66
            radius: Theme.radiusSmall + 2
            color: Theme.card

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 14
                    rightMargin: 12
                }
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Txt {
                        text: "Base URL"
                        font.bold: true
                    }
                    Txt {
                        text: "Leave empty to use " + (UnityAgent.provider ? UnityAgent.provider.baseUrl : "the provider default")
                        color: Theme.subtext
                        font.pixelSize: Theme.fontSmall - 1
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 330
                    height: 36
                    radius: Theme.radiusSmall
                    color: Theme.bgSolid
                    border.width: 1
                    border.color: baseInput.activeFocus ? Theme.accent : Theme.border

                    TextInput {
                        id: baseInput
                        anchors {
                            fill: parent
                            leftMargin: 10
                            rightMargin: 10
                        }
                        text: UnityAgent.settings.baseUrl || ""
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSmall + 1
                        selectionColor: Theme.accentSoft
                        clip: true
                        onEditingFinished: UnityAgent.setBaseUrl(text.trim())

                        Text {
                            anchors.fill: parent
                            visible: baseInput.text.length === 0
                            text: UnityAgent.provider ? UnityAgent.provider.baseUrl : "https://…"
                            color: Theme.subtext
                            opacity: 0.55
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSmall + 1
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        // Temperature
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 66
            radius: Theme.radiusSmall + 2
            color: Theme.card

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 14
                    rightMargin: 16
                }
                spacing: 16

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Txt {
                        text: "Temperature"
                        font.bold: true
                    }
                    Txt {
                        text: "0 is focused, 1 is balanced, 2 is wild"
                        color: Theme.subtext
                        font.pixelSize: Theme.fontSmall - 1
                    }
                }

                ValueSlider {
                    value: UnityAgent.settings.temperature
                    from: 0
                    to: 2
                    step: 0.1
                    decimals: 1
                    onMoved: v => UnityAgent.setTemperature(v)
                }
            }
        }

        // Test
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 10

            Rectangle {
                width: testTxt.implicitWidth + 28
                height: 36
                radius: Theme.radiusSmall
                color: testMa.containsMouse ? Theme.accentSoft : Theme.card
                border.width: 1
                border.color: Theme.border

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 7

                    Glyph {
                        visible: UnityAgent.testRunning
                        text: Icons.refresh
                        color: Theme.accent
                        font.pixelSize: Theme.fontSmall

                        RotationAnimator on rotation {
                            running: Theme.anim > 0 && UnityAgent.testRunning
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: 900
                        }
                    }

                    Txt {
                        id: testTxt
                        text: UnityAgent.testRunning ? "Testing…" : "Test connection"
                        color: Theme.accent
                        font.pixelSize: Theme.fontSmall
                        font.bold: true
                    }
                }

                MouseArea {
                    id: testMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: UnityAgent.testConnection()
                }
            }

            Txt {
                Layout.fillWidth: true
                text: UnityAgent.testResult
                color: UnityAgent.testResult.toLowerCase().indexOf("ok") === 0 ? Theme.green : Theme.subtext
                font.pixelSize: Theme.fontSmall
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: 2
            }
        }

        // ───────────── system prompt ─────────────
        SectionLabelLocal {
            text: "System prompt"
            Layout.topMargin: 20
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: promptCol.implicitHeight + 24
            radius: Theme.radiusSmall + 2
            color: Theme.card

            ColumnLayout {
                id: promptCol
                anchors {
                    fill: parent
                    margins: 12
                }
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true

                    Txt {
                        Layout.fillWidth: true
                        text: "Instructions sent with every request"
                        color: Theme.subtext
                        font.pixelSize: Theme.fontSmall
                    }

                    Rectangle {
                        width: resetTxt.implicitWidth + 18
                        height: 24
                        radius: 6
                        color: resetMa.containsMouse ? Theme.hover : "transparent"
                        border.width: 1
                        border.color: Theme.border

                        Txt {
                            id: resetTxt
                            anchors.centerIn: parent
                            text: "Reset"
                            color: Theme.subtext
                            font.pixelSize: Theme.fontSmall - 1
                        }
                        MouseArea {
                            id: resetMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: UnityAgent.resetSystemPrompt()
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 118
                    radius: Theme.radiusSmall
                    color: Theme.bgSolid
                    border.width: 1
                    border.color: promptInput.activeFocus ? Theme.accent : Theme.border

                    TextEdit {
                        id: promptInput
                        anchors {
                            fill: parent
                            margins: 10
                        }
                        text: UnityAgent.settings.systemPrompt || ""
                        textFormat: TextEdit.PlainText
                        wrapMode: TextEdit.Wrap
                        selectByMouse: true
                        color: Theme.text
                        selectionColor: Theme.accentSoft
                        selectedTextColor: Theme.text
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSmall + 1
                        onTextChanged: promptSave.restart()
                        clip: true
                    }
                }

                Txt {
                    Layout.fillWidth: true
                    Layout.topMargin: -2
                    text: "A built-in description of this machine (the Lua Hyprland config, keybinds, the shell) and the tool list are appended automatically."
                    color: Theme.subtext
                    font.pixelSize: Theme.fontSmall - 1
                    wrapMode: Text.Wrap
                }
            }

            Timer {
                id: promptSave
                interval: 600
                onTriggered: UnityAgent.setSystemPrompt(promptInput.text)
            }
        }

        // ───────────── data ─────────────
        SectionLabelLocal {
            text: "Data"
            Layout.topMargin: 20
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 66
            radius: Theme.radiusSmall + 2
            color: Theme.card

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 14
                    rightMargin: 12
                }
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Txt {
                        text: "Chat history"
                        font.bold: true
                    }
                    Txt {
                        text: UnityAgent.conversations.length + (UnityAgent.conversations.length === 1 ? " conversation stored locally" : " conversations stored locally")
                        color: Theme.subtext
                        font.pixelSize: Theme.fontSmall - 1
                    }
                }

                Rectangle {
                    width: clearTxt.implicitWidth + 22
                    height: 32
                    radius: Theme.radiusSmall
                    color: clearMa.containsMouse ? Qt.alpha(Theme.red, 0.18) : "transparent"
                    border.width: 1
                    border.color: clearMa.containsMouse ? Qt.alpha(Theme.red, 0.5) : Theme.border

                    Txt {
                        id: clearTxt
                        anchors.centerIn: parent
                        text: "Clear all chats"
                        color: clearMa.containsMouse ? Theme.red : Theme.subtext
                        font.pixelSize: Theme.fontSmall
                    }

                    MouseArea {
                        id: clearMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: UnityAgent.clearHistory()
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 12
        }
    }

    // Local section label (the settings module has one, but this page is
    // self-contained so it can be opened without importing the settings app).
    component SectionLabelLocal: Txt {
        color: Theme.accent
        font.bold: true
        font.pixelSize: Theme.fontSmall + 1
        font.letterSpacing: 1
        font.capitalization: Font.AllUppercase
        Layout.topMargin: 8
        Layout.bottomMargin: 2
    }
}
