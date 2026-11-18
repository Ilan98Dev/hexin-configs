pragma Singleton

import QtQuick
import Quickshell

// Session lock state for hyprunity's built-in lock screen.
//
// The actual WlSessionLock lives in shell.qml and binds its `locked` property
// to `Lock.locked`; the lock screen (modules/lock/LockScreen.qml) calls
// Lock.unlock() once PAM accepts the password.
Singleton {
    id: root

    property bool locked: false

    function lock() {
        locked = true;
    }

    function unlock() {
        locked = false;
    }

    function toggle() {
        locked = !locked;
    }
}
