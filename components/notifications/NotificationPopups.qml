import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../theme"
import "../../services"

// Окно со стеком всплывающих уведомлений (справа сверху, под баром).
// Прозрачное для мыши везде, кроме самих карточек.
PanelWindow {
    id: win
    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: Notifs.shown.length > 0
    // Верхняя зарезервированная область монитора (все панели, не только наша):
    // окно на слое Overlay игнорирует exclusive-зоны, поэтому отступ считаем сами.
    readonly property real reservedTop: Hyprland.focusedMonitor?.lastIpcObject?.reserved?.[1] ?? (Theme.barHeight + Theme.barMargin * 2)
    onVisibleChanged: if (visible) Hyprland.refreshMonitors()
    color: "transparent"
    // Окно всегда на всю высоту: смена размера окна заставляла композитор заново
    // проигрывать анимацию появления у всех карточек. Мышь пропускает mask.
    anchors { top: true; bottom: true; right: true }
    margins {
        top: win.reservedTop + Theme.gap
        right: Theme.barMargin
        bottom: Theme.barMargin
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "qs-notifications"

    implicitWidth: Theme.notifWidth
    mask: Region { item: stack }

    Column {
        id: stack
        width: parent.width
        spacing: Theme.gap

        // ScriptModel сопоставляет элементы по идентичности: карточки не пересоздаются
        // (и не сбрасывают таймеры), когда состав очереди меняется
        Repeater {
            model: ScriptModel { values: Notifs.shown }
            delegate: NotificationCard { width: stack.width }
        }
    }
}
