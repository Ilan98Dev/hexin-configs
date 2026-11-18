pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.config

// Notification daemon. Owns the server, keeps a history list (shown in the
// notification center) and a subset flagged as "popup" (shown as toasts).
Singleton {
    id: root

    property var list: []   // wrappers, newest first
    readonly property int count: list.length
    readonly property var popupList: list.filter(n => n.popup).slice(0, Config.notifications.maxPopups)
    readonly property bool dnd: Config.notifications.dnd

    function isNotice(n) {
        if (!n || !n.hints)
            return false;
        const h = n.hints;
        if (h["x-hyprunity-notice"] !== undefined)
            return true;
        if (h["hyprunity-notice"] !== undefined)
            return true;
        if (h["hyprunity:notice"] !== undefined)
            return true;
        return false;
    }

    function quote(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'";
    }

    function notify(title, body, icon) {
        if (icon === undefined)
            icon = "bell";
        const cmd = ["sh", "-c", "notify-send -a hyprunity -i " + quote(icon) + " -u normal -t 4000 -h string:x-hyprunity-notice:1 " + quote(title) + " " + quote(body)];
        Quickshell.execDetached(cmd);
    }

    // A notice with one clickable button. `command` is run through sh when the
    // user picks the action, so callers pass e.g. an IPC call back into the
    // shell. notify-send waits for the action (or the notification closing).
    function notifyAction(title, body, icon, actionLabel, actionId, command) {
        if (icon === undefined)
            icon = "dialog-error";
        const script = "act=$(notify-send -a hyprunity -i " + quote(icon)
            + " -u critical -t 0 -h string:x-hyprunity-toast:15 -A " + quote(actionId + "=" + actionLabel)
            + " -h string:x-hyprunity-notice:1 "
            + quote(title) + " " + quote(body) + "); "
            + "if [ \"$act\" = " + quote(actionId) + " ]; then " + command + "; fi";
        Quickshell.execDetached(["sh", "-c", script]);
    }

    function toggleDnd() {
        const will = !Config.notifications.dnd;
        if (will)
            notify("Do Not Disturb", "Notifications silenced", "bell-slash");
        else
            notify("Do Not Disturb", "Notifications will show again", "bell");
        Config.notifications.dnd = will;
    }

    function find(n) {
        return list.find(w => w.notification === n) ?? null;
    }

    function shouldPopup(n) {
        if (root.isNotice(n))
            return true;
        if (!Config.notifications.popups)
            return false;
        if (!Config.notifications.dnd)
            return true;
        return Config.notifications.criticalBypassDnd && n.urgency === NotificationUrgency.Critical;
    }

    function wrap(n, popup) {
        const w = factory.createObject(root, {
            notification: n,
            popup: popup
        });
        list = [w, ...list];
        return w;
    }

    function drop(w) {
        if (list.indexOf(w) < 0)
            return;
        list = list.filter(x => x !== w);
        w.destroy();
    }

    function dismiss(w) {
        if (list.indexOf(w) < 0)
            return;
        const n = w.notification;
        drop(w);
        n.dismiss();
    }

    // Notification actions do not point back at their notification, so find
    // the wrapper by action identity. Used by the action buttons in NotifCard,
    // where outer ids are not in scope.
    function dismissAction(action) {
        for (const w of list) {
            const actions = w.notification.actions || [];
            if (actions.indexOf(action) < 0)
                continue;
            if (!w.notification.resident)
                dismiss(w);
            return;
        }
    }

    function clearAll() {
        for (const w of list.slice())
            dismiss(w);
    }

    component Notif: QtObject {
        id: notif

        required property var notification
        property bool popup: false
        property bool hovered: false
        property date time: new Date()

        // seconds; 0 = never auto-hide
        readonly property real timeout: {
            // Per-notification toast duration. notifyAction() sends persistent
            // notifications (expire_timeout 0) so the action stays available in
            // the notification centre, but the on-screen toast should still go
            // away on its own.
            const hints = notification.hints;
            if (hints && hints["x-hyprunity-toast"] !== undefined) {
                const seconds = parseFloat(String(hints["x-hyprunity-toast"]));
                if (!isNaN(seconds))
                    return seconds;
            }
            // D-Bus expire_timeout arrives in milliseconds; the Timer below
            // works in seconds.
            if (notification.expireTimeout > 0)
                return notification.expireTimeout / 1000;
            if (notification.urgency === NotificationUrgency.Critical)
                return 0;
            return Config.notifications.timeout;
        }

        property Timer timer: Timer {
            running: notif.popup && notif.timeout > 0 && !notif.hovered
            interval: notif.timeout * 1000
            onTriggered: notif.popup = false
        }

        property Connections conn: Connections {
            target: notif.notification
            function onClosed() {
                root.drop(notif);
            }
        }
    }

    Component {
        id: factory
        Notif {}
    }

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;
            const existing = root.find(n);
            if (existing) {
                existing.time = new Date();
                existing.popup = root.shouldPopup(n);
            } else {
                root.wrap(n, root.shouldPopup(n));
            }
        }
    }

    // Re-adopt notifications that survived a shell reload.
    Component.onCompleted: {
        for (const n of server.trackedNotifications.values)
            root.wrap(n, false);
    }
}
