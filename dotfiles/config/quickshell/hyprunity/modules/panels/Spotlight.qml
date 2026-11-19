import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components
import "Search.js" as Search

// Spotlight — ALT + SPACE.
//
// One box that answers in the order a search should:
//
//   1. quick maths      12*8          -> = 96        (Enter copies)
//   2. applications     fire          -> Firefox
//   3. shell actions    lock, record  -> Lock session
//   4. files            report        -> ~/Documents/report.pdf
//   5. the web          rust async    -> DuckDuckGo in Zen
//
// The web row is always last, so pressing Enter on a real match never
// surprises you with a browser tab. Files come from a debounced find(1) over
// the usual home folders; the wallpaper folder is skipped on purpose.
Rectangle {
    id: root

    property int maxHeight: 800

    property string query: ""
    property int selected: 0
    property var fileHits: []
    property bool pendingSearch: false
    property string searchQuery: ""

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string browser: String(Config.apps.browser || "").trim()
    readonly property string browserBin: browser.split(/\s+/)[0]
    // Checked once so a machine without the configured browser still gets a
    // working web row through xdg-open instead of a dead keypress.
    property bool browserAvailable: false
    readonly property string browserName: (browser !== "" && browserAvailable) ? Search.browserLabel(browser) : "your browser"

    function checkBrowser() {
        browserAvailable = false;
        if (browserBin !== "")
            browserCheck.running = true;
    }

    Component.onCompleted: checkBrowser()
    onBrowserBinChanged: checkBrowser()

    readonly property var allApps: {
        const out = [];
        for (const app of DesktopEntries.applications.values) {
            if (!app.noDisplay)
                out.push(app);
        }
        out.sort((a, b) => String(a.name).localeCompare(String(b.name)));
        return out;
    }

    // ───────────── shell actions ─────────────
    readonly property var actionDefs: [
        {
            id: "lock",
            label: "Lock session",
            hint: "Lock the screen now",
            keys: "lock screen session",
            glyph: Icons.lock
        },
        {
            id: "settings",
            label: "Open Settings",
            hint: "Appearance, bar, Hyprland",
            keys: "settings preferences config",
            glyph: Icons.cog
        },
        {
            id: "control",
            label: "Control centre",
            hint: "Volume, Wi-Fi, Bluetooth, power",
            keys: "control centre center panel power",
            glyph: Icons.sliders
        },
        {
            id: "wallpaper",
            label: "Change wallpaper",
            hint: "Pick an image",
            keys: "wallpaper background image",
            glyph: Icons.image
        },
        {
            id: "keybinds",
            label: "Keybind cheatsheet",
            hint: "Every shortcut in the shell",
            keys: "keybinds shortcuts keys cheatsheet",
            glyph: Icons.keyboard
        },
        {
            id: "clipboard",
            label: "Clipboard history",
            hint: "Everything you copied",
            keys: "clipboard history copy paste",
            glyph: Icons.clipboard
        },
        {
            id: "agent",
            label: "Open UnityAgent",
            hint: "Approval-first assistant",
            keys: "agent ai chat unityagent assistant",
            glyph: Icons.star
        },
        {
            id: "screenshot",
            label: "Take a screenshot",
            hint: "Select an area",
            keys: "screenshot capture screen shot",
            glyph: Icons.camera
        },
        {
            id: "record",
            label: "Record the screen",
            hint: "Start a full-screen recording",
            keys: "record capture video screen",
            glyph: Icons.record
        },
        {
            id: "nightlight",
            label: "Toggle night light",
            hint: "Warmer colours",
            keys: "night light warm blue filter",
            glyph: Icons.moon
        },
        {
            id: "caffeine",
            label: "Toggle caffeine",
            hint: "Keep the session awake",
            keys: "caffeine awake idle inhibit",
            glyph: Icons.coffee
        },
        {
            id: "gamemode",
            label: "Toggle game mode",
            hint: "Quieter, faster session",
            keys: "game mode performance",
            glyph: Icons.gamepad
        },
        {
            id: "suspend",
            label: "Suspend",
            hint: "Sleep the machine",
            keys: "suspend sleep",
            glyph: Icons.moon
        },
        {
            id: "logout",
            label: "Log out",
            hint: "End the Hyprland session",
            keys: "logout log out sign exit",
            glyph: Icons.signOut
        },
        {
            id: "reboot",
            label: "Reboot",
            hint: "Restart the machine",
            keys: "reboot restart",
            glyph: Icons.refresh
        },
        {
            id: "shutdown",
            label: "Shut down",
            hint: "Power the machine off",
            keys: "shutdown shut down power off",
            glyph: Icons.power
        }
    ]

    // ───────────── the result list ─────────────
    readonly property var results: {
        const q = query.trim().toLowerCase();
        const out = [];

        if (q === "") {
            for (const app of allApps)
                out.push(appResult(app));
            return out;
        }

        // 1. maths
        const m = Search.evaluate(query);
        if (m)
            out.push({
                kind: "math",
                title: "= " + m.text,
                hint: "Quick maths — Enter copies the result",
                badge: "MATH",
                glyph: Icons.balance,
                copy: m.text
            });

        // 2. applications
        const apps = [];
        for (const app of allApps) {
            const s = Search.scoreApp(app, q);
            if (s > 0)
                apps.push({
                    app: app,
                    score: s
                });
        }
        apps.sort((a, b) => (b.score - a.score) || String(a.app.name).localeCompare(String(b.app.name)));
        for (const hit of apps.slice(0, 6))
            out.push(appResult(hit.app));

        // 3. shell actions
        const acts = [];
        for (const a of actionDefs) {
            const s = actionScore(a, q);
            if (s > 0)
                acts.push({
                    def: a,
                    score: s
                });
        }
        acts.sort((a, b) => (b.score - a.score) || a.def.label.localeCompare(b.def.label));
        for (const hit of acts.slice(0, 4))
            out.push({
                kind: "action",
                title: hit.def.label,
                hint: hit.def.hint,
                badge: "ACTION",
                glyph: hit.def.glyph,
                action: hit.def.id
            });

        // 4. files (asynchronous; empty until the find finishes)
        for (const f of fileHits)
            out.push({
                kind: "file",
                title: f.name,
                hint: Search.parentDir(f.path, home),
                badge: "FILE",
                glyph: Icons.file,
                path: f.path
            });

        // 5. the web — always last
        if (Search.looksLikeUrl(query)) {
            out.push({
                kind: "url",
                title: "Open " + query.trim(),
                hint: "In " + browserName,
                badge: "WEB",
                glyph: Icons.globe,
                url: Search.webUrl(query)
            });
        } else {
            out.push({
                kind: "web",
                title: "Search the web for “" + query.trim() + "”",
                hint: "DuckDuckGo · " + browserName,
                badge: "WEB",
                glyph: Icons.search,
                url: Search.webUrl(query)
            });
        }
        return out;
    }

    function appResult(app) {
        return {
            kind: "app",
            title: String(app.name),
            hint: String(app.comment || ""),
            badge: "",
            app: app
        };
    }

    function actionScore(a, q) {
        const label = a.label.toLowerCase();
        const keys = a.keys.toLowerCase();
        if (label === q)
            return 100;
        if (label.startsWith(q))
            return 90;
        if (label.includes(q))
            return 70;
        if (keys.startsWith(q))
            return 55;
        if (keys.includes(q))
            return 30;
        return 0;
    }

    readonly property int visibleRows: Math.max(1, Math.min(results.length, 8))

    onResultsChanged: if (selected >= results.length)
        selected = Math.max(0, results.length - 1)

    // ───────────── file search ─────────────
    onQueryChanged: {
        selected = 0;
        fileHits = [];
        if (query.trim().length < 2) {
            findTimer.stop();
            return;
        }
        findTimer.restart();
    }

    function startFileSearch() {
        const q = query.trim();
        if (q.length < 2) {
            fileHits = [];
            return;
        }
        if (findProc.running) {
            pendingSearch = true;
            return;
        }
        pendingSearch = false;
        searchQuery = q.toLowerCase();
        findProc.command = ["sh", "-c", Search.fileSearchScript(q, home)];
        findProc.running = true;
    }

    function applyFileHits(text) {
        // The query may have moved on while find was running.
        if (searchQuery !== query.trim().toLowerCase())
            return;

        const q = searchQuery;
        const seen = ({});
        const hits = [];
        for (const line of String(text).split("\n")) {
            if (!line || seen[line])
                continue;
            seen[line] = true;
            const name = Search.baseName(line);
            if (!name)
                continue;
            const lower = name.toLowerCase();
            let score = 1;
            if (lower === q)
                score = 4;
            else if (lower.startsWith(q))
                score = 3;
            else if (lower.includes(q))
                score = 2;
            hits.push({
                path: line,
                name: name,
                score: score
            });
        }
        hits.sort((a, b) => (b.score - a.score) || (a.path.length - b.path.length) || a.name.localeCompare(b.name));
        fileHits = hits.slice(0, 6);
    }

    Process {
        id: browserCheck
        command: ["sh", "-c", "command -v " + Search.shellQuote(root.browserBin) + " >/dev/null 2>&1"]
        onExited: (code, status) => root.browserAvailable = (code === 0)
    }

    Timer {
        id: findTimer
        interval: 180
        onTriggered: root.startFileSearch()
    }

    Process {
        id: findProc

        stdout: StdioCollector {
            onStreamFinished: root.applyFileHits(text)
        }

        onRunningChanged: if (!running && root.pendingSearch)
            root.startFileSearch()
    }

    // ───────────── activation ─────────────
    function activate(r) {
        if (!r)
            return;
        Panels.close();

        if (r.kind === "app") {
            launchApp(r.app);
        } else if (r.kind === "file") {
            Quickshell.execDetached(["xdg-open", r.path]);
        } else if (r.kind === "web" || r.kind === "url") {
            openUrl(r.url);
        } else if (r.kind === "math") {
            Quickshell.execDetached(["sh", "-c", "printf %s " + Search.shellQuote(r.copy) + " | wl-copy"]);
        } else if (r.kind === "action") {
            runAction(r.action);
        }
    }

    function launchApp(app) {
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

    function openUrl(url) {
        if (browser !== "" && browserAvailable)
            Quickshell.execDetached(["sh", "-c", browser + " " + Search.shellQuote(url)]);
        else
            Quickshell.execDetached(["xdg-open", url]);
    }

    function runAction(id) {
        if (id === "lock")
            Actions.lock();
        else if (id === "settings")
            Panels.openSettings();
        else if (id === "control")
            Panels.toggle("control");
        else if (id === "wallpaper")
            Panels.toggle("wallpaper");
        else if (id === "keybinds")
            Panels.toggle("keybinds");
        else if (id === "clipboard")
            Panels.toggle("clipboard");
        else if (id === "agent")
            UnityAgent.toggle();
        else if (id === "screenshot")
            Actions.screenshot();
        else if (id === "record")
            Recorder.startFull();
        else if (id === "nightlight")
            Actions.nightLight = !Actions.nightLight;
        else if (id === "caffeine")
            Actions.caffeine = !Actions.caffeine;
        else if (id === "gamemode")
            Actions.gameMode = !Actions.gameMode;
        else if (id === "suspend")
            Actions.suspend();
        else if (id === "logout")
            Actions.logout();
        else if (id === "reboot")
            Actions.reboot();
        else if (id === "shutdown")
            Actions.shutdown();
    }

    function move(delta) {
        if (results.length === 0)
            return;
        selected = Math.max(0, Math.min(results.length - 1, selected + delta));
    }

    // ───────────── surface ─────────────
    implicitWidth: 660
    implicitHeight: Math.min(maxHeight, col.implicitHeight + 28)

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Theme.anim
            easing.type: Easing.OutCubic
        }
    }

    radius: Theme.radius + 2
    color: Theme.bg
    border.width: 1
    border.color: Qt.alpha(Theme.accent, 0.35)
    clip: true

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
            implicitHeight: 46
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
                    leftMargin: 13
                    rightMargin: 13
                }
                spacing: 10

                Glyph {
                    text: Icons.search
                    color: Theme.accent
                    font.pixelSize: Theme.fontSize + 3
                }

                TextInput {
                    id: field

                    Layout.fillWidth: true
                    focus: true
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize + 2
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.onAccent
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true

                    onTextChanged: {
                        root.query = text;
                        root.selected = 0;
                    }
                    onAccepted: root.activate(root.results[root.selected])

                    Keys.onUpPressed: root.move(-1)
                    Keys.onDownPressed: root.move(1)
                    Keys.onEscapePressed: Panels.close()

                    Component.onCompleted: forceActiveFocus()

                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: field.text.length === 0
                        text: "Search apps, files, maths or the web…"
                        color: Theme.subtext
                    }
                }

                Txt {
                    visible: field.text.length > 0
                    text: "ALT + SPACE"
                    color: Theme.subtext
                    font.pixelSize: Theme.fontSmall - 1
                    font.letterSpacing: 0.5
                }
            }
        }

        // ── results ─────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.visibleRows * 52

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
                    readonly property string iconSource: modelData.kind === "app" ? Icons.src(modelData.app.icon) : ""

                    width: list.width
                    height: 52
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
                        onClicked: root.activate(row.modelData)
                    }

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 10
                            rightMargin: 12
                        }
                        spacing: 10

                        Item {
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 26

                            IconImage {
                                anchors.centerIn: parent
                                width: 26
                                height: 26
                                visible: row.iconSource !== ""
                                source: row.iconSource
                                implicitSize: 26
                            }

                            Glyph {
                                anchors.centerIn: parent
                                visible: row.iconSource === ""
                                text: row.modelData.glyph || Icons.apps
                                color: row.current ? Theme.accent : Theme.subtext
                                font.pixelSize: Theme.fontSize + 2
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Txt {
                                Layout.fillWidth: true
                                text: row.modelData.title
                                color: row.modelData.kind === "math" ? Theme.accent : Theme.text
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            Txt {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: row.modelData.hint || ""
                                color: Theme.subtext
                                font.pixelSize: Theme.fontSmall
                                elide: Text.ElideRight
                            }
                        }

                        Txt {
                            visible: text !== ""
                            text: row.modelData.badge || ""
                            color: Theme.subtext
                            font.pixelSize: Theme.fontSmall - 1
                            font.letterSpacing: 1
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width - 40
                spacing: 4
                visible: root.results.length === 0

                Txt {
                    Layout.fillWidth: true
                    text: "Nothing matched"
                    color: Theme.text
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }
                Txt {
                    Layout.fillWidth: true
                    text: "Try maths like 12*8, an app name, or a file in your home folders."
                    color: Theme.subtext
                    font.pixelSize: Theme.fontSmall
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                }
            }
        }

        // ── footer ──────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Txt {
                Layout.fillWidth: true
                text: root.results.length + (root.results.length === 1 ? " result" : " results") + " · ↑↓ to move · Enter to run"
                color: Theme.subtext
                font.pixelSize: Theme.fontSmall
                elide: Text.ElideRight
            }

            Txt {
                text: "Esc to close"
                color: Theme.subtext
                font.pixelSize: Theme.fontSmall
            }
        }
    }
}
