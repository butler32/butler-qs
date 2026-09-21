pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import "../config"

// Демон уведомлений (org.freedesktop.Notifications) + очередь показа.
//  - `shown`   — то, что сейчас на экране (не больше Config.notifications.maxVisible)
//  - `waiting` — очередь: попадает на экран, когда освобождается место
// Отрисовка — components/notifications/. Здесь только состояние.
// Заодно помечает воркспейсы, на которых есть окно приложения-отправителя (`pending`);
// метка снимается при переходе на воркспейс.
Singleton {
    id: root

    property var shown: []
    property var waiting: []
    property var pending: ({})   // id воркспейса → true
    property int hoverCount: 0   // сколько уведомлений сейчас под курсором

    NotificationServer {
        keepOnReload: true
        actionsSupported: true
        bodyMarkupSupported: true
        onNotification: n => {
            n.tracked = true
            root.enqueue(n)
            root.markWorkspace(n.appName, n.desktopEntry)
        }
    }

    function enqueue(n) {
        n.closed.connect(() => root.forget(n))
        waiting = [...waiting, n]
        promote()
    }
    function forget(n) {
        shown = shown.filter(x => x !== n)
        waiting = waiting.filter(x => x !== n)
        promote()
    }
    function promote() {
        const free = Config.notifications.maxVisible - shown.length
        if (free <= 0 || waiting.length === 0) return
        shown = [...shown, ...waiting.slice(0, free)]
        waiting = waiting.slice(free)
    }

    Connections {
        target: Config.notifications
        function onMaxVisibleChanged() { root.promote() }
    }

    // ---------- метки воркспейсов ----------

    function mark(id) { if (!pending[id]) pending = Object.assign({}, pending, { [id]: true }) }
    function clear(id) {
        if (!pending[id]) return
        const p = Object.assign({}, pending)
        delete p[id]
        pending = p
    }

    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() { root.clear(Hyprland.focusedWorkspace?.id) }
    }

    function norm(s) { return (s ?? "").toLowerCase().replace(/[^a-z0-9]/g, "") }

    function markWorkspace(appName, desktop) {
        const keys = [norm(desktop), norm(appName)].filter(k => k.length > 1)
        if (!keys.length) return
        for (const t of Hyprland.toplevels.values) {
            const cls = [norm(t.lastIpcObject?.class), norm(t.lastIpcObject?.initialClass)].filter(c => c.length > 1)
            const ws = t.workspace?.id ?? -1
            if (ws < 0 || ws === Hyprland.focusedWorkspace?.id) continue
            if (cls.some(c => keys.some(k => c === k || c.includes(k) || k.includes(c)))) root.mark(ws)
        }
    }
}
