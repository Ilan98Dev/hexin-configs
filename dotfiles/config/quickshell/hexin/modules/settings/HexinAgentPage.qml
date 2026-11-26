import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// Settings > HexinAgent.
//
// The universal switch and the per-feature policy live here, in the shell
// settings app — not inside the agent's own window. The daemon receives the
// same feature map with every request and removes or refuses the matching
// tools, so turning a feature off here is a real limit, not just hidden UI.
SettingsPage {
    id: root

    readonly property var ua: Config.hexinAgent
    readonly property bool agentOn: ua.enabled
    readonly property real lastCheck: (HexinAgent.settings.lastUpdateCheck || 0)

    function lastCheckLabel() {
        if (!lastCheck)
            return "Never checked";
        return "Last checked " + new Date(lastCheck).toLocaleString();
    }

    title: "HexinAgent"
    subtitle: "The built-in assistant: one master switch and the powers it is allowed to use."

    SectionLabel {
        text: "Agent"
    }

    SettingRow {
        title: "Enable HexinAgent"
        description: "Universal switch. When off, the agent will not answer, run tools or show its neon frame, and SUPER + T only reminds you that it is off. Everything below stays configured for when you turn it back on."

        Toggle {
            checked: root.ua.enabled
            onToggled: v => root.ua.enabled = v
        }
    }

    SettingRow {
        title: "Model & API key"
        description: HexinAgent.modelReady
            ? (HexinAgent.provider ? HexinAgent.provider.name : "Provider") + " · " + (HexinAgent.settings.model || "no model")
            : "Not ready — open the agent settings to pick a provider, model and key."

        Rectangle {
            implicitWidth: modelLbl.implicitWidth + 24
            implicitHeight: 32
            radius: Theme.radiusSmall
            color: modelMa.containsMouse ? Theme.accent : Theme.surfaceHi

            Behavior on color {
                ColorAnimation {
                    duration: Theme.animFast
                }
            }

            Txt {
                id: modelLbl
                anchors.centerIn: parent
                text: "Open agent settings"
                color: modelMa.containsMouse ? Theme.onAccent : Theme.text
            }
            MouseArea {
                id: modelMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Panels.settingsOpen = false;
                    HexinAgent.open();
                    HexinAgent.showSettings();
                }
            }
        }
    }

    SectionLabel {
        text: "Features"
    }

    Txt {
        Layout.fillWidth: true
        Layout.bottomMargin: 2
        text: root.agentOn
            ? "Each switch removes a tool from the agent. The model is told what is off, and the daemon refuses it even if the model asks anyway."
            : "HexinAgent is off. These switches keep their values and take effect when you turn the agent back on."
        color: Theme.subtext
        font.pixelSize: Theme.fontSmall + 1
        wrapMode: Text.Wrap
        opacity: 0.9
    }

    SettingRow {
        opacity: root.agentOn ? 1 : 0.55
        title: "Coding projects"
        description: "Create projects under ~/Projects/HexinAgent and build or test them with a project working directory."

        Toggle {
            checked: root.ua.projects
            onToggled: v => root.ua.projects = v
        }
    }

    SettingRow {
        opacity: root.agentOn ? 1 : 0.55
        title: "Run shell commands"
        description: "The run_command tool. Every command still needs your approval before it runs."

        Toggle {
            checked: root.ua.commands
            onToggled: v => root.ua.commands = v
        }
    }

    SettingRow {
        opacity: root.agentOn ? 1 : 0.55
        title: "File changes"
        description: "Write and edit files. Read-only file access stays available either way."

        Toggle {
            checked: root.ua.files
            onToggled: v => root.ua.files = v
        }
    }

    SettingRow {
        opacity: root.agentOn ? 1 : 0.55
        title: "Package management"
        description: "Install, remove or upgrade packages with pacman, yay, paru and similar tools. Non-package commands are unaffected."

        Toggle {
            checked: root.ua.packages
            onToggled: v => root.ua.packages = v
        }
    }

    SettingRow {
        opacity: root.agentOn ? 1 : 0.55
        title: "Web access"
        description: "Fetch pages and search the web."

        Toggle {
            checked: root.ua.web
            onToggled: v => root.ua.web = v
        }
    }

    SettingRow {
        opacity: root.agentOn ? 1 : 0.55
        title: "Screen capture"
        description: "Take a screenshot when a visual check helps."

        Toggle {
            checked: root.ua.screenshots
            onToggled: v => root.ua.screenshots = v
        }
    }

    SettingRow {
        opacity: root.agentOn ? 1 : 0.55
        title: "Mouse control"
        description: "See the screen and drive the pointer, clicks and scrolling with ydotool. Clicks always ask for approval. Requires the ydotool service, which the installer sets up."

        Toggle {
            checked: root.ua.mouse
            onToggled: v => root.ua.mouse = v
        }
    }

    SectionLabel {
        text: "System errors"
    }

    SettingRow {
        opacity: root.agentOn ? 1 : 0.55
        title: "Fix crashes and failed services with AI"
        description: "Watch for application crashes (coredumps) and failed systemd units. A notification appears with a Fix with AI button that opens the chat with the crash details already filled in. Nothing is run or changed without your approval."

        Toggle {
            checked: root.ua.systemErrors
            onToggled: v => root.ua.systemErrors = v
        }
    }

    SectionLabel {
        text: "Weekly update check"
    }

    SettingRow {
        opacity: root.agentOn ? 1 : 0.55
        title: "Check for package updates"
        description: "Once a week, check for pending updates in the background (read-only: checkupdates or pacman -Qu) and tell you what is available. Nothing is installed without your approval."

        Toggle {
            checked: root.ua.weeklyUpdates
            onToggled: v => root.ua.weeklyUpdates = v
        }
    }

    SettingRow {
        title: "Run a check now"
        description: HexinAgent.updateCheckRunning
            ? "Checking the repositories…"
            : (HexinAgent.updateSummary.length ? HexinAgent.updateSummary + " · " + root.lastCheckLabel() : root.lastCheckLabel())

        Rectangle {
            implicitWidth: checkLbl.implicitWidth + 24
            implicitHeight: 32
            radius: Theme.radiusSmall
            color: HexinAgent.updateCheckRunning
                ? Theme.surfaceHi
                : (checkMa.containsMouse ? Theme.accent : Theme.surfaceHi)

            Behavior on color {
                ColorAnimation {
                    duration: Theme.animFast
                }
            }

            Txt {
                id: checkLbl
                anchors.centerIn: parent
                text: HexinAgent.updateCheckRunning ? "Checking…" : "Check now"
                color: checkMa.containsMouse && !HexinAgent.updateCheckRunning ? Theme.onAccent : Theme.text
            }
            MouseArea {
                id: checkMa
                anchors.fill: parent
                enabled: !HexinAgent.updateCheckRunning
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: HexinAgent.runUpdateCheck()
            }
        }
    }

    SectionLabel {
        text: "Notes"
    }

    Txt {
        Layout.fillWidth: true
        Layout.bottomMargin: 8
        text: "Policy is enforced by the agent daemon. Read-only tools still run without an approval card; commands, file writes and project creation always ask first. API keys and chat history stay in the agent's own state folder and are never stored in the shell settings."
        color: Theme.subtext
        font.pixelSize: Theme.fontSmall + 1
        wrapMode: Text.Wrap
        opacity: 0.85
    }
}
