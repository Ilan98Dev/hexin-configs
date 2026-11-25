import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// Ambient neon edge lighting, one surface per monitor.
//
// It fades in while the HexinAgent window is open and fades out when it
// closes. The surface is a click-through overlay (empty input region), so it
// never steals focus or blocks the desktop underneath.
//
// While the agent is thinking a bright sine wave travels clockwise around the
// frame. While the reply streams in the wave softens and raises its floor, so
// the whole border swells and fades instead of going dark between peaks. When
// the agent is idle the base glow just breathes gently.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property var modelData

        screen: modelData
        color: "transparent"

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        focusable: false
        mask: Region {}

        // Stay mapped only while needed; the fade-out keeps it alive for one
        // animation before the compositor unmaps it.
        property bool active: false
        visible: active

        // The bar is on the Top layer too. Within a layer the surface created
        // last stacks on top, and this one is created after Bar in shell.qml,
        // so the frame draws over the bar instead of stopping underneath it.
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "qs-agent-neon"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        readonly property bool thinking: HexinAgent.busy && !HexinAgent.streaming
        readonly property bool responding: HexinAgent.streaming
        readonly property bool animOn: Theme.anim > 0

        // 0..4, one unit per edge, clockwise from the top-left corner.
        property real phase: 0

        NumberAnimation on phase {
            from: 0
            to: 4
            duration: 5200
            loops: Animation.Infinite
            running: win.animOn && win.active
        }

        // Wave shape per agent state. Thinking is a bright travelling wave;
        // responding keeps travelling but its crests swell and fade, so the
        // frame reads as waves rising and falling instead of a constant
        // ripple. `phase` runs 0..4, giving three swells per loop.
        readonly property bool busyWave: win.thinking || win.responding
        readonly property real respondPulse: 0.5 + 0.5 * Math.sin(1.5 * Math.PI * win.phase)
        readonly property real waveAmp: !win.animOn ? 0 : (win.thinking ? 0.94 : (win.responding ? 0.12 + 0.86 * win.respondPulse : 0))
        readonly property real waveBase: !win.animOn ? 0 : (win.thinking ? 0.05 : (win.responding ? 0.18 : 0))
        readonly property int waveCycles: win.responding ? 3 : 2

        Item {
            id: glow
            anchors.fill: parent
            opacity: 0

            NeonEdge {
                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                }
                width: 96
                waveSign: -1
                breathe: win.active && !win.busyWave
                baseOpacity: win.busyWave ? 0.3 : 1
                wavePhase: win.phase
                waveCycles: win.waveCycles
                waveAmp: win.waveAmp
                waveBase: win.waveBase
            }

            NeonEdge {
                anchors {
                    right: parent.right
                    top: parent.top
                    bottom: parent.bottom
                }
                width: 96
                flip: true
                waveSign: 1
                breathe: win.active && !win.busyWave
                baseOpacity: win.busyWave ? 0.3 : 1
                wavePhase: win.phase
                waveCycles: win.waveCycles
                waveAmp: win.waveAmp
                waveBase: win.waveBase
            }

            NeonEdge {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                }
                height: 22
                horizontal: true
                waveSign: 1
                breathe: win.active && !win.busyWave
                baseOpacity: win.busyWave ? 0.3 : 1
                wavePhase: win.phase
                waveCycles: win.waveCycles
                waveAmp: win.waveAmp
                waveBase: win.waveBase
            }

            NeonEdge {
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                height: 22
                horizontal: true
                flip: true
                waveSign: -1
                breathe: win.active && !win.busyWave
                baseOpacity: win.busyWave ? 0.3 : 1
                wavePhase: win.phase
                waveCycles: win.waveCycles
                waveAmp: win.waveAmp
                waveBase: win.waveBase
            }
        }

        NumberAnimation {
            id: fade

            target: glow
            property: "opacity"
            duration: Math.max(180, Theme.anim + 90)
            easing.type: Easing.InOutSine

            onFinished: if (!HexinAgent.visible || !HexinAgent.enabled)
                win.active = false
        }

        function sync() {
            if (HexinAgent.visible && HexinAgent.enabled) {
                win.active = true;
                if (Theme.anim <= 0) {
                    glow.opacity = 1;
                    return;
                }
                fade.stop();
                fade.to = 1;
                fade.restart();
            } else {
                if (Theme.anim <= 0) {
                    glow.opacity = 0;
                    win.active = false;
                    return;
                }
                fade.stop();
                fade.to = 0;
                fade.restart();
            }
        }

        Connections {
            target: HexinAgent
            function onVisibleChanged() {
                win.sync();
            }
            function onEnabledChanged() {
                win.sync();
            }
        }

        Component.onCompleted: sync()
    }
}
