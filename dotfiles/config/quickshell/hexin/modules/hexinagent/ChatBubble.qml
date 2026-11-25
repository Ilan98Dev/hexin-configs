import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components

// One chat message.
//
// Assistant text is rendered plain on the surface (no heavy card around every
// reply); fenced runs become code cards, shell runs get a single Approve & Run
// panel, and finished commands become terminal cards. Nothing is executed until
// that panel is pressed.
Item {
    id: root

    property var message: ({})
    property int index: 0
    property real maxWidth: 760
    property bool showTime: false
    property bool expanded: false
    // When a whole conversation appears at once, rows stagger in; a single
    // message that arrives later fades in immediately.
    property bool stagger: true

    signal runRequested(string code)
    // Approve/Deny on a tool card. The service forwards it to the daemon,
    // which is blocked waiting for this exact call id.
    signal toolDecision(string callId, bool approved)
    // Answer to an interactive prompt (sudo password, confirmation, ...).
    // The value is sent straight to the daemon and never stored in the message.
    signal inputSubmitted(string callId, string value, bool cancelled)

    readonly property string role: message.role || "assistant"
    readonly property bool isUser: role === "user"
    readonly property bool isTool: role === "tool"
    readonly property bool isNote: role === "note"
    readonly property bool isError: message.error === true
    readonly property bool pending: message.pending === true
    readonly property bool needsApproval: message.needsApproval === true && pending
    readonly property bool needsInput: message.needsInput === true && pending
    readonly property string inputPrompt: message.inputPrompt || ""
    readonly property bool inputSecret: message.inputSecret === true
    readonly property bool denied: message.denied === true
    readonly property string callId: message.callId || ""
    readonly property string toolName: message.toolName || ""
    readonly property var toolArgs: message.toolArgs || ({})
    readonly property string content: message.content || ""
    readonly property string output: message.output || ""
    readonly property string imagePath: message.imagePath || ""
    readonly property string title: message.title || ""
    readonly property var exitCode: (message.exitCode === undefined ? null : message.exitCode)
    readonly property var segments: parseSegments(content)

    readonly property string toolLabel: {
        switch (toolName) {
        case "read_file":
            return "Read file";
        case "list_dir":
            return "List folder";
        case "search_files":
            return "Search files";
        case "fetch_url":
            return "Fetch page";
        case "web_search":
            return "Web search";
        case "screenshot":
            return "Screenshot";
        case "mouse_move":
            return "Mouse move";
        case "mouse_click":
            return "Mouse click";
        case "mouse_scroll":
            return "Mouse scroll";
        case "create_project":
            return "Create project";
        case "write_file":
            return "Write file";
        case "edit_file":
            return "Edit file";
        case "run_command":
            return "Run command";
        default:
            return "Tool";
        }
    }

    // What the card shows above the output: the command, path, query or diff.
    readonly property string toolBody: {
        if (!toolName.length)
            return content;
        const a = toolArgs || {};
        switch (toolName) {
        case "run_command":
            return (a.cwd ? "In: " + a.cwd + "\n" : "") + (a.command || "");
        case "create_project":
            return "~/Projects/HexinAgent/" + (a.name || "");
        case "read_file":
            return a.path || "";
        case "list_dir":
            return a.path || "~";
        case "search_files":
            return (a.pattern ? "Pattern: " + a.pattern : "") + (a.path ? "\nIn: " + a.path : "") + (a.glob ? "\nGlob: " + a.glob : "");
        case "fetch_url":
            return a.url || "";
        case "web_search":
            return a.query || "";
        case "screenshot":
            return a.region ? "Region: " + a.region : (a.monitor ? "Monitor: " + a.monitor : "Whole screen");
        case "mouse_move":
            return "To: " + (a.x !== undefined ? a.x : "?") + ", " + (a.y !== undefined ? a.y : "?");
        case "mouse_click": {
            const at = (a.x !== undefined && a.y !== undefined) ? "At: " + a.x + ", " + a.y + "\n" : "At the current pointer\n";
            const button = a.button || "left";
            const count = (a.count && a.count > 1) ? " ×" + a.count : "";
            return at + "Button: " + button + count;
        }
        case "mouse_scroll":
            return "Direction: " + (a.direction || "down") + " ×" + (a.amount || 3);
        case "write_file":
            return (a.path || "") + (a.content ? "\n\n" + truncate(a.content, 4000) : "");
        case "edit_file":
            return (a.path || "") + "\n\n" + truncate(a.old_string || "", 2000) + "\n→\n" + truncate(a.new_string || "", 2000);
        default:
            return JSON.stringify(a);
        }
    }

    readonly property string toolTitle: {
        if (needsApproval)
            return "Approve " + toolLabel.toLowerCase() + "?";
        if (needsInput)
            return "Waiting for input";
        if (pending)
            return toolLabel + "…";
        if (denied)
            return "Denied";
        if (!title.length || title === "Done")
            return toolLabel + " finished";
        return title;
    }

    // A single shell command (or the whole set of shell blocks) becomes one
    // approval panel, so there is never a tiny "run" link hiding in a corner.
    readonly property string approvalCode: {
        if (isUser || isTool || isNote || pending)
            return ""
        const top = (message.code || "").trim()
        if (top.length)
            return top
        const shells = segments.filter(s => s.kind === "code" && isShell(s.lang))
        if (!shells.length)
            return ""
        return shells.map(s => s.body.trim()).filter(s => s.length).join("\n")
    }
    readonly property bool hasApproval: approvalCode.length > 0

    readonly property color fg: isUser ? Theme.onAccent : Theme.text
    readonly property color muted: isUser ? Qt.alpha(Theme.onAccent, 0.72) : Theme.subtext
    readonly property int padH: isUser ? 16 : ((isError && !isTool) ? 14 : 0)
    readonly property int padV: isUser ? 10 : ((isError && !isTool) ? 12 : 0)
    readonly property int contentMax: maxWidth - (isUser ? 0 : 42)
    readonly property var outLines: output.length ? output.split("\n") : []
    // While a command runs the card behaves like a terminal tail: the newest
    // lines stay visible. Once it finishes, long command output keeps the tail
    // (errors live there) while file/tool output keeps the head, both with a
    // "Show all" toggle.
    readonly property bool tailOutput: root.toolName === "run_command"
    readonly property string tailText: outLines.slice(Math.max(0, outLines.length - 12)).join("\n")
    readonly property string shownOutput: (root.pending || root.tailOutput) && !root.expanded
        ? tailText
        : (expanded ? output : outLines.slice(0, 12).join("\n"))

    implicitHeight: layout.implicitHeight
    Layout.fillWidth: true

    transform: Translate {
        id: shift
        y: 14
    }
    opacity: 0

    Component.onCompleted: {
        if (Theme.anim <= 0) {
            root.opacity = 1;
            shift.y = 0;
        } else {
            entry.start();
        }
        if (root.needsInput)
            Qt.callLater(inputField.forceActiveFocus);
    }

    onNeedsInputChanged: {
        if (root.needsInput)
            Qt.callLater(inputField.forceActiveFocus);
    }

    SequentialAnimation {
        id: entry
        PauseAnimation {
            // A delegate can briefly report index -1 while rows are torn down
            // (chat switch); a negative duration is invalid, so clamp it.
            duration: root.stagger ? Math.max(0, Math.min(root.index, 7)) * 32 : 0
        }
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "opacity"
                to: 1
                duration: Math.max(120, Theme.anim + 60)
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: shift
                property: "y"
                to: 0
                duration: Math.max(160, Theme.anim + 90)
                easing.type: Easing.OutCubic
            }
        }
    }

    // Width measurement for short user bubbles.
    Text {
        id: measure
        visible: false
        text: root.content.length ? root.content : " "
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        wrapMode: Text.NoWrap
    }

    RowLayout {
        id: layout
        width: parent.width
        spacing: 12
        layoutDirection: root.isUser ? Qt.RightToLeft : Qt.LeftToRight

        // ───────────── avatar ─────────────
        Rectangle {
            visible: !root.isUser
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: 1
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            radius: 10
            color: root.isTool ? Theme.surfaceHi : Theme.accentSoft
            border.width: 1
            border.color: root.isTool ? Theme.border : Qt.alpha(Theme.accent, 0.45)

            Glyph {
                anchors.centerIn: parent
                visible: root.isTool
                text: Icons.terminal
                color: root.isError ? Theme.red : Theme.subtext
                font.pixelSize: Theme.fontSmall + 1
            }

            Logo {
                anchors.centerIn: parent
                visible: !root.isTool
                size: 22
                glyphSize: Theme.fontSmall + 1
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 6

            // ───────────── meta line ─────────────
            RowLayout {
                visible: !root.isNote
                Layout.fillWidth: true
                spacing: 6

                Item {
                    visible: root.isUser
                    Layout.fillWidth: true
                }

                Txt {
                    text: root.isUser ? "You" : (root.isTool ? root.toolLabel : "HexinAgent")
                    color: root.isUser ? Theme.subtext : (root.isError ? Theme.red : Theme.accent)
                    font.pixelSize: Theme.fontSmall
                    font.bold: true
                }

                Txt {
                    visible: root.showTime && (root.message.ts || 0) > 0
                    text: "· " + Qt.formatDateTime(new Date(root.message.ts || 0), "hh:mm")
                    color: Theme.subtext
                    font.pixelSize: Theme.fontSmall - 1
                }

                Item {
                    visible: !root.isUser
                    Layout.fillWidth: true
                }
            }

            // ───────────── bubble ─────────────
            Rectangle {
                id: bubble

                Layout.alignment: root.isNote ? Qt.AlignHCenter : (root.isUser ? Qt.AlignRight : Qt.AlignLeft)
                Layout.fillWidth: !root.isUser && !root.isNote && (!root.isError || root.isTool)
                Layout.maximumWidth: root.isNote ? root.maxWidth * 0.72 : root.contentMax
                Layout.preferredWidth: {
                    if (root.isNote)
                        return root.maxWidth * 0.72;
                    if (root.isUser)
                        return Math.min(root.contentMax, Math.max(120, measure.implicitWidth + root.padH * 2 + 8));
                    if (root.isError && !root.isTool)
                        return Math.min(root.contentMax, Math.max(260, measure.implicitWidth + root.padH * 2));
                    return 0;
                }

                implicitHeight: col.implicitHeight + root.padV * 2
                radius: root.isUser ? Theme.radius + 4 : ((root.isError && !root.isTool) || root.isNote ? Theme.radius + 2 : 0)
                color: root.isUser
                    ? Theme.accent
                    : ((root.isError && !root.isTool) ? Qt.alpha(Theme.red, 0.09) : (root.isNote ? Theme.accentSoft : "transparent"))
                border.width: root.isUser ? 0 : ((root.isError && !root.isTool) ? 1 : (root.isNote ? 1 : 0))
                border.color: root.isError ? Qt.alpha(Theme.red, 0.45) : Qt.alpha(Theme.accent, 0.35)

                ColumnLayout {
                    id: col

                    x: root.padH
                    y: root.padV
                    width: bubble.width - root.padH * 2
                    spacing: 9

                    Txt {
                        visible: root.title.length > 0 && !root.isTool
                        text: root.title
                        font.bold: true
                        font.pixelSize: Theme.fontSmall + 1
                        color: root.isUser ? Theme.onAccent : (root.isError ? Theme.red : Theme.accent)
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                    }

                    Repeater {
                        model: root.isTool ? [] : root.segments

                        delegate: ColumnLayout {
                            id: seg

                            required property var modelData
                            property bool copied: false
                            // Shell blocks are shown in the approval panel below,
                            // so don't render the same command twice.
                            readonly property bool hiddenShell: root.hasApproval && modelData.kind === "code" && root.isShell(modelData.lang)

                            Layout.fillWidth: true
                            spacing: 8

                            TextEdit {
                                visible: modelData.kind === "text"
                                Layout.fillWidth: true
                                // Assistant prose is markdown (headings, lists,
                                // emphasis, inline code, links); what the user
                                // typed stays literal.
                                text: root.isUser ? modelData.body : root.markdownToHtml(modelData.body)
                                textFormat: root.isUser ? TextEdit.PlainText : TextEdit.RichText
                                readOnly: true
                                selectByMouse: true
                                wrapMode: TextEdit.Wrap
                                color: root.fg
                                selectionColor: root.isUser ? Qt.alpha(Theme.onAccent, 0.3) : Theme.accentSoft
                                selectedTextColor: root.fg
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize
                                Layout.preferredHeight: visible ? contentHeight : 0
                                cursorVisible: false
                                onLinkActivated: link => Qt.openUrlExternally(link)
                            }

                            Rectangle {
                                visible: modelData.kind === "code" && !seg.hiddenShell
                                Layout.fillWidth: true
                                color: root.isUser ? Qt.alpha("#000000", 0.18) : Theme.bgSolid
                                radius: Theme.radiusSmall
                                border.width: 1
                                border.color: root.isUser ? Qt.alpha("#ffffff", 0.12) : Theme.border
                                implicitHeight: codeCol.implicitHeight + 16

                                ColumnLayout {
                                    id: codeCol
                                    x: 8
                                    y: 8
                                    width: parent.width - 16
                                    spacing: 6

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Txt {
                                            text: (modelData.lang || "code").toLowerCase()
                                            color: root.muted
                                            font.pixelSize: Theme.fontSmall - 1
                                            font.letterSpacing: 0.5
                                            Layout.fillWidth: true
                                        }

                                        Rectangle {
                                            width: copyLbl.implicitWidth + 16
                                            height: 22
                                            radius: 6
                                            color: copyMa.containsMouse ? Theme.hover : "transparent"

                                            Txt {
                                                id: copyLbl
                                                anchors.centerIn: parent
                                                text: seg.copied ? "Copied" : "Copy"
                                                color: seg.copied ? Theme.green : root.muted
                                                font.pixelSize: Theme.fontSmall - 1
                                            }
                                            MouseArea {
                                                id: copyMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.copyText(modelData.body);
                                                    seg.copied = true;
                                                    copyReset.restart();
                                                }
                                            }
                                            Timer {
                                                id: copyReset
                                                interval: 1400
                                                onTriggered: seg.copied = false
                                            }
                                        }
                                    }

                                    TextEdit {
                                        Layout.fillWidth: true
                                        text: modelData.body
                                        textFormat: TextEdit.PlainText
                                        readOnly: true
                                        selectByMouse: true
                                        wrapMode: TextEdit.Wrap
                                        color: root.fg
                                        selectionColor: Theme.accentSoft
                                        selectedTextColor: Theme.text
                                        font.family: "monospace"
                                        font.pixelSize: Theme.fontSmall + 1
                                        Layout.preferredHeight: contentHeight
                                        cursorVisible: false
                                    }
                                }
                            }
                        }
                    }

                    // ───────────── approve & run ─────────────
                    Rectangle {
                        visible: root.hasApproval
                        Layout.fillWidth: true
                        Layout.topMargin: 1
                        implicitHeight: approvalCol.implicitHeight + 24
                        radius: Theme.radius + 2
                        color: Qt.alpha(Theme.accent, 0.07)
                        border.width: 1
                        border.color: Qt.alpha(Theme.accent, 0.38)

                        ColumnLayout {
                            id: approvalCol
                            x: 12
                            y: 12
                            width: parent.width - 24
                            spacing: 9

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Glyph {
                                    text: Icons.terminal
                                    color: Theme.accent
                                    font.pixelSize: Theme.fontSmall + 1
                                }

                                Txt {
                                    Layout.fillWidth: true
                                    text: "Approve this command"
                                    color: Theme.accent
                                    font.bold: true
                                    font.pixelSize: Theme.fontSmall + 1
                                }

                                Txt {
                                    text: "nothing runs without you"
                                    color: Theme.subtext
                                    font.pixelSize: Theme.fontSmall - 1
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: cmdTxt.contentHeight + 18
                                radius: Theme.radiusSmall
                                color: Theme.bgSolid
                                border.width: 1
                                border.color: Theme.border

                                TextEdit {
                                    id: cmdTxt
                                    anchors {
                                        fill: parent
                                        margins: 9
                                    }
                                    text: root.approvalCode
                                    textFormat: TextEdit.PlainText
                                    readOnly: true
                                    selectByMouse: true
                                    wrapMode: TextEdit.Wrap
                                    color: Theme.text
                                    selectionColor: Theme.accentSoft
                                    selectedTextColor: Theme.text
                                    font.family: "monospace"
                                    font.pixelSize: Theme.fontSmall + 1
                                    cursorVisible: false
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Item {
                                    Layout.fillWidth: true
                                }

                                Rectangle {
                                    width: approvalCopy.implicitWidth + 20
                                    height: 28
                                    radius: 7
                                    color: approvalCopyMa.containsMouse ? Theme.hover : "transparent"
                                    border.width: 1
                                    border.color: Theme.border

                                    Txt {
                                        id: approvalCopy
                                        anchors.centerIn: parent
                                        text: "Copy"
                                        color: Theme.subtext
                                        font.pixelSize: Theme.fontSmall
                                    }
                                    MouseArea {
                                        id: approvalCopyMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.copyText(root.approvalCode)
                                    }
                                }

                                Rectangle {
                                    width: approveLbl.implicitWidth + 24
                                    height: 28
                                    radius: 7
                                    color: approveMa.containsMouse ? Qt.lighter(Theme.accent, 1.12) : Theme.accent

                                    Txt {
                                        id: approveLbl
                                        anchors.centerIn: parent
                                        text: "Approve & Run"
                                        color: Theme.onAccent
                                        font.pixelSize: Theme.fontSmall
                                        font.bold: true
                                    }
                                    MouseArea {
                                        id: approveMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.runRequested(root.approvalCode)
                                    }
                                }
                            }
                        }
                    }

                    // ───────────── command result ─────────────
                    Rectangle {
                        visible: root.isTool
                        Layout.fillWidth: true
                        implicitHeight: toolCol.implicitHeight + 24
                        radius: Theme.radius + 2
                        color: Theme.card
                        border.width: 1
                        border.color: root.isError ? Qt.alpha(Theme.red, 0.42) : Theme.border

                        ColumnLayout {
                            id: toolCol
                            x: 12
                            y: 12
                            width: parent.width - 24
                            spacing: 9

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Rectangle {
                                    width: 7
                                    height: 7
                                    radius: 4
                                    color: root.pending ? Theme.accent : (root.isError ? Theme.red : Theme.green)

                                    SequentialAnimation on opacity {
                                        running: Theme.anim > 0 && root.pending
                                        loops: Animation.Infinite
                                        NumberAnimation {
                                            to: 0.25
                                            duration: 480
                                        }
                                        NumberAnimation {
                                            to: 1
                                            duration: 480
                                        }
                                    }
                                }

                                Txt {
                                    Layout.fillWidth: true
                                    text: root.toolTitle
                                    color: root.pending ? Theme.accent : (root.isError ? Theme.red : Theme.text)
                                    font.bold: true
                                    font.pixelSize: Theme.fontSmall + 1
                                    elide: Text.ElideRight
                                }

                                Rectangle {
                                    visible: !root.pending && root.exitCode !== null
                                    Layout.preferredWidth: exitLbl.implicitWidth + 16
                                    Layout.preferredHeight: 20
                                    radius: 10
                                    color: root.isError ? Qt.alpha(Theme.red, 0.16) : Qt.alpha(Theme.green, 0.14)

                                    Txt {
                                        id: exitLbl
                                        anchors.centerIn: parent
                                        text: "exit " + root.exitCode
                                        color: root.isError ? Theme.red : Theme.green
                                        font.pixelSize: Theme.fontSmall - 1
                                        font.bold: true
                                    }
                                }
                            }

                            Rectangle {
                                visible: root.toolBody.length > 0
                                Layout.fillWidth: true
                                Layout.preferredHeight: toolCmd.contentHeight + 16
                                radius: Theme.radiusSmall
                                color: Theme.bgSolid
                                border.width: 1
                                border.color: Theme.border

                                TextEdit {
                                    id: toolCmd
                                    x: 8
                                    y: 8
                                    width: parent.width - 16
                                    height: contentHeight
                                    text: root.toolBody
                                    textFormat: TextEdit.PlainText
                                    readOnly: true
                                    selectByMouse: true
                                    wrapMode: TextEdit.Wrap
                                    color: Theme.subtext
                                    selectionColor: Theme.accentSoft
                                    selectedTextColor: Theme.text
                                    font.family: "monospace"
                                    font.pixelSize: Theme.fontSmall + 1
                                    cursorVisible: false
                                }
                            }

                            // ───────────── interactive input ─────────────
                            Rectangle {
                                visible: root.needsInput
                                Layout.fillWidth: true
                                implicitHeight: inputCol.implicitHeight + 24
                                radius: Theme.radiusSmall
                                color: Qt.alpha(Theme.accent, 0.06)
                                border.width: 1
                                border.color: Qt.alpha(Theme.accent, 0.42)

                                ColumnLayout {
                                    id: inputCol
                                    x: 12
                                    y: 12
                                    width: parent.width - 24
                                    spacing: 8

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Glyph {
                                            text: root.inputSecret ? Icons.lock : Icons.terminal
                                            color: Theme.accent
                                            font.pixelSize: Theme.fontSmall + 1
                                        }

                                        Txt {
                                            Layout.fillWidth: true
                                            text: root.inputSecret ? "Waiting for a secret" : "Waiting for input"
                                            color: Theme.accent
                                            font.bold: true
                                            font.pixelSize: Theme.fontSmall + 1
                                        }
                                    }

                                    Txt {
                                        Layout.fillWidth: true
                                        text: root.inputPrompt.length ? root.inputPrompt : "Input required"
                                        color: Theme.text
                                        font.family: "monospace"
                                        font.pixelSize: Theme.fontSmall + 1
                                        wrapMode: Text.Wrap
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: 34
                                        radius: Theme.radiusSmall
                                        color: Theme.bgSolid
                                        border.width: 1
                                        border.color: inputField.activeFocus ? Theme.accent : Theme.border

                                        Behavior on border.color {
                                            ColorAnimation {
                                                duration: Theme.animFast
                                            }
                                        }

                                        TextInput {
                                            id: inputField
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            verticalAlignment: TextInput.AlignVCenter
                                            clip: true
                                            echoMode: root.inputSecret ? TextInput.Password : TextInput.Normal
                                            passwordCharacter: "•"
                                            color: Theme.text
                                            selectionColor: Theme.accentSoft
                                            selectedTextColor: Theme.text
                                            font.family: Theme.font
                                            font.pixelSize: Theme.fontSize
                                            onAccepted: root.submitInput()
                                            Keys.onEscapePressed: {
                                                event.accepted = true
                                                root.cancelInput()
                                            }
                                        }

                                        Text {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            verticalAlignment: Text.AlignVCenter
                                            enabled: false
                                            visible: inputField.text.length === 0
                                            text: root.inputSecret ? "Password" : "Type your answer…"
                                            color: Theme.subtext
                                            font.family: Theme.font
                                            font.pixelSize: Theme.fontSize
                                            opacity: 0.7
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Txt {
                                            Layout.fillWidth: true
                                            text: root.inputSecret
                                                ? "Masked and never sent to the AI."
                                                : "Kept out of the model's context."
                                            color: Theme.subtext
                                            font.pixelSize: Theme.fontSmall - 1
                                            wrapMode: Text.Wrap
                                        }

                                        Rectangle {
                                            width: inputCancelLbl.implicitWidth + 22
                                            height: 28
                                            radius: 7
                                            color: inputCancelMa.containsMouse ? Theme.hover : "transparent"
                                            border.width: 1
                                            border.color: Theme.border

                                            Txt {
                                                id: inputCancelLbl
                                                anchors.centerIn: parent
                                                text: "Cancel"
                                                color: Theme.subtext
                                                font.pixelSize: Theme.fontSmall
                                            }
                                            MouseArea {
                                                id: inputCancelMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.cancelInput()
                                            }
                                        }

                                        Rectangle {
                                            width: inputSendLbl.implicitWidth + 24
                                            height: 28
                                            radius: 7
                                            color: inputSendMa.containsMouse ? Qt.lighter(Theme.accent, 1.12) : Theme.accent

                                            Txt {
                                                id: inputSendLbl
                                                anchors.centerIn: parent
                                                text: "Send"
                                                color: Theme.onAccent
                                                font.pixelSize: Theme.fontSmall
                                                font.bold: true
                                            }
                                            MouseArea {
                                                id: inputSendMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.submitInput()
                                            }
                                        }
                                    }
                                }
                            }

                            // ───────────── screenshot preview ─────────────
                            Rectangle {
                                visible: root.imagePath.length > 0 && !root.pending
                                Layout.fillWidth: true
                                Layout.preferredHeight: 248
                                radius: Theme.radiusSmall
                                color: Theme.bgSolid
                                border.width: 1
                                border.color: Theme.border
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    source: root.imagePath.length ? "file://" + root.imagePath : ""
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    cache: false
                                    smooth: true
                                }
                            }

                            // ───────────── approve / deny ─────────────
                            RowLayout {
                                visible: root.needsApproval
                                Layout.fillWidth: true
                                spacing: 8

                                Txt {
                                    Layout.fillWidth: true
                                    text: "Nothing runs until you choose."
                                    color: Theme.subtext
                                    font.pixelSize: Theme.fontSmall - 1
                                    elide: Text.ElideRight
                                }

                                Rectangle {
                                    width: denyLbl.implicitWidth + 22
                                    height: 28
                                    radius: 7
                                    color: denyMa.containsMouse ? Theme.hover : "transparent"
                                    border.width: 1
                                    border.color: Theme.border

                                    Txt {
                                        id: denyLbl
                                        anchors.centerIn: parent
                                        text: "Deny"
                                        color: Theme.subtext
                                        font.pixelSize: Theme.fontSmall
                                    }
                                    MouseArea {
                                        id: denyMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.toolDecision(root.callId, false)
                                    }
                                }

                                Rectangle {
                                    width: allowLbl.implicitWidth + 24
                                    height: 28
                                    radius: 7
                                    color: allowMa.containsMouse ? Qt.lighter(Theme.accent, 1.12) : Theme.accent

                                    Txt {
                                        id: allowLbl
                                        anchors.centerIn: parent
                                        text: "Approve"
                                        color: Theme.onAccent
                                        font.pixelSize: Theme.fontSmall
                                        font.bold: true
                                    }
                                    MouseArea {
                                        id: allowMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.toolDecision(root.callId, true)
                                    }
                                }
                            }

                            Rectangle {
                                visible: root.output.length > 0
                                Layout.fillWidth: true
                                Layout.preferredHeight: outTxt.contentHeight + 16
                                radius: Theme.radiusSmall
                                color: Theme.bgSolid
                                border.width: 1
                                border.color: root.pending ? Qt.alpha(Theme.accent, 0.32) : Theme.border

                                TextEdit {
                                    id: outTxt
                                    x: 8
                                    y: 8
                                    width: parent.width - 16
                                    height: contentHeight
                                    text: root.shownOutput
                                    textFormat: TextEdit.PlainText
                                    readOnly: true
                                    selectByMouse: true
                                    wrapMode: TextEdit.Wrap
                                    color: Theme.text
                                    selectionColor: Theme.accentSoft
                                    selectedTextColor: Theme.text
                                    font.family: "monospace"
                                    font.pixelSize: Theme.fontSmall + 1
                                    cursorVisible: false
                                }
                            }

                            Item {
                                visible: root.outLines.length > 12 && !root.pending
                                Layout.fillWidth: true
                                Layout.preferredHeight: 20

                                Txt {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.expanded ? "Show less" : "Show all " + root.outLines.length + " lines"
                                    color: Theme.accent
                                    font.pixelSize: Theme.fontSmall
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.expanded = !root.expanded
                                }
                            }
                        }
                    }

                    // ───────────── typing indicator ─────────────
                    RowLayout {
                        visible: root.pending && !root.isTool && root.content.length === 0
                        Layout.fillWidth: true
                        spacing: 5

                        Repeater {
                            model: 3

                            Rectangle {
                                required property int index
                                width: 6
                                height: 6
                                radius: 3
                                color: Theme.accent

                                SequentialAnimation on opacity {
                                    running: Theme.anim > 0 && root.pending
                                    loops: Animation.Infinite
                                    PauseAnimation {
                                        duration: index * 140
                                    }
                                    NumberAnimation {
                                        to: 0.25
                                        duration: 320
                                    }
                                    NumberAnimation {
                                        to: 1
                                        duration: 320
                                    }
                                    PauseAnimation {
                                        duration: 240
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    function truncate(text, max) {
        const s = String(text || "")
        if (s.length <= max)
            return s
        return s.slice(0, max) + "\n… (truncated)"
    }

    function submitInput() {
        const value = inputField.text
        // Clear the field before handing it over so it cannot linger in the
        // scene graph or a screenshot.
        inputField.text = ""
        root.inputSubmitted(root.callId, value, false)
    }

    function cancelInput() {
        inputField.text = ""
        root.inputSubmitted(root.callId, "", true)
    }

    function isShell(lang) {
        const l = (lang || "").toLowerCase()
        return l === "bash" || l === "sh" || l === "shell" || l === "zsh" || l === "console" || l === "fish" || l === ""
    }

    // ───────────── markdown ─────────────
    // Assistant prose is markdown. Qt's MarkdownText import renders it, but
    // leaves every block with zero margins, so paragraphs, headings and lists
    // run together. This converts the common subset to rich text we can space
    // and colour with the theme; fenced code never reaches here (it becomes a
    // code card or the approval panel).
    function escHtml(t) {
        return String(t).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;")
    }

    function inlineMd(t) {
        let s = escHtml(t)
        s = s.replace(/\[([^\]]+)\]\((https?:\/\/[^\s)"]+)\)/g, '<a href="$2">$1</a>')
        s = s.replace(/`([^`]+)`/g, '<span style="font-family:\'monospace\'; color:' + Theme.accent + ';">$1</span>')
        s = s.replace(/\*\*([^*]+)\*\*/g, "<b>$1</b>")
        s = s.replace(/__([^_]+)__/g, "<b>$1</b>")
        s = s.replace(/(^|[\s(])\*([^*\n]+)\*(?=[\s).,;:!?]|$)/g, "$1<i>$2</i>")
        s = s.replace(/(^|[\s(])_([^_\n]+)_(?=[\s).,;:!?]|$)/g, "$1<i>$2</i>")
        return s
    }

    function markdownToHtml(text) {
        const lines = String(text).replace(/\r\n/g, "\n").split("\n")
        const out = []
        let list = ""
        let para = []

        function flushPara() {
            if (!para.length)
                return
            out.push('<p style="margin:0 0 7px 0;">' + inlineMd(para.join(" ")) + "</p>")
            para = []
        }
        function closeList() {
            if (!list)
                return
            out.push("</" + list + ">")
            list = ""
        }

        for (let i = 0; i < lines.length; i++) {
            const raw = lines[i]
            const line = raw.replace(/\s+$/, "")
            let m

            if (!line.trim().length) {
                flushPara()
                // A blank line between items keeps the list open (markdown's
                // "loose" list). Closing it would restart ordered numbering at
                // 1 for the next item.
                if (list) {
                    let j = i + 1
                    while (j < lines.length && !lines[j].trim().length)
                        j++
                    const next = j < lines.length ? lines[j] : ""
                    const sameUl = list === "ul" && /^\s*[-*+]\s+/.test(next)
                    const sameOl = list === "ol" && /^\s*\d+[.)]\s+/.test(next)
                    if (!sameUl && !sameOl)
                        closeList()
                }
                continue
            }

            if ((m = line.match(/^(#{1,6})\s+(.*)$/))) {
                flushPara()
                closeList()
                const lvl = m[1].length
                const size = lvl === 1 ? Theme.fontSize + 7 : (lvl === 2 ? Theme.fontSize + 4 : Theme.fontSize + 1)
                out.push('<p style="margin:' + (lvl === 1 ? 1 : 6) + 'px 0 6px 0; font-size:' + size
                         + 'px; font-weight:bold;">' + inlineMd(m[2]) + "</p>")
                continue
            }

            if ((m = line.match(/^\s*[-*+]\s+(.*)$/))) {
                flushPara()
                if (list !== "ul") {
                    closeList()
                    out.push('<ul style="margin:0 0 7px 0; -qt-list-indent:1;">')
                    list = "ul"
                }
                out.push("<li>" + inlineMd(m[1]) + "</li>")
                continue
            }

            if ((m = line.match(/^\s*\d+[.)]\s+(.*)$/))) {
                flushPara()
                if (list !== "ol") {
                    closeList()
                    out.push('<ol style="margin:0 0 7px 0; -qt-list-indent:1;">')
                    list = "ol"
                }
                out.push("<li>" + inlineMd(m[1]) + "</li>")
                continue
            }

            if ((m = line.match(/^\s*>\s?(.*)$/))) {
                flushPara()
                closeList()
                out.push('<p style="margin:0 0 7px 0; color:' + Theme.subtext + ';">' + inlineMd(m[1]) + "</p>")
                continue
            }

            if (/^\s*([-*_])\1{2,}\s*$/.test(line)) {
                flushPara()
                closeList()
                continue
            }

            // An indented line while a list is open continues the last item;
            // anything else ends the list.
            if (list && /^\s{2,}/.test(raw)) {
                out[out.length - 1] = out[out.length - 1].replace(/<\/li>$/, " " + inlineMd(line.trim()) + "</li>")
                continue
            }
            closeList()
            para.push(line.trim())
        }

        flushPara()
        closeList()
        return out.join("")
    }

    function parseSegments(text) {
        const out = []
        if (!text || !text.length)
            return out
        const re = /```([^\n`]*)\n([\s\S]*?)(```|$)/g
        let last = 0
        let m
        while ((m = re.exec(text)) !== null) {
            if (m.index > last)
                out.push({
                    kind: "text",
                    lang: "",
                    body: text.slice(last, m.index)
                })
            out.push({
                kind: "code",
                lang: (m[1] || "").trim(),
                body: m[2]
            })
            last = re.lastIndex
            if (m[3] === "")
                break
        }
        if (last < text.length)
            out.push({
                kind: "text",
                lang: "",
                body: text.slice(last)
            })
        return out
    }

    function copyText(text) {
        const quoted = "'" + String(text).replace(/'/g, "'\\''") + "'"
        Quickshell.execDetached(["sh", "-c", "printf '%s' " + quoted + " | wl-copy"])
    }
}
