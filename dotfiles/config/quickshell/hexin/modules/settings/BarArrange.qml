import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// One arrange strip (left / center / right) in Settings > Bar.
//
// Chips are laid out by the RowLayout; the chip itself never moves, because
// the layout owns its position. While dragging, a ghost copy follows the
// cursor above the other strips, and whichever strip the cursor is over
// records where the item should land (BarItems.dropSection / dropIndex)
// before the release tears the source chip down.
Item {
    id: root

    property string section: "left"
    readonly property string heading: section === "left" ? "Left side" : (section === "center" ? "Center" : "Right side")
    readonly property var list: {
        if (section === "left")
            return BarItems.leftOrderList();
        if (section === "right")
            return BarItems.rightOrderList();
        if (section === "center")
            return BarItems.centerOrderList();
        return [];
    }

    property bool dragging: false       // a drag that started in *this* strip
    property bool highlight: false      // a foreign drag is over this strip
    property var dragSource: null       // the chip being dragged out of here
    property var ghost: null
    property real grabX: 0
    property real grabY: 0

    implicitHeight: header.implicitHeight + 6 + 44
    z: root.dragging ? 20 : 0           // keep the ghost above the sibling strips

    Component.onCompleted: BarItems.registerStrip(root)
    Component.onDestruction: {
        BarItems.unregisterStrip(root);
        // The strip going away mid-drag (page rebuilt, window closed) must not
        // leave the shared drag state hanging.
        if (BarItems.dragging)
            BarItems.resetDrag();
    }

    // ── drag lifecycle ────────────────────────────────────────────────
    function beginDrag(chip) {
        dragging = true;
        dragSource = chip;
        makeGhost(chip);
        moveGhost();
    }

    function makeGhost(chip) {
        if (ghost)
            ghost.destroy();
        ghost = ghostComp.createObject(root, {
            width: chip.width,
            height: chip.height,
            gtext: chip.item ? chip.item.glyph : "",
            ltext: chip.item ? chip.item.label : ""
        });
        if (!ghost)
            return;
        const tl = chip.mapToItem(root, 0, 0);
        // Qt 6.12: mapFromScene not Q_INVOKABLE; mapFromItem(null,...) maps scene->item
        const cs = root.mapFromItem(null, BarItems.dragScene.x, BarItems.dragScene.y);
        grabX = cs.x - tl.x;
        grabY = cs.y - tl.y;
        moveGhost();
    }

    function moveGhost() {
        if (!ghost)
            return;
        const cs = root.mapFromItem(null, BarItems.dragScene.x, BarItems.dragScene.y);
        ghost.x = cs.x - grabX;
        ghost.y = cs.y - grabY;
        // A side is fixed, so the ghost fades while it is over a strip that
        // cannot take it — the drop will be refused when you let go.
        ghost.opacity = BarItems.dropSection === BarItems.dragSection ? 0.95 : 0.35;
    }

    // Purely visual teardown — the drop target values on BarItems survive it.
    function cleanup() {
        dragging = false;
        dragSource = null;
        highlight = false;
        if (ghost) {
            ghost.destroy();
            ghost = null;
        }
    }

    // Is the cursor (in scene coordinates) inside this strip's box?
    function containsScenePoint(sceneX, sceneY) {
        const p = strip.mapFromItem(null, sceneX, sceneY);
        return p.x >= 0 && p.x <= strip.width && p.y >= 0 && p.y <= strip.height;
    }

    // Insertion index for a drop here, in strip coordinates. The chip being
    // dragged is skipped, so the result is the index it takes *after* it is
    // pulled out of this list (which is exactly what moveItem() expects).
    function insertIndexAt() {
        const p = row.mapFromItem(null, BarItems.dragScene.x, BarItems.dragScene.y);
        const kids = row.children;
        let idx = 0;
        for (let i = 0; i < kids.length; i++) {
            const k = kids[i];
            if (!k || !k.item)
                continue;
            if (root.dragSource === k)
                continue;
            if (p.x >= k.x + k.width / 2)
                idx++;
        }
        return idx;
    }

    Connections {
        target: BarItems
        function onDraggingChanged() {
            if (!BarItems.dragging)
                root.cleanup();
        }
    }

    RowLayout {
        id: header
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        spacing: 8

        Txt {
            text: root.heading
            font.bold: true
        }
        Txt {
            text: root.section === "center" ? "always centred" : "drag to reorder · click the eye to hide"
            color: Theme.subtext
            font.pixelSize: Theme.fontSmall
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }

    Rectangle {
        id: strip
        anchors {
            top: header.bottom
            topMargin: 6
            left: parent.left
            right: parent.right
        }
        height: 44
        radius: Theme.radiusSmall
        color: Theme.card
        border.width: 1
        border.color: root.highlight || root.dragging ? Theme.accent : Theme.border

        Behavior on border.color {
            ColorAnimation {
                duration: Theme.animFast
            }
        }

        Flickable {
            anchors.fill: parent
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentWidth: row.implicitWidth + 12
            contentHeight: row.implicitHeight
            interactive: contentWidth > width
            flickableDirection: Flickable.HorizontalFlick

            RowLayout {
                id: row
                x: 6
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Repeater {
                    model: root.list

                    delegate: BarChip {
                        id: chip
                        required property var modelData
                        item: BarItems.itemById(modelData)
                        section: root.section
                        onDragStart: root.beginDrag(chip)
                        onDragMove: root.moveGhost()
                        onDragEnd: {}
                        onToggleHidden: {
                            const it = BarItems.itemById(modelData);
                            if (it && it.flag)
                                Config.bar[it.flag] = !Config.bar[it.flag];
                        }
                    }
                }
            }
        }
    }

    // ── ghost ─────────────────────────────────────────────────────────
    // The ghost copy is parented to this strip's root (see makeGhost) so it can
    // follow the cursor over the other strips without being clipped by them.
    Component {
        id: ghostComp
        Rectangle {
            property string gtext: ""
            property string ltext: ""
            // Above the strip it is dragged over, and above the sibling strips
            // (root.z is raised while dragging).
            z: 1000
            radius: Theme.radiusSmall
            color: Theme.surfaceHi
            border.width: 1
            border.color: Theme.accent
            opacity: 0.95

            RowLayout {
                anchors.centerIn: parent
                spacing: 6

                Glyph {
                    text: gtext
                    font.pixelSize: Theme.fontSmall + 2
                }
                Txt {
                    text: ltext
                    font.pixelSize: Theme.fontSmall
                }
            }
        }
    }
}
