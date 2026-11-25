pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.config

// Battery + power profile (UPower / power-profiles-daemon).
Singleton {
    id: root

    readonly property var dev: UPower.displayDevice
    readonly property bool present: dev !== null && dev.isPresent && dev.isLaptopBattery
    readonly property int percent: present ? Math.round(dev.percentage * 100) : 0
    readonly property bool charging: present && dev.state === UPowerDeviceState.Charging
    readonly property bool plugged: present && !UPower.onBattery
    readonly property bool low: present && !plugged && percent <= 20

    readonly property string icon: charging ? Icons.bolt : Icons.battery[Math.min(4, Math.floor(percent / 20))]
    readonly property color color: charging ? Theme.green : (low ? Theme.red : (percent <= 40 && !plugged ? Theme.yellow : Theme.text))

    readonly property string eta: {
        if (!present)
            return "";
        const s = charging ? dev.timeToFull : dev.timeToEmpty;
        if (!s || s <= 0)
            return plugged ? "Plugged in" : "";
        const h = Math.floor(s / 3600);
        const m = Math.floor((s % 3600) / 60);
        return (h > 0 ? h + "h " : "") + m + "m " + (charging ? "to full" : "left");
    }

    // ---- power profiles ----
    // Power profiles are not tied to a battery: desktops with
    // power-profiles-daemon expose them too. `present` alone hid the tile
    // there, so accept a performance profile as proof the service exists.
    readonly property bool hasProfiles: present || PowerProfiles.hasPerformanceProfile
    readonly property int profile: PowerProfiles.profile
    readonly property bool performance: profile === PowerProfile.Performance
    readonly property string profileName: profile === PowerProfile.PowerSaver ? "Power saver" : (profile === PowerProfile.Performance ? "Performance" : "Balanced")
    readonly property string profileIcon: profile === PowerProfile.PowerSaver ? Icons.leaf : (profile === PowerProfile.Performance ? Icons.rocket : Icons.balance)

    function cycleProfile() {
        if (profile === PowerProfile.PowerSaver)
            PowerProfiles.profile = PowerProfile.Balanced;
        else if (profile === PowerProfile.Balanced)
            PowerProfiles.profile = PowerProfiles.hasPerformanceProfile ? PowerProfile.Performance : PowerProfile.PowerSaver;
        else
            PowerProfiles.profile = PowerProfile.PowerSaver;
    }
}
