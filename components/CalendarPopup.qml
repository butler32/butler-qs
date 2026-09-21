import QtQuick
import QtQuick.Layouts
import "../theme"
import "../i18n"
import "../config"

// Календарь месяца; начало недели — Config.clock.weekStartsMonday.
BarPopup {
    id: pop
    align: "center"
    property date now: new Date()
    property int viewYear: now.getFullYear()
    property int viewMonth: now.getMonth()
    readonly property var loc: Qt.locale(I18n.locale)
    readonly property int startDay: Config.clock.weekStartsMonday ? 1 : 0

    onOpenChanged: if (open) { viewYear = now.getFullYear(); viewMonth = now.getMonth() }
    function shift(d) {
        const m = viewMonth + d
        viewYear += Math.floor(m / 12)
        viewMonth = ((m % 12) + 12) % 12
    }

    // шапка: ‹ Месяц год ›
    RowLayout {
        Layout.fillWidth: true
        Chip { icon: ""; onClicked: pop.shift(-1) }
        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: pop.loc.monthName(pop.viewMonth, Locale.LongFormat) + " " + pop.viewYear
            font.bold: true
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { pop.viewYear = pop.now.getFullYear(); pop.viewMonth = pop.now.getMonth() }
            }
        }
        Chip { icon: ""; onClicked: pop.shift(1) }
    }

    Grid {
        Layout.alignment: Qt.AlignHCenter
        columns: 7
        spacing: 2

        Repeater {
            model: 7
            delegate: Label {
                required property int index
                width: 36; height: 24
                horizontalAlignment: Text.AlignHCenter
                text: pop.loc.dayName((pop.startDay + index) % 7, Locale.ShortFormat)
                color: Theme.textDim
                font.pixelSize: Theme.fontSize - 2
            }
        }
        Repeater {
            model: 42
            delegate: Rectangle {
                id: cell
                required property int index
                readonly property date day: {
                    const first = new Date(pop.viewYear, pop.viewMonth, 1)
                    const offset = (first.getDay() - pop.startDay + 7) % 7
                    return new Date(pop.viewYear, pop.viewMonth, 1 - offset + index)
                }
                readonly property bool inMonth: day.getMonth() === pop.viewMonth
                readonly property bool today: day.getFullYear() === pop.now.getFullYear()
                    && day.getMonth() === pop.now.getMonth() && day.getDate() === pop.now.getDate()
                width: 36; height: 30
                radius: Theme.radiusItem
                color: today ? Theme.accent : "transparent"
                Label {
                    anchors.centerIn: parent
                    text: cell.day.getDate()
                    color: cell.today ? Theme.accentText : cell.inMonth ? Theme.text : Theme.textDim
                    opacity: cell.inMonth || cell.today ? 1 : 0.5
                    font.bold: cell.today
                }
            }
        }
    }
}
