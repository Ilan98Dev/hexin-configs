import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.components

Pill {
    id: root

    property var monitorScreen
    readonly property var monitor: Hyprland.monitorFor(monitorScreen)
    readonly property int activeId: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : -1
    readonly property bool numbers: Config.bar.workspaceStyle === "numbers"

    readonly property int workspaceLimit: Config.bar.workspaceCount || 5
    readonly property var allWorkspaces: Hyprland.workspaces.values
    readonly property var allMonitors: Hyprland.monitors.values

    readonly property var shownList: {
        let base = workspaceLimit;
        // Start with base set 1..base
        let out = [];
        for (let i = 1; i <= base; i++) out.push(i);

        // If current workspace is beyond base, add it
        if (root.activeId > 0 && root.activeId > base) {
            // avoid duplicates
            let exists = false;
            for (let k = 0; k < out.length; k++) if (out[k] === root.activeId) { exists = true; break; }
            if (!exists) out.push(root.activeId);
        }

        // Add any workspace that has windows/clients or is occupied (has apps)
        // Also add other active workspaces on other monitors
        for (let m = 0; m < allMonitors.length; m++) {
            const mon = allMonitors[m];
            if (!mon) continue;
            const aw = mon.activeWorkspace;
            if (aw && aw.id > 0) {
                let exists = false;
                for (let k = 0; k < out.length; k++) if (out[k] === aw.id) { exists = true; break; }
                if (!exists && aw.id > base) out.push(aw.id);
                else if (!exists) {
                    // also ensure it's present if it's active and within/over base? keep behavior as requested
                    // but ensure we don't drop base set; if within base already there
                }
            }
        }

        // Add occupied workspaces (with windows)
        for (let j = 0; j < allWorkspaces.length; j++) {
            const w = allWorkspaces[j];
            if (!w || w.id <= 0) continue;
            // consider occupied if it has clients
            const hasClients = (w.toplevels && w.toplevels.values && w.toplevels.values.length > 0) || w.windows > 0;
            if (!hasClients) continue;
            let exists = false;
            for (let k = 0; k < out.length; k++) if (out[k] === w.id) { exists = true; break; }
            if (!exists) {
                // add if it's active somewhere or if it's > base / just add as requested
                // requested: if app is on workspace 8 and user on workspace 6 with base 5 -> add 6 and 8
                // so add occupied workspaces (especially those outside base set) - but also include current if outside base
                out.push(w.id);
            }
        }

        // Ensure current workspace is included
        if (root.activeId > 0) {
            let exists = false;
            for (let k = 0; k < out.length; k++) if (out[k] === root.activeId) { exists = true; break; }
            if (!exists) out.push(root.activeId);
        }

        // Sort numerically
        out.sort((a, b) => a - b);
        return out;
    }
    readonly property int count: shownList.length

    // Hyprland here is driven by a Lua config, so dispatch takes a Lua
    // expression: hyprctl dispatch 'hl.dsp.focus({ workspace = 4 })'.
    // The legacy "workspace 4" string is a Lua syntax error and silently
    // does nothing (Hyprland answers with a parser error), which is why the
    // bar buttons used to be dead.
    function focusWorkspace(target) {
        const arg = typeof target === "number" ? target : JSON.stringify(String(target));
        Hyprland.dispatch("hl.dsp.focus({ workspace = " + arg + " })");
    }

    interactive: false
    padding: 6

    // Scroll anywhere over the workspaces to switch.
    WheelHandler {
        onWheel: event => root.focusWorkspace(event.angleDelta.y > 0 ? "e-1" : "e+1")
    }

    Repeater {
        model: root.shownList

        Rectangle {
            id: dot

            required property var modelData
            readonly property int wsId: typeof modelData === "number" ? modelData : (index + 1)
            readonly property var ws: Hyprland.workspaces.values.find(w => w.id === wsId)
            readonly property bool focused: root.activeId === wsId
            readonly property bool occupied: ws !== undefined && ws !== null
            readonly property bool urgent: occupied && ws.urgent
            property bool hovered: false

            implicitHeight: root.numbers ? 22 : 8
            implicitWidth: root.numbers ? 24 : (focused ? 24 : 8)
            radius: root.numbers ? Theme.radiusSmall - 2 : 4
            color: urgent ? Theme.red : focused ? Theme.accent : (occupied ? Qt.alpha(Theme.text, 0.55) : Qt.alpha(Theme.text, 0.2))
            scale: hovered && !focused ? 1.25 : 1

            Behavior on implicitWidth {
                NumberAnimation {
                    duration: Theme.anim
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: Theme.animFast
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: Theme.animFast
                    easing.type: Easing.OutCubic
                }
            }

            Txt {
                visible: root.numbers
                anchors.centerIn: parent
                text: dot.wsId
                color: dot.focused || dot.urgent ? Theme.onAccent : (dot.occupied ? Theme.text : Theme.subtext)
                font.pixelSize: Theme.fontSmall + 1
                font.bold: dot.focused
            }

            MouseArea {
                id: dotMa
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onEntered: dot.hovered = true
                onExited: dot.hovered = false
                onClicked: root.focusWorkspace(dot.wsId)
            }
        }
    }
}
