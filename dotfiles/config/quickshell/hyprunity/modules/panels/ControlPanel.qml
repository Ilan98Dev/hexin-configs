import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs.config
import qs.services
import qs.components

Rectangle {
    id: root

    property int maxHeight: 800
    property string expanded: ""   // "" | wifi | bt | audio

    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property var btConnected: Bluetooth.devices.values.filter(d => d.connected)
    readonly property var btList: Bluetooth.devices.values.filter(d => d.paired || d.connected || (btAdapter && btAdapter.discovering)).slice().sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired))

    function toggleExpand(name) {
        expanded = expanded === name ? "" : name;
    }

    implicitWidth: Config.controlPanel.width
    implicitHeight: Math.min(maxHeight, col.implicitHeight + 40)

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Theme.anim
            easing.type: Easing.OutCubic
        }
    }
    radius: Theme.radius
    color: Theme.bg
    border.width: 1
    border.color: Theme.border

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
    clip: true

    MouseArea {
        anchors.fill: parent
    }

    Flickable {
        id: flick
        anchors {
            fill: parent
            margins: 16
        }
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: col
            width: flick.width
            spacing: 12

            // ───── header ─────
            RowLayout {
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: 0
                    Txt {
                        text: Qt.formatDateTime(Time.date, "dddd")
                        font.pixelSize: Theme.fontLarge + 2
                        font.bold: true
                    }
                    Txt {
                        text: Qt.formatDateTime(Time.date, "d MMMM yyyy")
                        color: Theme.subtext
                    }
                }
                Item {
                    Layout.fillWidth: true
                }
                IconButton {
                    glyph: Icons.cog
                    onClicked: Panels.openSettings()
                }
            }

            // ───── sliders ─────
            Card {
                visible: Config.controlPanel.showSliders
                Layout.fillWidth: true

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    IconButton {
                        glyph: Audio.icon
                        active: Audio.muted
                        onClicked: Audio.toggleMute()
                    }
                    SliderBar {
                        Layout.fillWidth: true
                        value: Audio.volume
                        onMoved: v => Audio.setVolume(v)
                    }
                    Txt {
                        text: Math.round(Audio.volume * 100) + "%"
                        horizontalAlignment: Text.AlignRight
                        Layout.preferredWidth: 38
                    }
                    IconButton {
                        glyph: root.expanded === "audio" ? Icons.chevronUp : Icons.chevronDown
                        size: 28
                        glyphSize: Theme.fontSmall
                        onClicked: root.toggleExpand("audio")
                    }
                }

                RowLayout {
                    visible: Audio.micReady
                    Layout.fillWidth: true
                    spacing: 8

                    IconButton {
                        glyph: Audio.micMuted ? Icons.micOff : Icons.mic
                        active: Audio.micMuted
                        onClicked: Audio.toggleMicMute()
                    }
                    SliderBar {
                        Layout.fillWidth: true
                        value: Audio.micVolume
                        fillColor: Theme.green
                        onMoved: v => Audio.setMicVolume(v)
                    }
                    Txt {
                        text: Math.round(Audio.micVolume * 100) + "%"
                        horizontalAlignment: Text.AlignRight
                        Layout.preferredWidth: 38
                    }
                    Item {
                        Layout.preferredWidth: 28
                    }
                }

                RowLayout {
                    visible: Brightness.available
                    Layout.fillWidth: true
                    spacing: 8

                    Item {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: brightGlyph.implicitHeight

                        Glyph {
                            id: brightGlyph
                            anchors.centerIn: parent
                            text: Icons.brightness
                            color: Theme.yellow
                        }
                    }
                    SliderBar {
                        Layout.fillWidth: true
                        value: Brightness.value
                        fillColor: Theme.yellow
                        onMoved: v => Brightness.set(v)
                    }
                    Txt {
                        text: Math.round(Brightness.value * 100) + "%"
                        horizontalAlignment: Text.AlignRight
                        Layout.preferredWidth: 38
                    }
                    Item {
                        Layout.preferredWidth: 28
                    }
                }
            }

            // ───── audio devices ─────
            Card {
                visible: root.expanded === "audio"
                Layout.fillWidth: true
                spacing: 2
                opacity: visible ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.anim
                        easing.type: Easing.OutCubic
                    }
                }

                Txt {
                    text: "Output"
                    color: Theme.subtext
                    font.pixelSize: Theme.fontSmall
                }
                Repeater {
                    model: Audio.sinks

                    ListRow {
                        required property var modelData
                        Layout.fillWidth: true
                        glyph: Icons.headphones
                        title: Audio.label(modelData)
                        active: Audio.sink !== null && Audio.sink.id === modelData.id
                        trailing: active ? Icons.check : ""
                        onClicked: Audio.setDefault(modelData)
                    }
                }
                Txt {
                    visible: Audio.sources.length > 0
                    text: "Input"
                    color: Theme.subtext
                    font.pixelSize: Theme.fontSmall
                    Layout.topMargin: 6
                }
                Repeater {
                    model: Audio.sources

                    ListRow {
                        required property var modelData
                        Layout.fillWidth: true
                        glyph: Icons.mic
                        title: Audio.label(modelData)
                        active: Audio.source !== null && Audio.source.id === modelData.id
                        trailing: active ? Icons.check : ""
                        onClicked: Audio.setDefault(modelData)
                    }
                }
            }

            // ───── toggle tiles ─────
            GridLayout {
                visible: Config.controlPanel.showTiles
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 8
                rowSpacing: 8

                Tile {
                    visible: Net.hasWifi
                    Layout.fillWidth: true
                    Layout.preferredWidth: 100
                    glyph: Icons.wifi
                    title: "Wi-Fi"
                    subtitle: !Net.wifiEnabled ? "Off" : (Net.type === "wifi" ? Net.name : "Not connected")
                    active: Net.wifiEnabled
                    expandable: true
                    expanded: root.expanded === "wifi"
                    onClicked: Net.setWifi(!Net.wifiEnabled)
                    onExpand: {
                        root.toggleExpand("wifi");
                        Net.refresh(true);
                    }
                }
                Tile {
                    visible: root.btAdapter !== null
                    Layout.fillWidth: true
                    Layout.preferredWidth: 100
                    glyph: Icons.bluetooth
                    title: "Bluetooth"
                    subtitle: !(root.btAdapter && root.btAdapter.enabled) ? "Off" : (root.btConnected.length > 0 ? root.btConnected[0].name : "On")
                    active: root.btAdapter !== null && root.btAdapter.enabled
                    expandable: true
                    expanded: root.expanded === "bt"
                    onClicked: root.btAdapter.enabled = !root.btAdapter.enabled
                    onExpand: root.toggleExpand("bt")
                }
                Tile {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 100
                    glyph: Notifs.dnd ? Icons.bellSlash : Icons.bell
                    title: "Do Not Disturb"
                    subtitle: Notifs.dnd ? "On" : "Off"
                    active: Notifs.dnd
                    onClicked: Notifs.toggleDnd()
                }
                Tile {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 100
                    glyph: Icons.gamepad
                    title: "Game Mode"
                    subtitle: Actions.gameMode ? "On" : "Off"
                    active: Actions.gameMode
                    onClicked: Actions.gameMode = !Actions.gameMode
                }
                Tile {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 100
                    glyph: Icons.moon
                    title: "Night Light"
                    subtitle: Actions.nightLight ? Config.controlPanel.nightLightTemp + " K" : "Off"
                    active: Actions.nightLight
                    onClicked: {
                        Actions.nightLight = !Actions.nightLight;
                        Notifs.notify(Actions.nightLight ? "Night Light" : "Night Light", Actions.nightLight ? "Night Light enabled" : "Night Light disabled", "moon");
                    }
                }
                Tile {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 100
                    glyph: Icons.coffee
                    title: "Caffeine"
                    subtitle: Actions.caffeine ? "Keeping awake" : "Off"
                    active: Actions.caffeine
                    onClicked: {
                        Actions.caffeine = !Actions.caffeine;
                        Notifs.notify(Actions.caffeine ? "Caffeine" : "Caffeine", Actions.caffeine ? "Keeping the system awake" : "Caffeine off", "coffee");
                    }
                }
                Tile {
                    visible: Power.hasProfiles
                    Layout.fillWidth: true
                    Layout.preferredWidth: 100
                    glyph: Power.profileIcon
                    title: "Power Mode"
                    subtitle: Power.profileName
                    active: Power.performance
                    onClicked: Power.cycleProfile()
                }
                // One-button recorder. Its mode is the default from Settings >
                // Control Panel; while recording the same tile stops and saves.
                Tile {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 100
                    glyph: Recorder.recording ? Icons.stop : (Recorder.defaultMode === "fullscreen" ? Icons.desktop : Icons.crop)
                    title: Recorder.recording ? "Recording" : "Record"
                    subtitle: Recorder.recording
                        ? Recorder.elapsedLabel + " · " + (Recorder.mode === "region" ? "Region" : "Fullscreen")
                        : (Recorder.defaultMode === "fullscreen" ? "Fullscreen" : "Region")
                    active: Recorder.recording
                    danger: true
                    onClicked: Recorder.startDefault()
                }
            }

            // ───── wifi list ─────
            Card {
                visible: root.expanded === "wifi"
                Layout.fillWidth: true
                spacing: 2
                opacity: visible ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.anim
                        easing.type: Easing.OutCubic
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Txt {
                        text: Net.connecting !== "" ? "Connecting to " + Net.connecting + "…" : "Wi-Fi networks"
                        color: Theme.subtext
                        font.pixelSize: Theme.fontSmall
                        Layout.fillWidth: true
                    }
                    IconButton {
                        glyph: Icons.refresh
                        size: 24
                        glyphSize: Theme.fontSmall
                        onClicked: Net.refresh(true)
                    }
                }
                Repeater {
                    model: Net.networks.slice(0, 7)

                    ListRow {
                        required property var modelData
                        Layout.fillWidth: true
                        glyph: Icons.wifi
                        title: modelData.ssid
                        subtitle: modelData.active ? "Connected" : (modelData.secure ? "Secured · " + modelData.strength + "%" : "Open · " + modelData.strength + "%")
                        active: modelData.active
                        trailing: modelData.active ? Icons.check : (modelData.secure ? Icons.lock : "")
                        onClicked: if (!modelData.active) Net.connectTo(modelData.ssid, "")
                    }
                }
                Txt {
                    visible: Net.networks.length === 0
                    text: Net.wifiEnabled ? "No networks found" : "Wi-Fi is off"
                    color: Theme.subtext
                    Layout.alignment: Qt.AlignHCenter
                }
                Input {
                    visible: Net.failedSsid !== ""
                    Layout.fillWidth: true
                    password: true
                    placeholder: "Password for " + Net.failedSsid + " (Enter)"
                    onCommitted: value => {
                        if (value !== "" && Net.failedSsid !== "")
                            Net.connectTo(Net.failedSsid, value);
                    }
                }
            }

            // ───── bluetooth list ─────
            Card {
                visible: root.expanded === "bt" && root.btAdapter !== null
                Layout.fillWidth: true
                spacing: 2
                opacity: visible ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.anim
                        easing.type: Easing.OutCubic
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Txt {
                        text: "Bluetooth devices"
                        color: Theme.subtext
                        font.pixelSize: Theme.fontSmall
                        Layout.fillWidth: true
                    }
                    IconButton {
                        glyph: Icons.refresh
                        size: 24
                        glyphSize: Theme.fontSmall
                        active: root.btAdapter !== null && root.btAdapter.discovering
                        onClicked: root.btAdapter.discovering = !root.btAdapter.discovering
                    }
                }
                Repeater {
                    model: root.btList

                    ListRow {
                        required property var modelData
                        Layout.fillWidth: true
                        glyph: Icons.bluetooth
                        title: modelData.name
                        subtitle: modelData.connected ? "Connected" + (modelData.batteryAvailable ? " · " + Math.round(modelData.battery * 100) + "%" : "") : (modelData.paired ? "Paired" : "Tap to pair")
                        active: modelData.connected
                        onClicked: {
                            if (modelData.connected)
                                modelData.disconnect();
                            else if (modelData.paired)
                                modelData.connect();
                            else
                                modelData.pair();
                        }
                    }
                }
                Txt {
                    visible: root.btList.length === 0
                    text: root.btAdapter && root.btAdapter.enabled ? "No devices — press scan" : "Bluetooth is off"
                    color: Theme.subtext
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            // ───── media ─────
            MediaCard {
                visible: Config.controlPanel.showMedia && Media.player !== null
                Layout.fillWidth: true
            }

            // ───── system stats ─────
            Card {
                visible: Config.controlPanel.showStats
                Layout.fillWidth: true

                Meter {
                    Layout.fillWidth: true
                    glyph: Icons.cpu
                    label: ""
                    value: SysStats.cpu
                    valueText: Math.round(SysStats.cpu * 100) + "%"
                    barColor: Theme.blue
                }
                Meter {
                    Layout.fillWidth: true
                    glyph: Icons.ram
                    label: ""
                    value: SysStats.mem
                    valueText: SysStats.gb(SysStats.memUsed)
                    barColor: Theme.green
                }
                Meter {
                    Layout.fillWidth: true
                    glyph: Icons.disk
                    label: ""
                    value: SysStats.disk
                    valueText: Math.round(SysStats.disk * 100) + "%"
                    barColor: Theme.yellow
                }
                Meter {
                    visible: Power.present
                    Layout.fillWidth: true
                    glyph: Power.icon
                    label: ""
                    value: Power.percent / 100
                    valueText: Power.percent + "%"
                    barColor: Power.charging ? Theme.green : (Power.low ? Theme.red : Theme.accent)
                }
                Txt {
                    visible: Power.present && Power.eta !== ""
                    text: Power.eta
                    color: Theme.subtext
                    font.pixelSize: Theme.fontSmall
                    Layout.alignment: Qt.AlignRight
                }
            }

            // ───── session buttons ─────
            RowLayout {
                visible: Config.controlPanel.showPower
                Layout.fillWidth: true
                spacing: 6

                PowerButton {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    glyph: Icons.camera
                    label: "Shot"
                    onActivated: Actions.screenshot()
                }
                PowerButton {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    glyph: Icons.lock
                    label: "Lock"
                    onActivated: {
                        Panels.close();
                        Actions.lock();
                    }
                }
                PowerButton {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    glyph: Icons.moon
                    label: "Sleep"
                    onActivated: {
                        Panels.close();
                        Actions.suspend();
                    }
                }
                PowerButton {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    glyph: Icons.signOut
                    label: "Logout"
                    confirm: true
                    onActivated: Actions.logout()
                }
                PowerButton {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    glyph: Icons.refresh
                    label: "Reboot"
                    confirm: true
                    onActivated: Actions.reboot()
                }
                PowerButton {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    glyph: Icons.power
                    label: "Off"
                    confirm: true
                    onActivated: Actions.shutdown()
                }
            }
        }
    }
}
