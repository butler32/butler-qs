import QtQuick
import Quickshell
import "../theme"
import "../i18n"

Panel {
    SystemClock { id: clock; precision: SystemClock.Seconds }

    Label { text: ""; color: Theme.accent }
    Label { text: clock.date.toLocaleDateString(Qt.locale(I18n.locale), "ddd d MMM"); color: Theme.textDim }
    Label { text: Qt.formatDateTime(clock.date, "HH:mm"); font.bold: true }
}
