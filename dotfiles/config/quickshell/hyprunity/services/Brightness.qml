pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Backlight control through brightnessctl.
Singleton {
    id: root

    property bool available: false
    property real value: 0.5     // 0..1
    property real pending: 0.5
    property double lastSet: 0

    function set(v) {
        v = Math.max(0.01, Math.min(1, v));
        value = v;
        pending = v;
        lastSet = Date.now();
        applyTimer.restart();
    }

    function step(delta) {
        set(value + delta);
    }

    Timer {
        id: applyTimer
        interval: 60
        onTriggered: {
            if (setProc.running) {
                applyTimer.restart();
                return;
            }
            setProc.command = ["brightnessctl", "-q", "-c", "backlight", "set", Math.round(root.pending * 100) + "%"];
            setProc.running = true;
        }
    }

    Process {
        id: setProc
    }

    Process {
        id: getProc
        command: ["brightnessctl", "-m", "-c", "backlight", "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(",");
                if (f.length >= 5) {
                    root.available = true;
                    // Don't fight the user while they are dragging the slider.
                    if (Date.now() - root.lastSet > 1500)
                        root.value = parseInt(f[3]) / 100;
                }
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!getProc.running) getProc.running = true
    }
}
