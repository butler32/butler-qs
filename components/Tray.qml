import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import "../theme"
import "../config"

// Системный трей (StatusNotifierItem). Клик — действие приложения, правый — его меню,
// средний — второе действие. Настройки — Меню → Конфигурация → Трей.
Panel {
    id: root
    property bool expanded: false
    readonly property bool collapsed: Config.tray.collapsed
    readonly property var items: SystemTray.items.values.filter(i => i.status !== Status.Passive)

    wanted: items.length > 0

    Repeater {
        model: root.items
        delegate: Item {
            id: cell
            required property var modelData
            visible: !root.collapsed || root.expanded
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20

            Image {
                anchors.centerIn: parent
                width: 18; height: 18
                sourceSize: Qt.size(48, 48)
                source: cell.modelData.icon
                // приложению нужно внимание — значок не приглушается
                opacity: cell.modelData.status === Status.NeedsAttention ? 1 : 0.85
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    const t = cell.modelData
                    const p = cell.mapToItem(null, 0, cell.height)
                    if (mouse.button === Qt.MiddleButton) t.secondaryActivate()
                    else if (mouse.button === Qt.RightButton || t.onlyMenu) {
                        if (t.hasMenu) t.display(root.QsWindow.window, p.x, p.y)
                    } else t.activate()
                }
            }
        }
    }

    // Развернуть / свернуть
    Label {
        visible: root.collapsed
        text: ""
        color: Theme.textDim
        rotation: root.expanded ? 180 : 0
        Behavior on rotation { NumberAnimation { duration: 150 } }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -Theme.gap / 2
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }
}
