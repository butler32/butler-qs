import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"
import "../config"
import "../services"

// Нижняя панель оконного режима: иконки открытых окон (по приложениям) и закреплённых
// приложений, увеличение под курсором как в macOS. Параметры: Config.windowing.
PanelWindow {
    id: dock
    readonly property var cfg: Config.windowing
    readonly property real base: cfg.dockIconSize
    readonly property real zoom: cfg.dockZoom / 100
    readonly property real gapPx: 6
    readonly property real pad: Theme.padding * 0.6
    readonly property real pillH: base + pad * 2
    readonly property int monId: Hyprland.monitorFor(screen)?.id ?? -1

    anchors { bottom: true; left: true; right: true }
    implicitHeight: base * zoom + pad * 2 + 30
    exclusiveZone: pillH + Theme.barMargin
    color: "transparent"
    WlrLayershell.namespace: "butler-dock"
    mask: Region { item: hit }

    // ── данные: группы окон по приложению ──
    property var order: []          // стабильный порядок ключей
    readonly property var rawGroups: {
        DesktopEntries.applications.values
        const map = {}
        for (const t of Hyprland.toplevels.values) {
            const o = t.lastIpcObject
            if (!o || !o.mapped || o.monitor !== dock.monId) continue
            const wsn = o.workspace?.name ?? ""
            if (!(o.workspace?.id > 0 || wsn === "special:minimized")) continue
            const key = Windows.norm(o.class)
            if (!key) continue
            const g = map[key] ?? (map[key] = { key: key, cls: o.class, wins: [], pinned: false })
            g.wins.push({ addr: Windows.address(t), title: o.title, minimized: wsn === "special:minimized",
                          active: t.activated, focusId: o.focusHistoryID })
        }
        for (const id of Config.apps.pinned) {
            const key = Windows.norm(id)
            const e = DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id)
            const hit = Object.values(map).find(g => Windows.matching([id, e?.startupClass, e?.name]).some(t => Windows.norm(t.lastIpcObject?.class) === g.key))
            if (hit) { hit.pinned = true; hit.pinId = id }
            else if (!map["pin:" + key]) map["pin:" + key] = { key: "pin:" + key, cls: id, wins: [], pinned: true, pinId: id }
        }
        const list = Object.values(map)
        for (const g of list) g.wins.sort((a, b) => a.focusId - b.focusId)
        return list
    }
    readonly property var groups: {
        const list = [...rawGroups]
        const ord = order
        list.sort((a, b) => {
            const ia = ord.indexOf(a.key), ib = ord.indexOf(b.key)
            return (ia < 0 ? 1e6 : ia) - (ib < 0 ? 1e6 : ib)
        })
        return list
    }
    onRawGroupsChanged: {
        const keys = rawGroups.map(g => g.key)
        const kept = order.filter(k => keys.includes(k))
        const fresh = keys.filter(k => !kept.includes(k))
        if (fresh.length || kept.length !== order.length) order = kept.concat(fresh)
    }

    function entryFor(g) {
        const id = g.pinId ?? g.cls
        DesktopEntries.applications.values
        return DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id) ?? DesktopEntries.heuristicLookup(g.cls)
    }

    function activate(g) {
        const e = entryFor(g)
        if (g.wins.length === 0) { e?.execute(); return }
        const vis = g.wins
        const i = vis.findIndex(w => w.active)
        const target = vis.length === 1 ? vis[0] : (vis[(i + 1) % vis.length])
        if (target.minimized) WinMode.unminimize(target.addr)
        else if (target.active && vis.length === 1) WinMode.minimize(target.addr)
        else Hyprland.dispatch("hl.dsp.focus({ window = \"address:" + target.addr + "\" })")
    }

    // ── увеличение ──
    property real mouseX: -1e4
    readonly property bool hovering: mouseX > -1e3
    readonly property real unitW: base + gapPx
    function scaleAt(i) {
        if (!hovering) return 1
        const c = hitInner.width / 2 - groups.length * unitW / 2 + i * unitW + base / 2
        const d = (mouseX - hitInner.x - c) / cfg.dockRadius
        return 1 + (zoom - 1) * Math.exp(-d * d)
    }

    // область, принимающая мышь: сам док (в покое) или вся полоса с запасом сверху (при наведении)
    Item {
        id: hit
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(row.width, 1) + pad * 2 + 40
        height: dock.hovering ? dock.height : dock.pillH + Theme.barMargin
        visible: dock.groups.length > 0

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onPositionChanged: m => dock.mouseX = m.x
            onExited: dock.mouseX = -1e4
        }
        Item { id: hitInner; x: 0; y: 0; width: parent.width; height: parent.height }

        Rectangle {
            id: pill
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.barMargin
            width: row.width + pad * 2
            height: dock.pillH
            radius: Theme.radiusPanel
            color: Theme.surface
            border.width: Theme.borderWidth
            border.color: Theme.border
            Behavior on width { NumberAnimation { duration: 90 } }
        }

        Row {
            id: row
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: pill.bottom
            anchors.bottomMargin: dock.pad
            spacing: dock.gapPx
            Repeater {
                model: dock.groups
                delegate: Item {
                    id: cell
                    required property var modelData
                    required property int index
                    readonly property real s: dock.scaleAt(index)
                    readonly property bool active: modelData.wins.some(w => w.active)
                    readonly property bool allMin: modelData.wins.length > 0 && modelData.wins.every(w => w.minimized)
                    width: dock.base * s
                    height: dock.base * s
                    anchors.bottom: parent.bottom

                    Image {
                        anchors.fill: parent
                        sourceSize: Qt.size(128, 128)
                        smooth: true
                        source: Quickshell.iconPath(dock.entryFor(cell.modelData)?.icon ?? "", "application-x-executable")
                        opacity: cell.allMin ? 0.45 : cell.modelData.wins.length ? 1 : 0.7
                    }
                    Rectangle {   // индикатор окон
                        visible: cell.modelData.wins.length > 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.bottom
                        anchors.topMargin: 1
                        width: cell.active ? 10 : 4
                        height: 3
                        radius: 1.5
                        color: cell.active ? Theme.accent : Theme.textDim
                    }
                    Rectangle {   // подсказка с названием
                        visible: ma.containsMouse
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.top
                        anchors.bottomMargin: 6
                        width: tip.implicitWidth + 16
                        height: tip.implicitHeight + 8
                        radius: Theme.radiusItem
                        color: Theme.surface
                        border.width: Theme.borderWidth
                        border.color: Theme.border
                        Label {
                            id: tip
                            anchors.centerIn: parent
                            text: cell.modelData.wins.length ? cell.modelData.wins[cell.modelData.wins.length - 1].title : (dock.entryFor(cell.modelData)?.name ?? cell.modelData.cls)
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, 320)
                        }
                    }
                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onClicked: m => {
                            const g = cell.modelData
                            if (m.button === Qt.LeftButton) dock.activate(g)
                            else if (m.button === Qt.MiddleButton) g.wins.forEach(w => Hyprland.dispatch("hl.dsp.window.close({ window = \"address:" + w.addr + "\" })"))
                            else if (g.wins.length) {
                                const w = g.wins[g.wins.length - 1]
                                w.minimized ? WinMode.unminimize(w.addr) : WinMode.minimize(w.addr)
                            }
                        }
                    }
                }
            }
        }
    }
}
