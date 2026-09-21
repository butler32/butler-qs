import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "../theme"

// Всплывающее окно под виджетом бара. Содержимое кладётся прямо внутрь
// (ColumnLayout); размер окна = размер содержимого. Закрывается кликом вне окна
// и по Esc. Пока открыто, забирает клавиатуру (нужно для полей ввода).
//
// Использование внутри виджета:
//   BarPopup { id: popup; anchorItem: root; screen: root.QsWindow.window?.screen; ... }
//   ... onClicked: popup.toggle()
PanelWindow {
    id: win
    property Item anchorItem
    property string align: "right"      // right | left | center — выравнивание относительно виджета
    property bool open: false
    property real minWidth: 240
    property string ipcName: ""          // если задано: qs ipc call popup.<имя> toggle | close
    property real closedAt: 0
    property real leftPos: 0
    default property alias content: col.data
    property alias spacing: col.spacing

    // клик по кнопке виджета, когда окно открыто, сначала закрывает его через grab,
    // а потом приходит сам клик — без этой защиты окно тут же открылось бы снова
    function toggle() { if (Date.now() - closedAt > 250) open = !open }

    function reposition() {
        if (!anchorItem) return
        const p = anchorItem.mapToItem(null, 0, 0)
        let x = align === "right" ? p.x + anchorItem.width - width
              : align === "center" ? p.x + (anchorItem.width - width) / 2
              : p.x
        const sw = screen ? screen.width : 1920
        leftPos = Math.max(Theme.gap, Math.min(x, sw - width - Theme.gap))
    }
    onOpenChanged: if (open) reposition()
    onWidthChanged: if (open) reposition()

    visible: open
    color: "transparent"
    anchors { top: true; left: true }
    margins {
        top: Theme.barMargin       // ниже всех панелей (exclusive-зоны), см. exclusionMode
        left: leftPos
    }
    exclusionMode: ExclusionMode.Normal   // отсчёт от нижнего края бара, а не от края экрана (там могут быть другие панели)
    WlrLayershell.layer: WlrLayer.Top   // в одном слое с панелями, чтобы работали их exclusive-зоны
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "qs-popup"

    implicitWidth: Math.max(minWidth, col.implicitWidth + Theme.padding * 2)
    implicitHeight: col.implicitHeight + Theme.padding * 2

    IpcHandler {
        // на нескольких мониторах цель ipc занимает бар монитора с фокусом
        enabled: win.ipcName !== "" && win.screen?.name === Hyprland.focusedMonitor?.name
        target: "popup." + win.ipcName
        function toggle(): void { win.open = !win.open }
        function close(): void { win.open = false }
    }

    HyprlandFocusGrab {
        windows: [win]
        active: win.open
        onCleared: { win.closedAt = Date.now(); win.open = false }
    }

    Rectangle {
        anchors.fill: parent
        // Esc: дочерние поля ввода его не забирают, событие доходит сюда
        focus: true
        Keys.onEscapePressed: { win.closedAt = Date.now(); win.open = false }
        color: Theme.surface
        radius: Theme.radiusPopup
        border.width: Theme.borderWidth
        border.color: Theme.border

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: Theme.padding
            spacing: Theme.gap
        }
    }
}
