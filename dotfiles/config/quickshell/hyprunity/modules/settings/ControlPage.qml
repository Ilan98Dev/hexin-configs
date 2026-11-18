import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

SettingsPage {
    title: "Control Panel"
    subtitle: "Choose what the quick-settings panel shows."

    SettingRow {
        title: "Width"

        ValueSlider {
            from: 320
            to: 560
            step: 10
            suffix: " px"
            value: Config.controlPanel.width
            onMoved: v => Config.controlPanel.width = Math.round(v)
        }
    }

    SectionLabel {
        text: "Sections"
    }

    SettingRow {
        title: "Volume / mic / brightness sliders"

        Toggle {
            checked: Config.controlPanel.showSliders
            onToggled: v => Config.controlPanel.showSliders = v
        }
    }
    SettingRow {
        title: "Toggle tiles"
        description: "Wi-Fi, Bluetooth, Do Not Disturb, Night Light, Caffeine, Power Mode."

        Toggle {
            checked: Config.controlPanel.showTiles
            onToggled: v => Config.controlPanel.showTiles = v
        }
    }
    SettingRow {
        title: "Media player"

        Toggle {
            checked: Config.controlPanel.showMedia
            onToggled: v => Config.controlPanel.showMedia = v
        }
    }
    SettingRow {
        title: "System stats"

        Toggle {
            checked: Config.controlPanel.showStats
            onToggled: v => Config.controlPanel.showStats = v
        }
    }
    SettingRow {
        title: "Session buttons"
        description: "Screenshot, lock, sleep, logout, reboot, shutdown. Logout, reboot and shutdown need a second click."

        Toggle {
            checked: Config.controlPanel.showPower
            onToggled: v => Config.controlPanel.showPower = v
        }
    }

    SectionLabel {
        text: "Screen recording"
    }

    SettingRow {
        title: "Default recording mode"
        description: "What the control panel's Record button starts. Region opens the area picker first; the bar's stop pill appears while recording."

        Segmented {
            options: [
                {
                    label: "Region",
                    value: "region"
                },
                {
                    label: "Fullscreen",
                    value: "fullscreen"
                }
            ]
            current: Config.controlPanel.recordingMode
            onSelected: v => Config.controlPanel.recordingMode = v
        }
    }

    SectionLabel {
        text: "Night light"
    }

    SettingRow {
        title: "Colour temperature"
        description: "Used by hyprsunset. Re-toggle Night Light after changing this."

        ValueSlider {
            from: 2000
            to: 6000
            step: 100
            suffix: " K"
            value: Config.controlPanel.nightLightTemp
            onMoved: v => Config.controlPanel.nightLightTemp = Math.round(v)
        }
    }
}
