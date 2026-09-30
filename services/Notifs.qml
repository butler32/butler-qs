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
    // История: снимки (обычные JS-объекты, не Notification) от новых к старым, размер —
    // Config.notifications.historyMax. `missed` — сколько пришло «молча» из-за DND
    // с тех пор, как историю в последний раз смотрели.
    property var history: []
    property int missed: 0

    NotificationServer {
        keepOnReload: true
        actionsSupported: true
        bodyMarkupSupported: true
        onNotification: n => {
            const silent = Config.notifications.dnd && n.urgency !== NotificationUrgency.Critical
            root.record(n, silent)
            root.markWorkspace(n.appName, n.desktopEntry)
            if (silent) { root.missed++; return }
            n.tracked = true
            root.enqueue(n)
        }
    }

    function record(n, silent) {
        const snap = {
            appName: n.appName, desktopEntry: n.desktopEntry, appIcon: n.appIcon,
            summary: n.summary, body: n.body, critical: n.urgency === NotificationUrgency.Critical,
            silent: silent, time: Date.now()
        }
        history = [snap, ...history].slice(0, Config.notifications.historyMax)
    }
    function clearHistory() { history = []; missed = 0 }
    function removeFromHistory(i) { history = history.filter((_, j) => j !== i) }
    function toggleDnd() { Config.notifications.dnd = !Config.notifications.dnd }

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
        function onHistoryMaxChanged() { root.history = root.history.slice(0, Config.notifications.historyMax) }
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
