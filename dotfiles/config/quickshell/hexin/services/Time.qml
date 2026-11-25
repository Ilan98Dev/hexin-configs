pragma Singleton

import QtQuick
import Quickshell
import qs.config

Singleton {
    id: root

    readonly property date date: clock.date

    readonly property string timeString: Qt.formatDateTime(date, Config.bar.clock24h ? (Config.bar.clockSeconds ? "HH:mm:ss" : "HH:mm") : (Config.bar.clockSeconds ? "h:mm:ss AP" : "h:mm AP"))
    readonly property string dateString: Qt.formatDateTime(date, Config.bar.dateFormat)

    SystemClock {
        id: clock
        precision: Config.bar.clockSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    // "just now", "5m ago", "3h ago", "2d ago"
    function ago(d) {
        const s = Math.max(0, Math.floor((date.getTime() - d.getTime()) / 1000));
        if (s < 60)
            return "now";
        if (s < 3600)
            return Math.floor(s / 60) + "m ago";
        if (s < 86400)
            return Math.floor(s / 3600) + "h ago";
        return Math.floor(s / 86400) + "d ago";
    }

    // seconds or microseconds-safe mm:ss
    function duration(sec) {
        sec = Math.max(0, Math.floor(sec));
        const m = Math.floor(sec / 60);
        const s = sec % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }
}
