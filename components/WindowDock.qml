import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"
import "../config"
import "../services"
import "../i18n"

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

    // lastIpcObject пуст, пока тополевелы не обновили вручную
    Component.onCompleted: Hyprland.refreshToplevels()

    anchors { bottom: true; left: true; right: true }
    implicitHeight: Math.max(base * zoom + pad * 2 + 30, 230)
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
        const pinIdx = k => { const g = rawGroups.find(x => x.key === k); const i = Config.apps.pinned.indexOf(g?.pinId); return i < 0 ? 1e6 : i }
        const fresh = keys.filter(k => !kept.includes(k)).sort((a, b) => pinIdx(a) - pinIdx(b))
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

    // ── контекстное меню ──
    property var menuGroup: null
    property real menuCx: 0
    function menuItems(g) {
        const w = g.wins.find(x => x.active) ?? g.wins[g.wins.length - 1]
        const addr = w?.addr
        const sel = "window = \"address:" + addr + "\""
        const items = []
        if (!w) items.push({ t: "dock.open", run: () => entryFor(g)?.execute() })
        else {
            items.push({ t: w.minimized ? "dock.restore" : "dock.minimize", run: () => w.minimized ? WinMode.unminimize(addr) : WinMode.minimize(addr) })
            items.push({ t: "dock.maximize", run: () => Hyprland.dispatch("hl.dsp.window.fullscreen({ mode = \"maximized\", action = \"toggle\", " + sel + " })") })
            items.push({ t: "dock.fullscreen", run: () => Hyprland.dispatch("hl.dsp.window.fullscreen({ mode = \"fullscreen\", action = \"toggle\", " + sel + " })") })
            items.push({ t: "dock.close", danger: true, run: () => Hyprland.dispatch("hl.dsp.window.close({ " + sel + " })") })
        }
        const id = g.pinId ?? entryFor(g)?.id
        if (id) items.push({ t: g.pinned ? "dock.unpin" : "dock.pin", run: () => Config.togglePinnedApp(id) })
        return items
    }

    // ── увеличение ──
    property real mouseX: -1e4
    readonly property bool hovering: mouseX > -1e3
    readonly property real unitW: base + gapPx
    readonly property real unscaledW: Math.max(groups.length * unitW - gapPx, 0)
    // ширина области мыши не зависит от текущего увеличения (иначе цикл раскладки)
    readonly property real hitW: unscaledW + pad * 2 + base * zoom * 2
    function scaleAt(i) {
        if (!hovering) return 1
        const c = hitW / 2 - unscaledW / 2 + i * unitW + base / 2
        const d = (mouseX - c) / cfg.dockRadius
        return 1 + (zoom - 1) * Math.exp(-d * d)
    }

    // область, принимающая мышь: сам док (в покое) или вся полоса с запасом сверху (при наведении)
    Item {
        id: hit
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: dock.hitW
        height: dock.hovering || dock.menuGroup ? dock.height : dock.pillH + Theme.barMargin
        visible: dock.groups.length > 0

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onPositionChanged: m => dock.mouseX = m.x
            onExited: dock.mouseX = -1e4
        }

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
                            else {
                                dock.menuCx = cell.mapToItem(null, cell.width / 2, 0).x
                                dock.menuGroup = g
                            }
                        }
                    }
                }
            }
        }
    }

    // клик мимо меню закрывает его
    MouseArea {
        anchors.fill: parent
        visible: dock.menuGroup !== null
        onClicked: dock.menuGroup = null
        z: 5
    }
    Rectangle {
        id: menu
        visible: dock.menuGroup !== null
        z: 6
        x: Math.max(4, Math.min(dock.width - width - 4, dock.menuCx - width / 2))
        anchors.bottom: parent.bottom
        anchors.bottomMargin: dock.pillH + Theme.barMargin + 10
        width: 200
        height: menuCol.implicitHeight + 12
        radius: Theme.radiusPanel
        color: Theme.surface
        border.width: Theme.borderWidth
        border.color: Theme.border
        Column {
            id: menuCol
            x: 6; y: 6; width: parent.width - 12
            Repeater {
                model: dock.menuGroup ? dock.menuItems(dock.menuGroup) : []
                delegate: Rectangle {
                    required property var modelData
                    width: menuCol.width
                    height: 30
                    radius: Theme.radiusItem
                    color: mi.containsMouse ? Theme.surfaceAlt : "transparent"
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 10
                        text: I18n.tr(parent.modelData.t)
                        color: parent.modelData.danger ? Theme.danger : Theme.text
                    }
                    MouseArea {
                        id: mi
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { const m = parent.modelData; dock.menuGroup = null; m.run() }
                    }
                }
            }
        }
    }
}
