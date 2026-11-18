import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// One draggable item in a Bar arrange strip.
//
// The chip itself never moves: the layout owns its position. Instead a ghost
// copy (made by BarArrange) follows the cursor, so reordering can't fight the
// RowLayout and the strip keeps its shape while you drag.
Rectangle {
    id: root

    property var item
    property string section: ""
    property bool dragging: false
    readonly property bool hidden: item && item.flag && Config.bar[item.flag] === false

    signal dragStart
    signal dragMove
    signal dragEnd
    signal toggleHidden

    radius: Theme.radiusSmall
    implicitWidth: content.implicitWidth + 12
    implicitHeight: 34
    color: dragging ? "transparent" : (ma.pressed ? Theme.pressed : (ma.containsMouse ? Theme.hover : Theme.card))
    border.width: 1
    border.color: dragging ? "transparent" : Theme.border
    opacity: dragging ? 0.3 : (hidden ? 0.55 : 1.0)

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.animFast
        }
    }
    Behavior on color {
        ColorAnimation {
            duration: Theme.animFast
        }
    }

    // Declared first so it sits *under* the content: the eye button keeps its
    // own mouse area on top (clicking it toggles instead of starting a drag).
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true   // page/strip Flickables must not grab the gesture
        property bool held: false
        cursorShape: held ? Qt.ClosedHandCursor : Qt.PointingHandCursor

        onPressed: mouse => {
            held = true;
            root.dragging = true;
            root.pushScene(mouse);
            BarItems.beginDrag(root.item ? root.item.id : "");
            BarItems.updateHover();
            root.dragStart();
        }
        onPositionChanged: mouse => {
            if (!held)
                return;
            root.pushScene(mouse);
            BarItems.updateHover();
            root.dragMove();
        }
        onReleased: mouse => {
            if (!held)
                return;
            held = false;
            root.dragging = false;
            root.pushScene(mouse);
            BarItems.updateHover();
            BarItems.finishDrag();
            root.dragEnd();
        }
        onCanceled: {
            held = false;
            root.dragging = false;
            BarItems.resetDrag();
            root.dragEnd();
        }
    }

    RowLayout {
        id: content
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            margins: 6
        }
        spacing: 6

        Glyph {
            text: root.item ? root.item.glyph : ""
            font.pixelSize: Theme.fontSmall + 2
        }
        Txt {
            text: root.item ? root.item.label : ""
            font.pixelSize: Theme.fontSmall
            elide: Text.ElideRight
        }
        Item {
            Layout.fillWidth: true
        }
        IconButton {
            visible: root.item && root.item.flag !== ""
            size: 22
            glyphSize: Theme.fontSmall
            glyph: root.hidden ? Icons.eyeSlash : Icons.eye
            onClicked: root.toggleHidden()
        }
    }

    function pushScene(mouse) {
        // Qt 6.12: mapToScene not Q_INVOKABLE; mapToItem(null,...) gives scene coords
        const p = root.mapToItem(null, mouse.x, mouse.y);
        BarItems.dragScene = Qt.point(p.x, p.y);
    }
}
