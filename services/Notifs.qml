pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Отслеживает уведомления и помечает воркспейсы, на которых есть окно приложения-отправителя.
// Демона уведомлений не подменяет: слушает D-Bus пассивно (dbus-monitor), поэтому
// не конфликтует с mako/dunst/swaync. Метка снимается при переходе на воркспейс.
Singleton {
    id: root

    // id воркспейса → true
    property var pending: ({})

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

    function handle(appName, desktop) {
        const keys = [norm(desktop), norm(appName)].filter(k => k.length > 1)
        if (!keys.length) return
        for (const t of Hyprland.toplevels.values) {
            const cls = [norm(t.lastIpcObject?.class), norm(t.lastIpcObject?.initialClass)].filter(c => c.length > 1)
            const ws = t.workspace?.id ?? -1
            if (ws < 0 || ws === Hyprland.focusedWorkspace?.id) continue
            if (cls.some(c => keys.some(k => c === k || c.includes(k) || k.includes(c)))) root.mark(ws)
        }
    }

    // Разбор вывода dbus-monitor для вызовов Notify:
    //   string "<app_name>" … string "desktop-entry" / variant string "<id>" … int32 <timeout>
    Process {
        running: true
        command: ["stdbuf", "-oL", "dbus-monitor", "--session",
                  "interface='org.freedesktop.Notifications',member='Notify'"]
        stdout: SplitParser {
            property bool inNotify: false
            property string app: ""
            property string desktop: ""
            property bool wantDesktop: false
            property bool gotApp: false

            onRead: line => {
                const l = line.trim()
                if (/^(method call|method return|signal|error)/.test(l)) {
                    inNotify = l.startsWith("method call") && l.includes("member=Notify")
                    app = ""; desktop = ""; wantDesktop = false; gotApp = false
                    return
                }
                if (!inNotify) return
                const m = l.match(/string "(.*)"$/)
                if (m) {
                    if (wantDesktop) { desktop = m[1]; wantDesktop = false }
                    else if (l.startsWith("string ") && m[1] === "desktop-entry") wantDesktop = true
                    else if (!gotApp && l.startsWith("string ")) { app = m[1]; gotApp = true }
                }
                if (l.startsWith("int32 ")) {   // expire_timeout — последний аргумент
                    inNotify = false
                    root.handle(app, desktop)
                }
            }
        }
    }
}
