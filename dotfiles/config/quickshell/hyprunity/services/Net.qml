pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Network state through NetworkManager (nmcli).
Singleton {
    id: root

    property bool hasWifi: false
    property bool wifiEnabled: true
    property string type: "none"       // wifi | ethernet | none
    property string name: ""
    property int strength: 0
    property var networks: []          // [{ssid, strength, secure, active}]
    property string connecting: ""
    property string failedSsid: ""     // set when a connect attempt needs a password

    readonly property bool connected: type !== "none"
    readonly property string icon: type === "ethernet" ? Icons.globe : Icons.wifi

    // Split an `nmcli -t` line on unescaped colons.
    function splitLine(line) {
        const out = [];
        let cur = "";
        for (let i = 0; i < line.length; i++) {
            const c = line[i];
            if (c === "\\" && i + 1 < line.length) {
                cur += line[++i];
            } else if (c === ":") {
                out.push(cur);
                cur = "";
            } else {
                cur += c;
            }
        }
        out.push(cur);
        return out;
    }

    function parseStatus(text) {
        let wifi = false, t = "none", n = "";
        for (const line of text.split("\n")) {
            if (!line)
                continue;
            const f = splitLine(line);
            if (f[0] === "wifi")
                wifi = true;
            if ((f[0] === "wifi" || f[0] === "ethernet") && (f[1] || "").startsWith("connected") && t === "none") {
                t = f[0];
                n = f[2] || "";
            }
        }
        hasWifi = wifi;
        type = t;
        name = n;
    }

    function parseList(text) {
        const best = {};
        for (const line of text.split("\n")) {
            if (!line)
                continue;
            const f = splitLine(line);
            const ssid = f[1];
            if (!ssid)
                continue;
            const entry = {
                ssid: ssid,
                active: f[0] === "*",
                strength: parseInt(f[2]) || 0,
                secure: (f[3] || "") !== "" && f[3] !== "--"
            };
            const old = best[ssid];
            if (!old || entry.active || (!old.active && entry.strength > old.strength))
                best[ssid] = entry;
        }
        const arr = Object.values(best);
        arr.sort((a, b) => (b.active - a.active) || (b.strength - a.strength));
        networks = arr;
        const act = arr.find(n => n.active);
        if (act)
            strength = act.strength;
    }

    function refresh(full) {
        if (!statusProc.running)
            statusProc.running = true;
        if (!radioProc.running)
            radioProc.running = true;
        if (full && hasWifi && !listProc.running)
            listProc.running = true;
    }

    function setWifi(on) {
        wifiEnabled = on;
        Quickshell.execDetached(["nmcli", "radio", "wifi", on ? "on" : "off"]);
        postToggle.restart();
    }

    function connectTo(ssid, password) {
        failedSsid = "";
        connecting = ssid;
        connectProc.ssid = ssid;
        connectProc.command = password ? ["nmcli", "device", "wifi", "connect", ssid, "password", password] : ["nmcli", "device", "wifi", "connect", ssid];
        connectProc.running = true;
    }

    Timer {
        id: postToggle
        interval: 1200
        onTriggered: root.refresh(true)
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh(false)
    }

    Connections {
        target: Panels
        function onActiveChanged() {
            if (Panels.active === "control")
                root.refresh(true);
        }
    }

    Process {
        id: statusProc
        command: ["nmcli", "-t", "-f", "TYPE,STATE,CONNECTION", "device"]
        stdout: StdioCollector {
            onStreamFinished: root.parseStatus(text)
        }
    }

    Process {
        id: radioProc
        command: ["nmcli", "radio", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: root.wifiEnabled = text.trim() === "enabled"
        }
    }

    Process {
        id: listProc
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "auto"]
        stdout: StdioCollector {
            onStreamFinished: root.parseList(text)
        }
    }

    Process {
        id: connectProc
        property string ssid: ""
        onExited: (code, status) => {
            root.connecting = "";
            root.failedSsid = code === 0 ? "" : ssid;
            root.refresh(true);
        }
    }
}
