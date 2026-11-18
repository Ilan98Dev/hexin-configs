pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    // Prefer a player that is actually playing, otherwise the first one.
    function pick() {
        const l = Mpris.players.values;
        for (let i = 0; i < l.length; i++) {
            if (l[i].isPlaying)
                return l[i];
        }
        return l.length > 0 ? l[0] : null;
    }

    readonly property var player: pick()
    readonly property bool playing: player !== null && player.isPlaying
    readonly property string title: player ? (player.trackTitle || "") : ""
    readonly property string artist: player ? (player.trackArtist || "") : ""
    readonly property string art: player ? (player.trackArtUrl || "") : ""
    readonly property string label: artist !== "" ? artist + " — " + title : title
}
