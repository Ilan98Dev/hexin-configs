pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.config

Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    readonly property bool ready: sink !== null && sink.audio !== null
    readonly property real volume: ready ? sink.audio.volume : 0
    readonly property bool muted: ready ? sink.audio.muted : false

    readonly property bool micReady: source !== null && source.audio !== null
    readonly property real micVolume: micReady ? source.audio.volume : 0
    readonly property bool micMuted: micReady ? source.audio.muted : false

    readonly property string icon: muted || volume <= 0.001 ? Icons.volumeMute : (volume < 0.34 ? Icons.volumeLow : Icons.volumeHigh)

    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    readonly property var sources: Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && n.audio)

    PwObjectTracker {
        objects: Pipewire.nodes.values
    }

    function label(node) {
        if (!node)
            return "";
        return node.nickname || node.description || node.name;
    }

    function setVolume(v) {
        if (!ready)
            return;
        sink.audio.muted = false;
        sink.audio.volume = Math.max(0, Math.min(1, v));
    }

    function step(delta) {
        setVolume(volume + delta);
    }

    function toggleMute() {
        if (ready)
            sink.audio.muted = !sink.audio.muted;
    }

    function setMicVolume(v) {
        if (!micReady)
            return;
        source.audio.muted = false;
        source.audio.volume = Math.max(0, Math.min(1, v));
    }

    function toggleMicMute() {
        if (micReady)
            source.audio.muted = !source.audio.muted;
    }

    function setDefault(node) {
        if (node)
            Quickshell.execDetached(["wpctl", "set-default", String(node.id)]);
    }
}
