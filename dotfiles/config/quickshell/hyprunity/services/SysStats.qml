pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// CPU / memory from /proc, disk from df.
Singleton {
    id: root

    property real cpu: 0          // 0..1
    property real memUsed: 0      // bytes
    property real memTotal: 0
    property real diskUsed: 0
    property real diskTotal: 0
    readonly property real mem: memTotal > 0 ? memUsed / memTotal : 0
    readonly property real disk: diskTotal > 0 ? diskUsed / diskTotal : 0

    property real prevIdle: 0
    property real prevTotal: 0

    readonly property bool wanted: Config.bar.showStats || Panels.active === "control"

    function gb(bytes) {
        return (bytes / 1073741824).toFixed(1) + " GB";
    }

    function parseCpu(txt) {
        const m = txt.match(/^cpu\s+(.*)$/m);
        if (!m)
            return;
        const f = m[1].trim().split(/\s+/).map(Number);
        const idle = f[3] + (f[4] || 0);
        const total = f.reduce((a, b) => a + b, 0);
        if (prevTotal > 0 && total > prevTotal)
            cpu = Math.max(0, Math.min(1, 1 - (idle - prevIdle) / (total - prevTotal)));
        prevIdle = idle;
        prevTotal = total;
    }

    function parseMem(txt) {
        const t = txt.match(/MemTotal:\s+(\d+)/);
        const a = txt.match(/MemAvailable:\s+(\d+)/);
        if (!t || !a)
            return;
        memTotal = parseInt(t[1]) * 1024;
        memUsed = (parseInt(t[1]) - parseInt(a[1])) * 1024;
    }

    Timer {
        interval: 2000
        running: root.wanted
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
        }
    }

    Timer {
        interval: 30000
        running: root.wanted
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!dfProc.running) dfProc.running = true
    }

    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: root.parseCpu(text())
    }

    FileView {
        id: meminfo
        path: "/proc/meminfo"
        onLoaded: root.parseMem(text())
    }

    Process {
        id: dfProc
        command: ["df", "-P", "-B1", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                if (lines.length < 2)
                    return;
                const f = lines[1].trim().split(/\s+/);
                root.diskTotal = parseFloat(f[1]);
                root.diskUsed = parseFloat(f[2]);
            }
        }
    }
}
