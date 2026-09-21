import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "../theme"
import "../services"

// Всплывающее окно под виджетом бара. Содержимое кладётся прямо внутрь
// (ColumnLayout); размер окна = размер содержимого. Закрывается кликом в любой точке
// вне окна и по Esc. Пока открыто, забирает клавиатуру (нужно для полей ввода).
// Одновременно открыто только одно окно (см. services/Popups).
//
// Использование внутри виджета:
//   BarPopup { id: popup; anchorItem: root; screen: root.QsWindow.window?.screen ?? null; ... }
//   ... onClicked: popup.toggle()
//
// Слои: само окно — на Overlay, «ловец кликов» на весь экран — на Top (ниже окна),
// поэтому порядок наложения не зависит от того, что раньше создано.
PanelWindow {
    id: win
    property Item anchorItem
    property string align: "right"      // right | left | center — выравнивание относительно виджета
    property bool open: false
    property real minWidth: 240
    property string ipcName: ""          // если задано: qs ipc call popup.<имя> toggle | close
    readonly property string uid: "popup-" + Math.random()
    property real closedAt: 0
    property real leftPos: 0
    default property alias content: col.data
    property alias spacing: col.spacing

    // Верхняя зарезервированная область монитора — все панели (не только наша).
    // Окно на слое Overlay игнорирует exclusive-зоны, поэтому отступ считаем сами.
    readonly property real reservedTop: Hyprland.monitorFor(screen)?.lastIpcObject?.reserved?.[1]
                                        ?? (Theme.barHeight + Theme.barMargin * 2)

    function close() { closedAt = Date.now(); open = false }
    // клик по кнопке виджета, когда окно открыто, сначала закрывает его (ловец кликов),
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
    onOpenChanged: {
        if (open) {
            Popups.activeId = uid
            Hyprland.refreshMonitors()
            reposition()
        } else if (Popups.activeId === uid) {
            Popups.activeId = ""
        }
    }
    onWidthChanged: if (open) reposition()
    Connections {
        target: Popups
        function onActiveIdChanged() { if (Popups.activeId !== win.uid) win.open = false }
    }

    visible: open
    color: "transparent"
    anchors { top: true; left: true }
    margins {
        top: reservedTop + Theme.barMargin
        left: leftPos
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
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

    // Забирает клавиатуру при открытии (Esc, поля ввода) и закрывает окно по клику вне его.
    // Именно grab + OnDemand, а не Exclusive: при Exclusive Hyprland не доставляет клики
    // в другие поверхности, и ловец кликов ниже не работает.
    HyprlandFocusGrab {
        windows: [win]
        active: win.open
        onCleared: win.close()
    }

    // Прозрачный слой на весь экран под окном: любой клик вне окна закрывает его.
    // Панели сверху (наша и чужие) остаются доступными (отступ сверху), так что клик
    // по другому виджету бара открывает его окно, а это закрывается.
    PanelWindow {
        id: catcher
        screen: win.screen
        visible: win.open
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "qs-popup-catcher"
        // отступ сверху = область панелей: они остаются кликабельными
        margins.top: win.reservedTop

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: win.close()
        }
    }

    Rectangle {
        anchors.fill: parent
        // Esc: дочерние поля ввода его не забирают, событие доходит сюда
        focus: true
        Keys.onEscapePressed: win.close()
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
