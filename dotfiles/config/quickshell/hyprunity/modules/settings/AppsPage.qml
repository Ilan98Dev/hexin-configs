import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

SettingsPage {
    title: "Commands"
    subtitle: "Shell commands the bar and control panel run. Each is executed with sh -c."

    SectionLabel {
        text: "Apps"
    }

    SettingRow {
        title: "Launcher"
        description: "Leave empty to use hyprunity's built-in launcher panel. Set a command to run an external launcher instead."

        Input {
            implicitWidth: 300
            text: Config.apps.launcher
            onCommitted: v => Config.apps.launcher = v
        }
    }
    SettingRow {
        title: "Terminal"

        Input {
            implicitWidth: 300
            text: Config.apps.terminal
            onCommitted: v => Config.apps.terminal = v
        }
    }
    SettingRow {
        title: "Browser"
        description: "Opened by Spotlight for web searches and URLs."

        Input {
            implicitWidth: 300
            text: Config.apps.browser
            onCommitted: v => Config.apps.browser = v
        }
    }
    SettingRow {
        title: "Screenshot"
        description: "Runs shortly after the panel closes."

        Input {
            implicitWidth: 300
            text: Config.apps.screenshot
            onCommitted: v => Config.apps.screenshot = v
        }
    }

    SectionLabel {
        text: "Session"
    }

    SettingRow {
        title: "Lock"
        description: "Leave empty to use hyprunity's built-in lock screen (PAM). Set a command to use an external locker instead."

        Input {
            implicitWidth: 300
            text: Config.apps.lock
            onCommitted: v => Config.apps.lock = v
        }
    }
    SettingRow {
        title: "Logout"

        Input {
            implicitWidth: 300
            text: Config.apps.logout
            onCommitted: v => Config.apps.logout = v
        }
    }
    SettingRow {
        title: "Suspend"

        Input {
            implicitWidth: 300
            text: Config.apps.suspend
            onCommitted: v => Config.apps.suspend = v
        }
    }
    SettingRow {
        title: "Reboot"

        Input {
            implicitWidth: 300
            text: Config.apps.reboot
            onCommitted: v => Config.apps.reboot = v
        }
    }
    SettingRow {
        title: "Shutdown"

        Input {
            implicitWidth: 300
            text: Config.apps.shutdown
            onCommitted: v => Config.apps.shutdown = v
        }
    }
}
