import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../theme"
import "../config"
import "../services"

// Настраивается через Меню → Конфигурация → Воркспейсы (см. Config.ws).
Panel {
    id: root
    readonly property var w: Config.ws
    property bool expanded: false
    readonly property int focusedId: Hyprland.focusedWorkspace?.id ?? -1

    readonly property var allIds: {
        const ids = new Set()
        for (let i = 1; i <= w.total; i++) ids.add(i)
        for (const ws of Hyprland.workspaces.values) if (ws.id > 0) ids.add(ws.id)
        return [...ids].sort((a, b) => a - b)
    }

    function occupied(id) {
        const ws = Hyprland.workspaces.values.find(x => x.id === id)
        return (ws?.toplevels?.values?.length ?? 0) > 0
    }
    // В свёрнутом виде: первые N, занятые (если включено) и текущий
    function pinned(id) {
        return id <= w.visibleCount || id === focusedId || (w.showOccupied && occupied(id))
    }
    function shown(id) { return !w.collapsible || expanded || pinned(id) }
    readonly property bool hasHidden: allIds.some(id => !pinned(id))

    Repeater {
        model: root.allIds
        delegate: Rectangle {
            id: cell
            required property int modelData
            readonly property int wsId: modelData
            readonly property bool active: root.focusedId === wsId
            readonly property bool occupied: root.occupied(wsId)
            readonly property bool notified: root.w.notifyHighlight && !!Notifs.pending[wsId]
            readonly property string spec: root.w.icons[wsId] ?? root.w.defaultStyle
            readonly property string kind: spec.startsWith("icon:") ? "icon" : spec
            readonly property real box: Theme.workspaceDot * 2.2

            visible: root.shown(wsId)
            Layout.preferredHeight: kind === "dot" ? Theme.workspaceDot : box
            Layout.preferredWidth: kind === "dot" ? (active ? Theme.workspaceDot * 2.4 : Theme.workspaceDot) : box
            radius: Math.min(Theme.radiusItem, height / 2)
            color: notified ? Theme.notify
                 : active ? Theme.accent
                 : kind === "dot" ? (occupied ? Theme.text : Theme.surfaceAlt)
                 : "transparent"
            Behavior on Layout.preferredWidth { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 150 } }

            Label {
                anchors.centerIn: parent
                visible: cell.kind === "number"
                text: cell.wsId
                font.bold: cell.active
                color: cell.notified || cell.active ? Theme.accentText : cell.occupied ? Theme.text : Theme.textDim
            }
            Image {
                anchors.centerIn: parent
                width: cell.box * 0.72
                height: width
                visible: cell.kind === "icon"
                sourceSize: Qt.size(48, 48)
                source: cell.kind === "icon" ? Quickshell.iconPath(cell.spec.slice(5), "application-x-executable") : ""
                opacity: cell.active || cell.occupied || cell.notified ? 1 : 0.55
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -Theme.gap / 2
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + cell.wsId + " })")
            }
        }
    }

    // Развернуть / свернуть
    Label {
        visible: root.w.collapsible && (root.expanded || root.hasHidden)
        text: ""
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
