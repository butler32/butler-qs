import QtQuick
import Quickshell
import "../theme"
import "../i18n"
import "../config"

// Настраивается через Меню → Конфигурация → Часы. Клик открывает календарь.
Panel {
    id: root
    readonly property var c: Config.clock
    property alias clock: clock

    SystemClock { id: clock; precision: root.c.showSeconds ? SystemClock.Seconds : SystemClock.Minutes }

    Label { text: ""; color: Theme.accent }
    Label {
        visible: root.c.showDate
        text: clock.date.toLocaleDateString(Qt.locale(I18n.locale), "ddd d MMM")
        color: Theme.textDim
    }
    Label {
        text: Qt.formatDateTime(clock.date, root.c.showSeconds ? "HH:mm:ss" : "HH:mm")
        font.bold: true
    }

    overlay: MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: calendar.toggle()
    }

    CalendarPopup {
        id: calendar
        anchorItem: root
        ipcName: "clock"
        screen: root.QsWindow.window?.screen ?? null
        now: clock.date
    }
}
