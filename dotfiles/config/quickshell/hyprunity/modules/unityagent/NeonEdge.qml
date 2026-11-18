import QtQuick
import qs.config

// One neon strip hugging a screen edge.
//
// A dim static glow (wide halo, inner bloom, hot core) keeps the frame
// readable while the agent is idle. On top of it a fragment shader paints a
// real travelling sine wave, so the light swells and fades along the edge
// instead of being a single moving blob. The agent dims the static glow while
// the wave runs so the movement stands out.
//
// `horizontal` turns it into a top/bottom strip; `flip` moves the glow to the
// opposite screen edge (right / bottom).
Item {
    id: root

    property bool horizontal: false
    property bool flip: false
    // Gentle idle breathing. The wave takes over when the agent is busy.
    property bool breathe: true
    // Scales the static glow. Lowered while a wave is running.
    property real baseOpacity: 1

    // ───────────── wave ─────────────
    // 0..4, one unit per edge, clockwise from the top-left corner.
    property real wavePhase: 0
    // Integer, so neighbouring edges meet in phase at the corners.
    property int waveCycles: 2
    property real waveAmp: 0
    property real waveBase: 0
    // -1 on the left/bottom edge so the wave travels clockwise there too.
    property real waveSign: 1

    readonly property real stripPx: horizontal ? height : width
    // How far the wave glow reaches in from the screen edge, in pixels.
    readonly property real waveDepth: Math.min(34, stripPx)
    readonly property bool waveOn: waveAmp > 0.001 || waveBase > 0.001

    Item {
        id: staticGlow

        anchors.fill: parent
        opacity: root.baseOpacity

        Behavior on opacity {
            NumberAnimation {
                duration: Math.max(120, Theme.anim)
                easing.type: Easing.OutCubic
            }
        }

        // wide ambient halo, fading out towards the middle of the screen
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: root.horizontal ? Gradient.Vertical : Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: root.flip ? Qt.alpha(Theme.accent, 0) : Qt.alpha(Theme.accent, 0.16)
                }
                GradientStop {
                    position: 0.5
                    color: Qt.alpha(Theme.accent, 0.05)
                }
                GradientStop {
                    position: 1
                    color: root.flip ? Qt.alpha(Theme.accent, 0.16) : Qt.alpha(Theme.accent, 0)
                }
            }
        }

        // inner bloom
        Rectangle {
            width: root.horizontal ? root.width : 34
            height: root.horizontal ? 34 : root.height
            x: root.horizontal ? 0 : (root.flip ? root.width - width : 0)
            y: root.horizontal ? (root.flip ? root.height - height : 0) : 0
            gradient: Gradient {
                orientation: root.horizontal ? Gradient.Vertical : Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: root.flip ? Qt.alpha(Theme.accent, 0) : Qt.alpha(Theme.accent, 0.58)
                }
                GradientStop {
                    position: 0.28
                    color: root.flip ? Qt.alpha(Theme.accent, 0) : Qt.alpha(Theme.accent, 0.22)
                }
                GradientStop {
                    position: 0.72
                    color: root.flip ? Qt.alpha(Theme.accent, 0.22) : Qt.alpha(Theme.accent, 0)
                }
                GradientStop {
                    position: 1
                    color: root.flip ? Qt.alpha(Theme.accent, 0.58) : Qt.alpha(Theme.accent, 0)
                }
            }
        }

        // hot core line
        Rectangle {
            width: root.horizontal ? root.width : 2
            height: root.horizontal ? 2 : root.height
            x: root.horizontal ? 0 : (root.flip ? root.width - width : 0)
            y: root.horizontal ? (root.flip ? root.height - height : 0) : 0
            color: Theme.accent
        }
    }

    // The actual wave. Premultiplied output, blended over the static glow.
    ShaderEffect {
        anchors.fill: parent
        visible: root.waveOn
        blending: true

        property color accent: Theme.accent
        property real phase: root.wavePhase
        property real cycles: root.waveCycles
        property real amp: root.waveAmp
        property real base: root.waveBase
        property real vertical: root.horizontal ? 0 : 1
        property real flip: root.flip ? 1 : 0
        property real uSign: root.waveSign
        property real stripPx: root.stripPx
        property real depth: root.waveDepth

        fragmentShader: "neonwave.frag.qsb"
    }

    // Gentle breathing so the strip feels alive instead of painted on.
    SequentialAnimation on opacity {
        running: Theme.anim > 0 && root.breathe
        loops: Animation.Infinite
        NumberAnimation {
            to: 0.78
            duration: 3200
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            to: 1
            duration: 3200
            easing.type: Easing.InOutSine
        }
    }

    // Leaving the animation mid-cycle would freeze the strip at 0.78.
    onBreatheChanged: if (!breathe)
        opacity = 1
}
