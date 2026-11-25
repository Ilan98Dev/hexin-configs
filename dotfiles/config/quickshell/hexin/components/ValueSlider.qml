import QtQuick
import QtQuick.Layouts
import qs.config

// Slider with a numeric read-out, for the settings app.
RowLayout {
    id: root

    property real value: 0
    property real from: 0
    property real to: 100
    property real step: 1
    property int decimals: 0
    property string suffix: ""

    signal moved(real newValue)

    spacing: 12

    SliderBar {
        Layout.preferredWidth: 200
        value: root.value
        from: root.from
        to: root.to
        step: root.step
        onMoved: v => root.moved(v)
    }
    Txt {
        text: root.value.toFixed(root.decimals) + root.suffix
        color: Theme.subtext
        horizontalAlignment: Text.AlignRight
        Layout.preferredWidth: 56
    }
}
