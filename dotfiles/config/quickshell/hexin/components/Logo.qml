import QtQuick
import qs.config

// The Hexin brand mark.
//
// By default it draws the bundled star logo (assets/logo.png). Callers that
// have their own "ASCII" logo can pass `useImage: false` and a `glyph`; the bar
// launcher does this when Config.bar.launcherIcon is set.
//
// Callers size the mark and, for the glyph fallback, choose which glyph and
// colour to use. The plate behind it (if any) stays in the caller, so the same
// mark can sit on the bar pill, the HexinAgent sidebar or a card.
Item {
    id: root

    property int size: 24
    // Leave true for the image; set false to draw the glyph instead.
    property bool useImage: true
    property string glyph: Icons.rocket
    property color glyphColor: Theme.accent
    property int glyphSize: Math.round(size * 0.62)

    implicitWidth: size
    implicitHeight: size

    Image {
        anchors.fill: parent
        visible: root.useImage
        source: Qt.resolvedUrl("../assets/logo.png")
        sourceSize.width: Math.max(64, root.size * 2)
        sourceSize.height: Math.max(64, root.size * 2)
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
    }

    Glyph {
        anchors.centerIn: parent
        visible: !root.useImage
        text: root.glyph
        color: root.glyphColor
        font.pixelSize: root.glyphSize
    }
}
