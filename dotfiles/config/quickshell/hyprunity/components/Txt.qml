import QtQuick
import qs.config

Text {
    color: Theme.text
    font.family: Theme.font
    font.pixelSize: Theme.fontSize
    verticalAlignment: Text.AlignVCenter

    // Theme changes and state colours (active, danger, subtext) glide instead
    // of snapping.
    Behavior on color {
        ColorAnimation {
            duration: Theme.animFast
        }
    }
}
