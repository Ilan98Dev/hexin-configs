import QtQuick
import Quickshell
import qs.config

MouseArea {
    id: root

    property var item
    property var barWindow

    implicitWidth: 22
    implicitHeight: 22
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    function openMenu() {
        const p = root.mapToItem(null, 0, 0);
        menu.anchor.rect.x = p.x;
        menu.anchor.rect.y = p.y;
        menu.anchor.rect.width = root.width;
        menu.anchor.rect.height = root.height;
        menu.open();
    }

    onClicked: mouse => {
        if (mouse.button === Qt.LeftButton) {
            if (item.onlyMenu && item.hasMenu)
                openMenu();
            else
                item.activate();
        } else if (mouse.button === Qt.RightButton) {
            if (item.hasMenu)
                openMenu();
            else
                item.secondaryActivate();
        } else {
            item.secondaryActivate();
        }
    }

    onWheel: wheel => item.scroll(wheel.angleDelta.y, false)

    QsMenuAnchor {
        id: menu
        menu: root.item ? root.item.menu : null
        anchor.window: root.barWindow
        anchor.edges: Config.bar.position === "top" ? Edges.Bottom : Edges.Top
        anchor.gravity: Config.bar.position === "top" ? Edges.Bottom : Edges.Top
    }

    Image {
        anchors.centerIn: parent
        width: 18
        height: 18
        sourceSize: Qt.size(36, 36)
        source: root.item ? root.item.icon : ""
        smooth: true
        opacity: root.containsMouse ? 1 : 0.85

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.animFast
            }
        }
    }
}
