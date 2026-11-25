import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components

// Application launcher — the built-in replacement for fuzzel / rofi.
//
//   type to filter · Up/Down to pick · Enter to launch · Esc to close
//
// The list comes from Quickshell's DesktopEntries, so it is the same set of
// apps a menu would show (entries flagged NoDisplay are hidden). The panel is
// re-created every time it opens, so the query always starts empty.
Rectangle {
    id: root

    property int maxHeight: 800

    readonly property var allApps: {
        const out = [];
        for (const app of DesktopEntries.applications.values) {
            if (!app.noDisplay)
                out.push(app);
        }
        out.sort((a, b) => String(a.name).localeCompare(String(b.name)));
        return out;
    }

    property string query: ""
    property int selected: 0

    /// Apps matching `query`, best match first. Empty query = everything.
    readonly property var results: {
        const q = query.trim().toLowerCase();
        if (q === "")
            return allApps;

        const hits = [];
        for (const app of allApps) {
            const s = score(app, q);
            if (s > 0)
                hits.push({
                    app: app,
                    score: s
                });
        }
        hits.sort((a, b) => (b.score - a.score) || String(a.app.name).localeCompare(String(b.app.name)));
        return hits.map(h => h.app);
    }

    /// Higher is better; 0 means "no match".
    function score(app, q) {
        const name = String(app.name).toLowerCase();
        const generic = String(app.genericName).toLowerCase();
        const comment = String(app.comment).toLowerCase();
        const keywords = keywordsOf(app);

        if (name === q)
            return 100;
        if (name.startsWith(q))
            return 90;
        if (name.includes(q))
            return 70;
        if (generic.startsWith(q))
            return 60;
        if (generic.includes(q))
            return 45;
        if (keywords.includes(q))
            return 35;
        if (comment.includes(q))
            return 20;
        return 0;
    }

    function keywordsOf(app) {
        const k = app.keywords;
        if (!k)
            return "";
        return Array.isArray(k) ? k.join(" ").toLowerCase() : String(k).toLowerCase();
    }

    function move(delta) {
        if (results.length === 0)
            return;
        selected = Math.max(0, Math.min(results.length - 1, selected + delta));
    }

    function launch(app) {
        if (!app)
            return;
        Panels.close();

        // DesktopEntry.execute() ignores Terminal=true, so honour it here.
        const term = String(Config.apps.terminal || "").trim();
        if (app.runInTerminal && term !== "") {
            const cmd = ["sh", "-c", term + ' -e "$@"', "sh"].concat(Array.from(app.command || []));
            if (app.workingDirectory && app.workingDirectory !== "")
                Quickshell.execDetached({
                    command: cmd,
                    workingDirectory: app.workingDirectory
                });
            else
                Quickshell.execDetached(cmd);
        } else {
            app.execute();
        }
    }

    readonly property int visibleRows: Math.max(1, Math.min(results.length, 7))

    implicitWidth: 520
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

    ColumnLayout {
        id: col
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 14
        }
        spacing: 10

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
                    onAccepted: root.launch(root.results[root.selected])

                    Keys.onUpPressed: root.move(-1)
                    Keys.onDownPressed: root.move(1)
                    Keys.onEscapePressed: Panels.close()

                    Component.onCompleted: forceActiveFocus()

                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: field.text.length === 0
                        text: "Search applications…"
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
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

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
                        onClicked: root.launch(row.modelData)
                    }

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 10
                            rightMargin: 10
                        }
                        spacing: 10

                        Item {
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 26

                            IconImage {
                                anchors.centerIn: parent
                                width: 26
                                height: 26
                                visible: source != ""
                                // Icons.src returns "" for names the theme does
                                // not have, instead of a checkerboard placeholder.
                                source: Icons.src(row.modelData.icon)
                                implicitSize: 26
                            }

                            Glyph {
                                anchors.centerIn: parent
                                visible: row.modelData.icon === ""
                                text: Icons.apps
                                color: Theme.subtext
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Txt {
                                text: row.modelData.name
                                font.bold: index === root.selected
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Txt {
                                visible: text !== ""
                                text: row.modelData.comment
                                color: Theme.subtext
                                font.pixelSize: Theme.fontSmall
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }

            Txt {
                anchors.centerIn: parent
                visible: root.results.length === 0
                text: "No applications found"
                color: Theme.subtext
            }
        }

        // ── footer ──────────────────────────────────────────────────────
        Txt {
            Layout.fillWidth: true
            text: root.results.length + (root.results.length === 1 ? " app" : " apps") + " · Enter to launch · Esc to close"
            color: Theme.subtext
            font.pixelSize: Theme.fontSmall
            elide: Text.ElideRight
        }
    }
}
