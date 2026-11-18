import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// One transparent full-screen overlay per monitor that hosts every dropdown
// panel (control centre, notification drawer, calendar, launcher, clipboard
// history, wallpaper picker, keybind cheatsheet). Clicking outside, or pressing
// Esc, closes it. The launcher, clipboard history, wallpaper picker and
// keybind cheatsheet take an exclusive keyboard focus so typing (or the arrow
// keys) goes to the panel instead of the window underneath.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property var modelData

        readonly property bool wanted: Panels.active !== "" && Panels.screenName === modelData.name
        property string shown: "control"
        // The surface is mapped before the reveal animation starts; animating
        // from the same frame as the map would finish before it is on screen.
        property bool revealed: false
        readonly property bool atTop: Config.bar.position === "top" || !Config.bar.enabled
        readonly property int edgeGap: Config.bar.enabled ? Panels.barSize + 4 : 12
        // The control panel carries the most sections (recording, stats, …);
        // give it a few extra pixels so it scrolls a little later than the
        // other panels.
        readonly property int maxH: height - edgeGap - (win.shown === "control" ? 6 : 16)

        // Panels that take typed input (search fields) or drive themselves
        // with the keyboard need the keyboard exclusively while they are open.
        readonly property bool typing: win.shown === "launcher" || win.shown === "clipboard" || win.shown === "wallpaper" || win.shown === "keybinds"
        // Hang these off the right edge of the screen, under their bar button.
        readonly property bool rightAligned: win.shown === "control" || win.shown === "notifications"

        function componentFor(name) {
            if (name === "notifications")
                return ncComp;
            if (name === "calendar")
                return calComp;
            if (name === "wallpaper")
                return wpComp;
            if (name === "launcher")
                return launchComp;
            if (name === "clipboard")
                return clipComp;
            if (name === "keybinds")
                return keybindsComp;
            return controlComp;
        }

        screen: modelData
        visible: wanted || host.opacity > 0.01
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-panels"
        WlrLayershell.keyboardFocus: wanted ? (win.typing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand) : WlrKeyboardFocus.None

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Connections {
            target: Panels
            function onActiveChanged() {
                if (Panels.active !== "")
                    win.shown = Panels.active;
            }
        }

        onWantedChanged: {
            if (wanted) {
                revealTimer.restart();
            } else {
                revealed = false;
            }
        }

        Timer {
            id: revealTimer
            interval: 16
            onTriggered: if (win.wanted) win.revealed = true
        }

        // Esc to close (typing panels handle Esc themselves)
        Item {
            anchors.fill: parent
            focus: win.wanted && !win.typing
            Keys.onEscapePressed: Panels.close()
        }

        // Click outside to close
        MouseArea {
            anchors.fill: parent
            onClicked: mouse => {
                // don't close if the click landed on the panel itself (the loader)
                if (loader.contains(mapToItem(loader, mouse.x, mouse.y)))
                    return;
                Panels.close();
            }
        }

        Item {
            id: host
            anchors.fill: parent
            opacity: win.revealed ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.anim
                    easing.type: Easing.OutCubic
                }
            }

            Loader {
                id: loader
                active: win.visible
                sourceComponent: win.componentFor(win.shown)
                focus: true

                // right-aligned for the control panel and the notification
                // drawer, centred for the clock's calendar, the launcher,
                // the clipboard, the wallpaper picker and the keybinds list
                x: win.rightAligned ? win.width - width - 12 : Math.round((win.width - width) / 2)
                y: (win.shown === "wallpaper" || win.shown === "keybinds") ? Math.round((win.height - height) / 2) : (win.atTop ? win.edgeGap : win.height - height - win.edgeGap)

                // A small bloom as the panel appears, and a quick fade when the
                // open panel is swapped for another one.
                scale: win.revealed ? 1 : 0.96

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.anim
                        easing.type: Easing.OutCubic
                    }
                }

                Connections {
                    target: win
                    function onShownChanged() {
                        if (win.wanted)
                            swapFade.restart();
                    }
                }

                SequentialAnimation {
                    id: swapFade
                    NumberAnimation {
                        target: loader
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Theme.anim
                        easing.type: Easing.OutCubic
                    }
                }

                transform: Translate {
                    y: win.revealed ? 0 : (win.atTop ? -14 : 14)

                    Behavior on y {
                        NumberAnimation {
                            duration: Theme.anim
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }

        Component {
            id: controlComp
            ControlPanel {
                maxHeight: win.maxH
            }
        }

        Component {
            id: ncComp
            NotificationCenter {
                maxHeight: win.maxH
            }
        }

        Component {
            id: calComp
            CalendarPanel {
                maxHeight: win.maxH
            }
        }

        Component {
            id: wpComp
            WallpaperPicker {
                maxHeight: win.maxH
            }
        }

        Component {
            id: launchComp
            Launcher {
                maxHeight: win.maxH
            }
        }

        Component {
            id: clipComp
            ClipboardPanel {
                maxHeight: win.maxH
            }
        }

        Component {
            id: keybindsComp
            KeybindsPanel {
                maxHeight: win.maxH
            }
        }
    }
}
