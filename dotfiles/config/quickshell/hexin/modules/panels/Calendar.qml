import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

ColumnLayout {
    id: root

    property int year: Time.date.getFullYear()
    property int month: Time.date.getMonth()

    readonly property bool mon: Config.general.weekStartsMonday
    readonly property var dayNames: mon ? ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"] : ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
    readonly property int offset: {
        const first = new Date(year, month, 1).getDay();
        return mon ? (first + 6) % 7 : first;
    }

    function shift(delta) {
        const d = new Date(year, month + delta, 1);
        year = d.getFullYear();
        month = d.getMonth();
    }

    function today() {
        year = Time.date.getFullYear();
        month = Time.date.getMonth();
    }

    spacing: 6

    onMonthChanged: monthAnim.restart()
    onYearChanged: monthAnim.restart()

    RowLayout {
        Layout.fillWidth: true

        IconButton {
            glyph: Icons.chevronLeft
            size: 28
            glyphSize: Theme.fontSmall
            onClicked: root.shift(-1)
        }
        Txt {
            text: Qt.formatDate(new Date(root.year, root.month, 1), "MMMM yyyy")
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.today()
            }
        }
        IconButton {
            glyph: Icons.chevronRight
            size: 28
            glyphSize: Theme.fontSmall
            onClicked: root.shift(1)
        }
    }

    GridLayout {
        id: dayGrid
        Layout.fillWidth: true
        columns: 7
        columnSpacing: 0
        rowSpacing: 2

        transform: Translate {
            id: dayShift
        }

        Repeater {
            model: root.dayNames

            Txt {
                required property string modelData
                text: modelData
                color: Theme.subtext
                font.pixelSize: Theme.fontSmall
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
                Layout.preferredWidth: 1
            }
        }

        Repeater {
            model: 42

            Rectangle {
                id: cell

                required property int index
                readonly property date d: new Date(root.year, root.month, index - root.offset + 1)
                readonly property bool inMonth: d.getMonth() === root.month
                readonly property bool isToday: d.getDate() === Time.date.getDate() && d.getMonth() === Time.date.getMonth() && d.getFullYear() === Time.date.getFullYear()

                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: 28
                radius: Theme.radiusSmall
                color: isToday ? Theme.accent : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.animFast
                    }
                }

                Txt {
                    anchors.centerIn: parent
                    text: cell.d.getDate()
                    color: cell.isToday ? Theme.onAccent : (cell.inMonth ? Theme.text : Qt.alpha(Theme.subtext, 0.45))
                    font.bold: cell.isToday
                    font.pixelSize: Theme.fontSmall + 1
                }
            }
        }
    }

    SequentialAnimation {
        id: monthAnim
        ParallelAnimation {
            NumberAnimation {
                target: dayGrid
                property: "opacity"
                from: 0.3
                to: 1
                duration: Theme.anim
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: dayShift
                property: "y"
                from: 5
                to: 0
                duration: Theme.anim
                easing.type: Easing.OutCubic
            }
        }
    }
}
