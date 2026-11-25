pragma Singleton
import QtQuick
import qs.config

QtObject {
    id: root

    readonly property var items: [
        {
            id: "launcher",
            label: "Launcher",
            glyph: "\uf009",
            flag: "showLauncher",
            section: "left"
        },
        {
            id: "workspaces",
            label: "Workspaces",
            glyph: "\uf009",
            flag: "showWorkspaces",
            section: "left"
        },
        {
            id: "windowTitle",
            label: "Window title",
            glyph: "\uf03e",
            flag: "showWindowTitle",
            section: "left"
        },
        {
            id: "media",
            label: "Media",
            glyph: "\uf001",
            flag: "showMedia",
            section: "right"
        },
        {
            id: "tray",
            label: "System tray",
            glyph: "\uf0c9",
            flag: "showTray",
            section: "right"
        },
        {
            id: "stats",
            label: "CPU / RAM",
            glyph: "\uf2db",
            flag: "showStats",
            section: "right"
        },
        {
            id: "status",
            label: "Status cluster",
            glyph: "\uf012",
            flag: "showStatus",
            section: "right"
        },
        {
            id: "recording",
            label: "Screen recording",
            glyph: "\uf03d",
            flag: "showRecording",
            section: "right"
        },
        {
            id: "notifications",
            label: "Notifications",
            glyph: "\uf0f3",
            flag: "showNotifications",
            section: "right"
        },
        {
            id: "clock",
            label: "Clock",
            glyph: "\uf017",
            flag: "",
            section: "center"
        }
    ]

    function itemById(id) {
        for (let i = 0; i < items.length; i++) {
            if (items[i].id === id)
                return items[i];
        }
        return null;
    }

    function splitOrder(s) {
        if (!s || typeof s !== "string")
            return [];
        return s.split(",").map(x => x.trim()).filter(x => x.length > 0);
    }

    function joinOrder(arr) {
        return arr.join(",");
    }

    function sectionOf(itemId) {
        const it = itemById(itemId);
        return it ? it.section : "";
    }

    // The items that belong to a side, in their declared order. A side is fixed:
    // the bar builds the left and right rows from hard-coded per-id components,
    // so an id that travelled to the other side would just vanish from the bar.
    function sectionItems(section) {
        const out = [];
        for (let i = 0; i < items.length; i++) {
            if (items[i].section === section)
                out.push(items[i].id);
        }
        return out;
    }

    // A section's list is always *exactly* its own items: the stored string
    // only supplies the order. Ids from another side are ignored, and ids the
    // string forgot (a fresh key, or one dragged across sides back when that
    // was allowed) fall back to their declared slot — so nothing can go missing.
    function normalise(orderStr, section) {
        const owned = sectionItems(section);
        const out = [];
        if (typeof orderStr === "string") {
            const parts = splitOrder(orderStr);
            for (let i = 0; i < parts.length; i++) {
                const id = parts[i];
                if (owned.indexOf(id) >= 0 && out.indexOf(id) < 0)
                    out.push(id);
            }
        }
        for (let i = 0; i < owned.length; i++) {
            if (out.indexOf(owned[i]) < 0)
                out.push(owned[i]);
        }
        return out;
    }

    function leftOrderList() {
        return normalise(Config.bar.leftOrder, "left");
    }

    function rightOrderList() {
        return normalise(Config.bar.rightOrder, "right");
    }

    function centerOrderList() {
        return normalise(Config.bar.centerOrder, "center");
    }

    function listFor(section) {
        if (section === "left")
            return leftOrderList();
        if (section === "right")
            return rightOrderList();
        if (section === "center")
            return centerOrderList();
        return [];
    }

    function writeList(section, arr) {
        const s = joinOrder(arr);
        if (section === "left")
            Config.bar.leftOrder = s;
        if (section === "right")
            Config.bar.rightOrder = s;
        if (section === "center")
            Config.bar.centerOrder = s;
    }

    // Reorder an item inside its own side. There is deliberately no
    // cross-section form of this: the side is part of the item's identity, and
    // moving it to another strip would drop it out of the bar altogether.
    function moveItem(itemId, toIndex) {
        const section = sectionOf(itemId);
        if (section === "")
            return;
        const arr = listFor(section);
        const i = arr.indexOf(itemId);
        if (i < 0)
            return;
        arr.splice(i, 1);
        let idx = toIndex;
        if (idx < 0)
            idx = 0;
        if (idx > arr.length)
            idx = arr.length;
        if (idx === i)
            return; // dropped where it came from — nothing to write
        arr.splice(idx, 0, itemId);
        writeList(section, arr);
    }

    // ── drag state shared by the three arrange strips ──────────────────
    //
    // Qt's own drag delivery (Drag attached type + DropArea) never reaches the
    // drop areas on this Qt build, so the gesture is tracked by hand instead:
    // the pressed chip publishes the cursor position in scene coordinates, and
    // every strip asks whether that point falls inside it. Only the item's own
    // strip may claim the drop — a side is fixed, so dragging a chip onto
    // another strip is simply refused (the ghost dims as the cue) — and the
    // release then applies the move on the next event-loop turn.
    property bool dragging: false
    property string dragId: ""
    property string dragSection: ""  // the fixed side the dragged item lives on
    property point dragScene: Qt.point(0, 0)
    property string dropSection: ""
    property int dropIndex: -1
    property var strips: []          // the registered BarArrange strips

    function registerStrip(strip) {
        if (strips.indexOf(strip) < 0)
            strips.push(strip);
    }

    function unregisterStrip(strip) {
        const i = strips.indexOf(strip);
        if (i >= 0)
            strips.splice(i, 1);
    }

    function beginDrag(itemId) {
        dragging = true;
        dragId = itemId;
        dragSection = sectionOf(itemId);
        dropSection = "";
        dropIndex = -1;
    }

    // Re-evaluate the drop target: the item's own strip claims it if the cursor
    // is inside. Other strips never do, whatever the pointer does.
    function updateHover() {
        if (!dragging)
            return;
        dropSection = "";
        dropIndex = -1;
        for (let i = 0; i < strips.length; i++) {
            const s = strips[i];
            if (!s)
                continue;
            if (s.section !== dragSection) {
                s.highlight = false;
                continue;
            }
            if (s.containsScenePoint(dragScene.x, dragScene.y)) {
                dropSection = s.section;
                dropIndex = s.insertIndexAt();
                s.highlight = true;
            } else {
                s.highlight = false;
            }
        }
    }

    function endDrag() {
        dragging = false; // every strip listens and drops its ghost
    }

    // Apply the recorded drop. The values are read before the state is reset,
    // and the reorder itself is deferred: it rebuilds the delegates that the
    // finished gesture is still holding. A drop outside the item's own strip
    // (dropSection left empty by updateHover) is silently discarded.
    function finishDrag() {
        const id = dragId;
        const idx = dropIndex;
        const accepted = dropSection !== "";
        resetDrag();
        if (id === "" || !accepted)
            return;
        Qt.callLater(() => moveItem(id, idx));
    }

    function resetDrag() {
        dragging = false;
        dragId = "";
        dragSection = "";
        dropSection = "";
        dropIndex = -1;
    }
}
