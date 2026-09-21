import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../theme"
import "../config"

// Иконки закреплённых приложений (Меню → Конфигурация → Иконки приложений).
// Клик: запустить, а если окно уже есть — перейти к нему.
Panel {
    id: root
    visible: Config.apps.pinned.length > 0

    function norm(s) { return (s ?? "").toLowerCase().replace(/\.desktop$/, "").replace(/[^a-z0-9]/g, "") }

    // окна приложения: по id .desktop, StartupWMClass или имени
    function windowsOf(id, entry) {
        const keys = [norm(id), norm(entry?.startupClass), norm(entry?.name)].filter(k => k.length > 1)
        return Hyprland.toplevels.values.filter(t => {
            const c = [norm(t.lastIpcObject?.class), norm(t.lastIpcObject?.initialClass)].filter(x => x.length > 1)
            return c.some(x => keys.some(k => x === k || x.endsWith(k) || k.endsWith(x)))
        })
    }

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
            readonly property var wins: root.windowsOf(modelData, entry)
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
                    if (cell.running) {
                        const a = cell.wins[0].address
                        Hyprland.dispatch("hl.dsp.focus({ window = \"address:" + (a.startsWith("0x") ? a : "0x" + a) + "\" })")
                    }
                    else if (cell.entry)
                        cell.entry.execute()
                }
            }
        }
    }
}
