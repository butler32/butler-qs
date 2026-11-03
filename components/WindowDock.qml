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

    // lastIpcObject пуст, пока тополевелы не обновили вручную
    Component.onCompleted: Hyprland.refreshToplevels()

    anchors { bottom: true; left: true; right: true }
    implicitHeight: Math.max(base * zoom + pad * 2 + 30, 230)
    exclusiveZone: autoHide ? 0 : pillH + Theme.barMargin
    color: "transparent"
    WlrLayershell.namespace: "butler-dock"
    // скрытый док выезжает и поверх окна в полноэкранном режиме (иначе из него не выйти);
    // постоянный док остаётся на слое Top и полноэкранное окно его перекрывает
    WlrLayershell.layer: autoHide ? WlrLayer.Overlay : WlrLayer.Top
    // скрытый док принимает мышь только на тонкой полосе у нижнего края
    mask: Region { item: dock.autoHide && !dock.revealed ? strip : hit }

    // ── автоскрытие ──
    readonly property bool autoHide: cfg.dockAutoHide
    property bool revealed: false
    readonly property bool keepOpen: dockHover.hovered || menuGroup !== null
    property real slide: autoHide && !revealed ? pillH + Theme.barMargin + 8 : 0
    Behavior on slide { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    onKeepOpenChanged: keepOpen ? hideTimer.stop() : hideTimer.restart()
    onRevealedChanged: if (revealed && !keepOpen) hideTimer.restart()
    onAutoHideChanged: revealed = false
    Timer {
        id: hideTimer
        interval: 450
        onTriggered: if (!dock.keepOpen) dock.revealed = false
    }
    Item {
        id: strip
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: 4
        visible: dock.autoHide && !dock.revealed && dock.groups.length > 0
        HoverHandler { onHoveredChanged: if (hovered) dock.revealed = true }
    }

    // ── данные: группы окон по приложению ──
    property var order: []          // стабильный порядок ключей
    readonly property var rawGroups: {
        DesktopEntries.applications.values
        const map = {}
        for (const t of Hyprland.toplevels.values) {
            const o = t.lastIpcObject
            if (!o || !o.mapped) continue
            const wsn = o.workspace?.name ?? ""
            if (!(o.workspace?.id > 0 || wsn === "special:minimized")) continue
            if (!Windows.norm(o.class)) continue
            const addr = Windows.address(t)
            // одно окно — одна иконка
            map[addr] = { key: addr, cls: o.class, wins: [{ addr: addr, title: o.title,
                          minimized: wsn === "special:minimized", active: t.activated, focusId: o.focusHistoryID }] }
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
        const id = g.cls
        DesktopEntries.applications.values
        return DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id) ?? DesktopEntries.heuristicLookup(g.cls)
    }

    // иконка из .desktop или по имени класса; "" — такой иконки в теме нет (рисуем заглушку)
    function iconFor(g) {
        const name = entryFor(g)?.icon || g.cls.toLowerCase()
        return Quickshell.iconPath(name, true)
    }

    function activate(g) {
        const e = entryFor(g)
        if (g.wins.length === 0) return
        const vis = g.wins
        const i = vis.findIndex(w => w.active)
        const target = vis.length === 1 ? vis[0] : (vis[(i + 1) % vis.length])
        if (target.minimized) WinMode.unminimize(target.addr)
        else if (target.active && vis.length === 1) WinMode.minimize(target.addr)
        else WinMode.raise(target.addr)
    }

    // ── контекстное меню ──
    property var menuGroup: null
    property real menuCx: 0
    function menuItems(g) {
        const w = g.wins.find(x => x.active) ?? g.wins[g.wins.length - 1]
        const addr = w?.addr
        const sel = "window = \"address:" + addr + "\""
        const items = []
        if (w) {
            items.push({ t: w.minimized ? "dock.restore" : "dock.minimize", run: () => w.minimized ? WinMode.unminimize(addr) : WinMode.minimize(addr) })
            items.push({ t: "dock.maximize", run: () => Hyprland.dispatch("hl.dsp.window.fullscreen({ mode = \"maximized\", action = \"toggle\", " + sel + " })") })
            items.push({ t: "dock.fullscreen", run: () => Hyprland.dispatch("hl.dsp.window.fullscreen({ mode = \"fullscreen\", action = \"toggle\", " + sel + " })") })
            items.push({ t: "dock.close", danger: true, run: () => Hyprland.dispatch("hl.dsp.window.close({ " + sel + " })") })
        }
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
        anchors.bottomMargin: -dock.slide
        anchors.horizontalCenter: parent.horizontalCenter
        width: dock.hitW
        height: dock.hovering || dock.menuGroup ? dock.height : dock.pillH + Theme.barMargin
        visible: dock.groups.length > 0

        // HoverHandler, а не MouseArea: иконки со своим hover не должны «съедать» положение курсора
        HoverHandler {
            id: dockHover
            onPointChanged: dock.mouseX = point.position.x
            onHoveredChanged: if (!hovered) dock.mouseX = -1e4
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

                    Rectangle {   // заглушка для приложений без иконки в теме
                        anchors.fill: parent
                        visible: dock.iconFor(cell.modelData) === ""
                        radius: Theme.radiusItem
                        color: Theme.surfaceAlt
                        opacity: cell.allMin ? 0.45 : 1
                        Label {
                            anchors.centerIn: parent
                            text: cell.modelData.cls.charAt(0).toUpperCase()
                            font.pixelSize: parent.height * 0.5
                            color: Theme.textDim
                        }
                    }
                    Image {
                        anchors.fill: parent
                        visible: dock.iconFor(cell.modelData) !== ""
                        sourceSize: Qt.size(128, 128)
                        smooth: true
                        source: dock.iconFor(cell.modelData)
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
