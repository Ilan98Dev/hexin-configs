pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Screen recording through gpu-screen-recorder.
//
//   startFull()    record the focused monitor
//   startRegion()  let slurp pick an area, then record just that
//   stop()         SIGINT, so gpu-screen-recorder finalizes the container
//
// Files land in ~/Videos as Screen_Recording_<date>_<time>.mp4, with desktop
// audio. The control panel starts a recording and the bar grows a stop pill
// while one is running.
Singleton {
    id: root

    property bool recording: false
    property string mode: ""            // "full" | "region"
    property string outputPath: ""
    property double startedAt: 0
    property int elapsedSec: 0
    property string lastError: ""
    property string lastSaved: ""

    // A start is waiting for the panel to finish fading out, or for slurp.
    property bool pendingStart: false
    property string pendingMode: ""
    property bool stopping: false

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string videosDir: home + "/Videos"
    readonly property string fileName: outputPath.split("/").pop()
    // Settings > Control Panel owns this. The Record tile and the IPC toggle
    // use it; the dedicated shortcuts always pick their own mode.
    readonly property string defaultMode: Config.controlPanel.recordingMode === "fullscreen" ? "fullscreen" : "region"

    readonly property string elapsedLabel: {
        const s = Math.max(0, elapsedSec);
        const h = Math.floor(s / 3600);
        const m = Math.floor((s % 3600) / 60);
        const sec = s % 60;
        const mm = (h > 0 && m < 10 ? "0" : "") + m;
        const ss = (sec < 10 ? "0" : "") + sec;
        return h > 0 ? h + ":" + mm + ":" + ss : mm + ":" + ss;
    }

    function notify(title, body) {
        Notifs.notify(title, body, "media-record");
    }

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    function startFull() {
        begin("full");
    }

    function startRegion() {
        begin("region");
    }

    // The single control-panel tile: start the configured mode, or stop the
    // recording that is already running.
    function startDefault() {
        if (recording) {
            stop();
            return;
        }
        if (defaultMode === "fullscreen")
            startFull();
        else
            startRegion();
    }

    function begin(m) {
        if (recording || pendingStart)
            return;
        pendingMode = m;
        pendingStart = true;
        // The control panel closes first so neither its fade nor the pointer
        // ends up in the recording.
        Panels.close();
        startDelay.restart();
    }

    function launch(target) {
        const stamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss");
        outputPath = videosDir + "/Screen_Recording_" + stamp + ".mp4";
        lastError = "";
        mode = pendingMode;
        startedAt = Date.now();
        elapsedSec = 0;
        stopping = false;
        // mkdir in the same shell so the encoder never races the folder.
        recorder.command = ["sh", "-c",
            "mkdir -p " + shellQuote(videosDir) + " && exec gpu-screen-recorder"
            + " -w " + shellQuote(target)
            + " -c mp4 -f 60 -a default_output"
            + " -o " + shellQuote(outputPath)];
        recording = true;
        recorder.running = true;
        notify("Screen recording", (pendingMode === "region" ? "Recording the selected region" : "Recording the focused monitor") + " · stop from the bar");
    }

    function stop() {
        if (!recording || stopping)
            return;
        stopping = true;
        recorder.signal(2); // SIGINT: gpu-screen-recorder finalizes the file
    }

    function finishRegion(code) {
        const geo = regionOut.text.trim();
        if (code === 0 && /^\d+x\d+\+-?\d+\+-?\d+$/.test(geo))
            root.launch(geo);
        else
            root.notify("Screen recording", "Region selection cancelled");
    }

    Timer {
        id: startDelay
        interval: 350
        repeat: false
        onTriggered: {
            if (!root.pendingStart)
                return;
            root.pendingStart = false;
            if (root.pendingMode === "region") {
                regionSelect.running = true;
            } else {
                const mon = Panels.focusedScreen();
                root.launch(mon && mon.length ? mon : "screen");
            }
        }
    }

    Timer {
        id: tick
        interval: 1000
        repeat: true
        running: root.recording
        onTriggered: root.elapsedSec = Math.max(0, Math.floor((Date.now() - root.startedAt) / 1000))
    }

    // Region picker. stdin is closed explicitly: Quickshell gives children a
    // pipe, and slurp reads boxes from a piped stdin instead of opening its UI.
    Process {
        id: regionSelect
        running: false
        command: ["sh", "-c", "exec 0</dev/null; slurp -f '%wx%h+%x+%y'"]

        stdout: StdioCollector {
            id: regionOut
            waitForEnd: true
        }

        // Let the collector deliver the last chunk before reading its text.
        onExited: (code, status) => Qt.callLater(() => root.finishRegion(code))
    }

    Process {
        id: recorder
        running: false

        // gpu-screen-recorder logs progress on stderr. Keep only the latest
        // line: a failure message is what matters, and a long recording must
        // not accumulate output in memory.
        stderr: SplitParser {
            onRead: data => root.lastError = data
        }

        onExited: (code, status) => {
            const wasStopping = root.stopping;
            const saved = root.outputPath;
            const failed = root.recording && !wasStopping && code !== 0;
            root.recording = false;
            root.stopping = false;
            root.mode = "";
            if (failed) {
                const detail = (root.lastError || "").trim();
                root.notify("Screen recording", "Recording failed" + (detail.length ? ": " + detail : ""));
            } else if (wasStopping) {
                root.lastSaved = saved;
                root.notify("Screen recording", "Saved " + saved.split("/").pop() + " to ~/Videos");
            }
        }
    }
}
