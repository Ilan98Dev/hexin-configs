import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// Scrollable page with a title. Children go into the content column.
Flickable {
    id: root

    property string title: ""
    property string subtitle: ""
    default property alias content: col.data

    contentHeight: col.implicitHeight + 48
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: col
        x: 28
        y: 24
        width: root.width - 56
        spacing: 4

        Txt {
            text: root.title
            font.pixelSize: Theme.fontLarge + 8
            font.bold: true
            Layout.fillWidth: true
        }
        Txt {
            text: root.subtitle
            color: Theme.subtext
            wrapMode: Text.Wrap
            Layout.fillWidth: true
            Layout.bottomMargin: 14
        }
    }
}
