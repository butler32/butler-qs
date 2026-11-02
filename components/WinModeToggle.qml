import QtQuick
import QtQuick.Layouts
import "../theme"
import "../i18n"
import "../services"

// Переключатель тайлинг ⇄ оконный режим (services/WinMode.qml).
Panel {
    id: root
    implicitWidth: Theme.barHeight

    Label {
        text: WinMode.windowed ? "" : ""
        color: WinMode.windowed ? Theme.accent : Theme.text
        opacity: WinMode.busy ? 0.5 : 1
        Layout.alignment: Qt.AlignCenter
    }
    overlay: MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: WinMode.toggle()
    }
}
