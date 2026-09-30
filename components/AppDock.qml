import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../theme"
import "../config"
import "../services"

// Иконки закреплённых приложений (Меню → Конфигурация → Иконки приложений).
// Клик: запустить, а если окно уже есть — перейти к нему.
Panel {
    id: root
    wanted: Config.apps.pinned.length > 0

    Repeater {
        model: Config.apps.pinned
        delegate: Item {
            id: cell
            required property string modelData
            // обращение к applications.values нужно для реактивности: записи подгружаются асинхронно
            readonly property var entry: {
                DesktopEntries.applications.values
                return DesktopEntries.byId(modelData) ?? DesktopEntries.heuristicLookup(modelData)
            }
            readonly property var wins: Windows.matching([modelData, entry?.startupClass, entry?.name])
            readonly property bool running: wins.length > 0
            readonly property bool focused: wins.some(w => w.activated)

            Layout.preferredWidth: 24
            Layout.preferredHeight: 24

            Image {
                anchors.centerIn: parent
                width: 20; height: 20
                sourceSize: Qt.size(48, 48)
                source: cell.entry ? Quickshell.iconPath(cell.entry.icon, "application-x-executable") : ""
                opacity: cell.running ? 1 : 0.7
            }
            // индикатор запущенного окна
            Rectangle {
                visible: cell.running
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: -3
                width: cell.focused ? 10 : 4
                height: 3
                radius: Math.min(Theme.radiusItem, 1.5)
                color: cell.focused ? Theme.accent : Theme.textDim
                Behavior on width { NumberAnimation { duration: 120 } }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (cell.running) Windows.focus(cell.wins[0])
                    else if (cell.entry)
                        cell.entry.execute()
                }
            }
        }
    }
}
