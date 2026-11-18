import QtQuick
import qs.config

// An icon-font glyph. Use with `text: Icons.wifi`.
//
// Note: Nerd Font icon glyphs are wider than their monospace advance, so we
// must NOT use horizontalAlignment: Text.AlignHCenter — that centres the
// (narrow) advance box and pushes the visible ink off to the right. Left
// alignment draws the ink from x=0 and the item's implicit width is the ink
// width, so layouts centre the ink correctly. Vertical centring is safe
// because the ink fits inside the line box.
Text {
    color: Theme.text
    font.family: Theme.iconFont
    font.pixelSize: Theme.iconSize
    verticalAlignment: Text.AlignVCenter

    Behavior on color {
        ColorAnimation {
            duration: Theme.animFast
        }
    }
}
