import QtQuick
import Quickshell
import "../services"
import Quickshell.Services.Mpris
import Quickshell.Bluetooth
import Quickshell.Hyprland
import "../theme"
import "../i18n"
import "../config"

// Содержимое меню. Страница = массив пунктов; `build(id)` вызывается из Menu.qml
// внутри биндинга, так что страницы реактивны (список приложений, значения настроек).
// id страницы может нести параметр: "cfg.ws.icon:5" → база "cfg.ws.icon", аргумент "5".
//
// Пункт:
//   name, comment   — текст
//   icon            — nerd-font глиф;  iconSource — url картинки (приоритетнее)
//   page            — id вложенной страницы (переход внутрь)
//   run()           — действие;  keepOpen — не закрывать меню после него
//   backAfter       — после run вернуться на N страниц назад (с keepOpen)
//   adjust(d)       — значение меняется стрелками ←/→ (d = -1/+1); value — его подпись справа
//   active          — показать галочку;  danger — красный глиф
//   keywords        — доп. слова для поиска
// Все тексты — через I18n.tr(key), ключи в обоих языках лежат в i18n/I18n.qml.
// Любые настройки бара живут в Меню → Конфигурация (см. cfg*), значения — в Config.
// Чтобы добавить раздел: пункт с `page: "id"`, `case` в build() и ключ `menu.title.<id>`.
QtObject {
    // состояние подтверждения удаления домена из исключений VPN (vpnPage) — второй клик в течение 3с подтверждает
    property string vpnConfirmDelete: ""
    property Timer vpnConfirmTimer: Timer { interval: 3000; onTriggered: vpnConfirmDelete = "" }

    // второй клик в течение 3с подтверждает опасное действие (power)
    property string confirmKey: ""
    property Timer confirmTimer: Timer { interval: 3000; onTriggered: confirmKey = "" }

    // вызывается при открытии страницы: подтянуть данные, которых нет в реактивных источниках
    function opened(id) {
        const base = id.split(":")[0]
        if (base === "clip") Clipboard.refresh()
        else if (base === "windows") Hyprland.refreshToplevels()
        else if (base === "vpn.config") NetInfo.refreshVpnConfigs()
    }

    function title(id) {
        const [base, arg] = id.split(":")
        if (base === "cfg.sys.metric") return I18n.tr("metric." + arg)
        if (base === "cfg.claude.metric") return I18n.tr("claude." + arg + ".title")
        return I18n.tr("menu.title." + base) + (arg ? " " + arg : "")
    }

    function build(id, query) {
        const [base, arg] = id.split(":")
        if (base !== "power" && base !== "cfg.clip" && confirmKey !== "") {
            confirmTimer.stop()
            confirmKey = ""
        }
        if (base !== "vpn" && vpnConfirmDelete !== "") {
            vpnConfirmTimer.stop()
            vpnConfirmDelete = ""
        }
        switch (base) {
        case "apps": return withCalc(apps(), query)
        case "windows": return windows()
        case "clip": return clipboard()
        case "shot": return screenshots()
        case "themes": return themes()
        case "power": return power()
        case "lang": return langs()
        case "config": return config()
        case "vpn": return vpnPage(query)
        case "vpn.config": return vpnConfigPage(query)
        case "cfg.ws": return cfgWorkspaces()
        case "cfg.notif": return cfgNotifications()
        case "cfg.bt": return cfgBluetooth()
        case "cfg.media": return cfgMedia()
        case "cfg.media.app": return cfgMediaApp()
        case "cfg.clock": return cfgClock()
        case "cfg.apps": return missingPinnedApps().concat(apps(e => Config.togglePinnedApp(e.id), 0, e => Config.apps.pinned.includes(e.id)))
        case "cfg.sys": return cfgSys()
        case "cfg.osd": return cfgOsd()
        case "cfg.bar": return cfgBar()
        case "cfg.bar.mon": return cfgBarMonitors()
        case "cfg.bar.mon.one": return cfgBarMonitor(arg)
        case "cfg.tray": return cfgTray()
        case "cfg.night": return cfgNight()
        case "cfg.shot": return cfgShot()
        case "cfg.clip": return cfgClip()
        case "cfg.backup": return cfgBackup()
        case "cfg.claude": return cfgClaude()
        case "cfg.claude.metric": return cfgClaudeMetric(arg)
        case "cfg.sys.metric": return cfgSysMetric(arg)
        case "cfg.ws.icons": return cfgWorkspaceIcons()
        case "cfg.ws.icon": return cfgWorkspaceIcon(arg)
        case "cfg.ws.app": return apps(e => Config.setWorkspaceIcon(arg, "icon:" + e.icon), 2)
        default: return withCalc(root(), query)
        }
    }

    function root() {
        return [
            { name: I18n.tr("menu.apps"), comment: I18n.tr("menu.apps.hint"), icon: "", page: "apps" },
            { name: I18n.tr("menu.windows"), comment: I18n.tr("menu.windows.hint"), icon: "\uf2d2", page: "windows" },
            ...(Clipboard.active ? [{ name: I18n.tr("menu.clip"), comment: I18n.tr("menu.clip.hint"), icon: "\uf0ea", page: "clip" }] : []),
            { name: I18n.tr("menu.shot"), comment: I18n.tr("menu.shot.hint"), icon: "\uf030", page: "shot" },
            { name: I18n.tr("menu.config"), comment: I18n.tr("menu.config.hint"), icon: "", page: "config" },
            { name: I18n.tr("menu.configs"), comment: I18n.tr("menu.configs.hint"), icon: "", run: () => ConfigEditor.openWindow() },
            { name: I18n.tr("menu.themes"), comment: I18n.tr("menu.themes.hint"), icon: "", page: "themes" },
            vpnRootEntry(),
            { name: I18n.tr("menu.power"), comment: I18n.tr("menu.power.hint"), icon: "", danger: true, page: "power" }
        ]
    }

    function baseName(path) { return path.slice(path.lastIndexOf("/") + 1) }
    function shortPath(path) {
        const home = Quickshell.env("HOME")
        return path.startsWith(home + "/") ? "~" + path.slice(home.length) : path
    }
    function vpnConfigPath() { return Config.network.vpnConfig || NetInfo.vpnDefaultConfig }

    // Выбор .ovpn для butler-vpn.service: найденные файлы + путь, набранный в поиске
    // (~/… или /…, заканчивается на .ovpn). Новый файл применяется при следующем подключении.
    function vpnConfigPage(query) {
        const cur = vpnConfigPath()
        const pick = path => ({
            id: "vpn-config:" + path,
            name: baseName(path),
            comment: shortPath(path),
            icon: "\uf15b",
            active: cur === path,
            keepOpen: true,
            backAfter: 1,
            run: () => Config.network.vpnConfig = path
        })
        const home = Quickshell.env("HOME")
        const items = []
        const q = (query ?? "").trim()
        if (/^(~|\/).*\.ovpn$/i.test(q)) {
            const typed = q.startsWith("~") ? home + q.slice(1) : q
            items.push(Object.assign(pick(typed), { name: I18n.tr("vpn.config.use").replace("%1", shortPath(typed)), comment: "", sticky: true }))
        }
        const found = NetInfo.vpnConfigs.includes(cur) ? NetInfo.vpnConfigs : [cur, ...NetInfo.vpnConfigs]
        items.push(...found.map(pick))
        if (found.length <= 1 && !q) items.push({ id: "vpn-config-hint", name: I18n.tr("vpn.config.hint2"), icon: "\uf059", keepOpen: true })
        return items
    }

    // Калькулятор / конвертер: если набранное — выражение, первым пунктом идёт результат
    // (sticky — не отфильтровывается поиском); Enter копирует его в буфер обмена.
    function withCalc(items, query) {
        const r = Calc.evaluate(query)
        if (!r) return items
        return [{
            name: "= " + r.label,
            comment: I18n.tr("calc.copy"),
            icon: "\uf1ec",
            sticky: true,
            run: () => Quickshell.execDetached(["wl-copy", r.value])
        }, ...items]
    }

    // Открытые окна, недавно активные — первыми; выбор переключает на окно (и воркспейс)
    function windows() {
        return Hyprland.toplevels.values
            .filter(t => t.lastIpcObject?.mapped !== false)
            .map(t => {
                const o = t.lastIpcObject ?? {}
                const cls = o.class ?? ""
                const entry = cls ? DesktopEntries.heuristicLookup(cls) : null
                return {
                    order: o.focusHistoryID ?? 999,
                    item: {
                        name: t.title || cls || "?",
                        comment: cls,
                        iconSource: Quickshell.iconPath(entry?.icon ?? cls.toLowerCase(), "application-x-executable"),
                        value: I18n.tr("ws.n").replace("%1", t.workspace?.id ?? "?"),
                        keywords: [cls, o.initialClass ?? "", o.initialTitle ?? ""],
                        run: () => Windows.focus(t),
                        close: () => Windows.close(t)
                    }
                }
            })
            .sort((a, b) => a.order - b.order)
            .map(x => x.item)
    }

    function clipboard() {
        if (Clipboard.entries.length === 0)
            return [{ name: I18n.tr("clip.empty"), comment: I18n.tr("clip.empty.hint"), icon: "\uf0ea", keepOpen: true }]
        return Clipboard.entries.map(e => ({
            name: e.image ? I18n.tr("clip.image") : e.text,
            comment: e.image ? e.text : "",
            icon: e.image ? "\uf03e" : "\uf0ea",
            run: () => Clipboard.copy(e.id)
        }))
    }

    function screenshots() {
        return [
            { name: I18n.tr("shot.area"), comment: I18n.tr("shot.area.hint"), icon: "\uf125", run: () => Screenshot.take("area") },
            { name: I18n.tr("shot.screen"), comment: I18n.tr("shot.screen.hint"), icon: "\uf108", run: () => Screenshot.take("screen") },
            { name: I18n.tr("shot.window"), comment: I18n.tr("shot.window.hint"), icon: "\uf2d0", run: () => Screenshot.take("window") }
        ]
    }

    // Точка входа в раздел VPN — статус виден сразу, сам коннект/дисконнект и
    // список исключённых доменов — внутри страницы (vpnPage)
    function vpnRootEntry() {
        return {
            name: I18n.tr("menu.vpn"),
            comment: I18n.tr("menu.vpn.hint"),
            icon: "",
            value: NetInfo.vpnBusy ? I18n.tr("vpn.connecting")
                   : NetInfo.vpnConnected ? I18n.tr("common.on") : I18n.tr("common.off"),
            page: "vpn"
        }
    }

    // butler-vpn.service (см. scripts/vpn/): коннект/дисконнект + домены вне
    // туннеля (Config.network.vpnExcludedDomains). Ввод домена — через
    // строку поиска меню: набранный текст, если похож
    // на домен, предлагает добавить. Удаление домена —
    // в два клика (vpnConfirmDelete), чтобы случайное Enter/клик на
    // выбранном пункте не сносило его сразу.
    function vpnPage(query) {
        const busy = NetInfo.vpnBusy
        const toggle = {
            name: NetInfo.vpnConnected ? I18n.tr("vpn.disconnect") : I18n.tr("vpn.connect"),
            comment: NetInfo.vpnStatus || I18n.tr("menu.vpn.hint"),
            icon: "",
            value: busy ? I18n.tr("vpn.connecting")
                   : NetInfo.vpnConnected ? I18n.tr("common.on") : I18n.tr("common.off"),
            active: NetInfo.vpnConnected,
            keepOpen: true,
            run: () => NetInfo.toggleVpn()
        }
        const domains = Config.network.vpnExcludedDomains
        const items = [toggle, {
            name: I18n.tr("vpn.config"),
            comment: I18n.tr("vpn.config.hint"),
            icon: "\uf15b",
            value: baseName(vpnConfigPath()),
            page: "vpn.config"
        }]

        const q = (query ?? "").trim().toLowerCase()
        if (q && /\.\w/.test(q) && !/\s/.test(q) && !domains.includes(q)) {
            items.push({
                name: I18n.tr("vpn.exclude.add").replace("%1", q),
                icon: "",
                keepOpen: true,
                clearQuery: true,
                run: () => Config.addVpnExcludedDomain(q)
            })
        } else if (!q && domains.length === 0) {
            items.push({ name: I18n.tr("vpn.exclude.hint"), icon: "", keepOpen: true })
        }

        domains.forEach((d, i) => {
            const confirming = vpnConfirmDelete === d
            items.push({
                id: "vpn-domain:" + d,
                name: confirming ? I18n.tr("vpn.exclude.confirm").replace("%1", d) : d,
                comment: confirming ? "" : I18n.tr("vpn.exclude.remove.hint"),
                icon: "",
                danger: true,
                keepOpen: true,
                run: () => {
                    if (confirming) {
                        vpnConfirmTimer.stop()
                        vpnConfirmDelete = ""
                        Config.removeVpnExcludedDomain(i)
                    } else {
                        vpnConfirmDelete = d
                        vpnConfirmTimer.restart()
                    }
                }
            })
        })

        return items
    }

    // onPick(entry) — если задан, выбор приложения не запускает его, а отдаёт вызывающему
    // isActive(entry) — если задан, у приложения показывается галочка (выбор из списка)
    function apps(onPick, backAfter, isActive) {
        return DesktopEntries.applications.values
            .filter(e => !e.noDisplay)
            .sort((a, b) => a.name.localeCompare(b.name))
            .map(e => ({
                name: e.name,
                comment: e.comment ?? "",
                iconSource: Quickshell.iconPath(e.icon, "application-x-executable"),
                keywords: [e.genericName ?? "", ...(e.keywords ?? [])],
                active: isActive ? isActive(e) : false,
                run: () => onPick ? onPick(e) : e.execute(),
                keepOpen: !!onPick,
                backAfter: backAfter ?? 0
            }))
    }

    // закреплённые приложения, которых нет на этом устройстве (например, после импорта настроек):
    // без этих пунктов их нельзя снять — в списке apps() их нет
    function missingPinnedApps() {
        DesktopEntries.applications.values
        return Config.apps.pinned
            .filter(id => !(DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id)))
            .map(id => ({
                name: id,
                comment: I18n.tr("cfg.apps.missing"),
                icon: "\uf071",
                active: true,
                keepOpen: true,
                run: () => Config.togglePinnedApp(id)
            }))
    }

    function themes() {
        return Theme.names.map(n => ({
            name: I18n.tr("theme." + n),
            icon: "",
            active: Theme.name === n,
            keepOpen: true,   // применяется сразу, меню остаётся — удобно листать
            run: () => Theme.set(n)
        }))
    }

    // Опасные пункты подтверждаются вторым нажатием в течение 3с (confirmKey)
    function confirmed(key, item) {
        const confirming = confirmKey === key
        return Object.assign({}, item, {
            name: confirming ? I18n.tr("common.confirm").replace("%1", item.name) : item.name,
            keepOpen: !confirming,
            run: () => {
                if (confirming) { confirmTimer.stop(); confirmKey = ""; item.run() }
                else { confirmKey = key; confirmTimer.restart() }
            }
        })
    }

    function power() {
        return [
            confirmed("off", { name: I18n.tr("power.off"), icon: "", danger: true, run: () => Quickshell.execDetached(["systemctl", "poweroff"]) }),
            confirmed("reboot", { name: I18n.tr("power.reboot"), icon: "", danger: true, run: () => Quickshell.execDetached(["systemctl", "reboot"]) }),
            confirmed("logout", { name: I18n.tr("power.logout"), comment: I18n.tr("power.logout.hint"), icon: "\uf08b", danger: true,
                run: () => Quickshell.execDetached(["sh", "-c", "command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"]) }),
            { name: I18n.tr("power.suspend"), icon: "", run: () => Quickshell.execDetached(["systemctl", "suspend"]) },
            { name: I18n.tr("power.lock"), icon: "", run: () => Quickshell.execDetached(["hyprlock"]) },
            { name: I18n.tr("power.reload"), comment: I18n.tr("power.reload.hint"), icon: "\uf021", run: () => Quickshell.reload(true) }
        ]
    }

    function langs() {
        return I18n.langs.map(l => ({
            name: I18n.tr("lang." + l),
            icon: "",
            active: I18n.lang === l,
            keepOpen: true,
            run: () => I18n.set(l)
        }))
    }

    // ---------- Конфигурация ----------

    function config() {
        return [
            { name: I18n.tr("menu.lang"), comment: I18n.tr("menu.lang.hint"), icon: "", page: "lang" },
            { name: I18n.tr("cfg.bar"), comment: I18n.tr("cfg.bar.hint"), icon: "\uf0c9", page: "cfg.bar" },
            { name: I18n.tr("cfg.ws"), comment: I18n.tr("cfg.ws.hint"), icon: "", page: "cfg.ws" },
            { name: I18n.tr("cfg.tray"), comment: I18n.tr("cfg.tray.hint"), icon: "\uf2d0", page: "cfg.tray" },
            { name: I18n.tr("cfg.night"), comment: I18n.tr("cfg.night.hint"), icon: "\uf186", page: "cfg.night" },
            { name: I18n.tr("cfg.shot"), comment: I18n.tr("cfg.shot.hint"), icon: "\uf030", page: "cfg.shot" },
            { name: I18n.tr("cfg.clip"), comment: I18n.tr("cfg.clip.hint"), icon: "\uf0ea", page: "cfg.clip" },
            { name: I18n.tr("cfg.backup"), comment: I18n.tr("cfg.backup.hint"), icon: "\uf0c7", page: "cfg.backup" },
            { name: I18n.tr("cfg.notif"), comment: I18n.tr("cfg.notif.hint"), icon: "\uf0f3", page: "cfg.notif" },
            { name: I18n.tr("cfg.bt"), comment: I18n.tr("cfg.bt.hint"), icon: "\uf293", page: "cfg.bt" },
            { name: I18n.tr("cfg.media"), comment: I18n.tr("cfg.media.hint"), icon: "\uf001", page: "cfg.media" },
            { name: I18n.tr("cfg.clock"), comment: I18n.tr("cfg.clock.hint"), icon: "\uf017", page: "cfg.clock" },
            { name: I18n.tr("cfg.apps"), comment: I18n.tr("cfg.apps.hint"), icon: "\uf00a", page: "cfg.apps" },
            { name: I18n.tr("cfg.sys"), comment: I18n.tr("cfg.sys.hint"), icon: "\uf080", page: "cfg.sys" },
            { name: I18n.tr("cfg.osd"), comment: I18n.tr("cfg.osd.hint"), icon: "\uf028", page: "cfg.osd" },
            { name: I18n.tr("cfg.claude"), comment: I18n.tr("cfg.claude.hint"), icon: "\uf121", page: "cfg.claude" }
        ]
    }

    function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }

    // Числовая настройка: ←/→ меняют, Enter увеличивает по кругу
    // step — шаг изменения, fmt — форматирование значения для показа
    function numberItem(name, hint, icon, get, set, lo, hi, step, fmt) {
        const adjust = d => {
            const n = get() + d * (step ?? 1)
            set(n > hi ? lo : n < lo ? hi : n)
        }
        return { name: name, comment: hint, icon: icon, value: fmt ? fmt(get()) : String(get()), adjust: adjust, keepOpen: true, run: () => adjust(1) }
    }

    function toggleItem(name, hint, icon, get, set) {
        return { name: name, comment: hint, icon: icon, active: get(), keepOpen: true, run: () => set(!get()) }
    }

    function cfgWorkspaces() {
        const w = Config.ws
        const styles = ["dot", "number"]
        const nextStyle = d => { w.defaultStyle = styles[(styles.indexOf(w.defaultStyle) + d + styles.length) % styles.length] }
        return [
            { name: I18n.tr("cfg.ws.style"), comment: I18n.tr("cfg.ws.style.hint"), icon: "",
              value: I18n.tr("style." + w.defaultStyle), adjust: nextStyle, keepOpen: true, run: () => nextStyle(1) },
            { name: I18n.tr("cfg.ws.icons"), comment: I18n.tr("cfg.ws.icons.hint"), icon: "", page: "cfg.ws.icons" },
            toggleItem(I18n.tr("cfg.ws.collapsible"), I18n.tr("cfg.ws.collapsible.hint"), "",
                       () => w.collapsible, v => w.collapsible = v),
            numberItem(I18n.tr("cfg.ws.visible"), I18n.tr("cfg.ws.visible.hint"), "",
                       () => w.visibleCount, v => w.visibleCount = v, 1, w.total),
            numberItem(I18n.tr("cfg.ws.total"), I18n.tr("cfg.ws.total.hint"), "",
                       () => w.total, v => { w.total = v; if (w.visibleCount > v) w.visibleCount = v }, 1, 30),
            toggleItem(I18n.tr("cfg.ws.occupied"), I18n.tr("cfg.ws.occupied.hint"), "",
                       () => w.showOccupied, v => w.showOccupied = v),
            toggleItem(I18n.tr("cfg.ws.notify"), I18n.tr("cfg.ws.notify.hint"), "",
                       () => w.notifyHighlight, v => w.notifyHighlight = v)
        ]
    }

    function specLabel(spec) {
        if (!spec) return I18n.tr("style.default")
        if (spec.startsWith("icon:")) return spec.slice(5)
        return I18n.tr("style." + spec)
    }

    function specVisual(spec) {
        if (spec && spec.startsWith("icon:"))
            return { iconSource: Quickshell.iconPath(spec.slice(5), "application-x-executable") }
        return { icon: spec === "number" ? "" : "" }
    }

    function cfgWorkspaceIcons() {
        const out = []
        for (let i = 1; i <= Config.ws.total; i++) {
            const spec = Config.ws.icons[i] ?? ""
            out.push(Object.assign({
                name: I18n.tr("ws.n").replace("%1", i),
                value: specLabel(spec),
                page: "cfg.ws.icon:" + i
            }, specVisual(spec || Config.ws.defaultStyle)))
        }
        return out
    }

    function cfgWorkspaceIcon(id) {
        const cur = Config.ws.icons[id] ?? ""
        const pick = (label, spec, glyph) => ({
            name: I18n.tr(label), icon: glyph, active: cur === spec,
            keepOpen: true, backAfter: 1, run: () => Config.setWorkspaceIcon(id, spec)
        })
        return [
            pick("style.default", "", ""),
            pick("style.dot", "dot", ""),
            pick("style.number", "number", ""),
            { name: I18n.tr("style.app"), icon: "", active: cur.startsWith("icon:"), page: "cfg.ws.app:" + id }
        ]
    }

    function cfgNotifications() {
        const c = Config.notifications
        return [
            numberItem(I18n.tr("cfg.notif.max"), I18n.tr("cfg.notif.max.hint"), "\uf0ca",
                       () => c.maxVisible, v => c.maxVisible = v, 1, 10),
            numberItem(I18n.tr("cfg.notif.timeout"), I18n.tr("cfg.notif.timeout.hint"), "\uf017",
                       () => c.timeoutSec, v => c.timeoutSec = v, 0, 60, 1,
                       v => v === 0 ? I18n.tr("value.never") : v + " " + I18n.tr("unit.s")),
            numberItem(I18n.tr("cfg.notif.fade"), I18n.tr("cfg.notif.fade.hint"), "\uf042",
                       () => c.fadeMs, v => c.fadeMs = v, 0, 3000, 100,
                       v => v + " " + I18n.tr("unit.ms")),
            toggleItem(I18n.tr("cfg.notif.pauseall"), I18n.tr("cfg.notif.pauseall.hint"), "\uf04c",
                       () => c.pauseAllOnHover, v => c.pauseAllOnHover = v),
            toggleItem(I18n.tr("cfg.notif.dnd"), I18n.tr("cfg.notif.dnd.hint"), "\uf1f6",
                       () => c.dnd, v => c.dnd = v),
            numberItem(I18n.tr("cfg.notif.history"), I18n.tr("cfg.notif.history.hint"), "\uf1da",
                       () => c.historyMax, v => c.historyMax = v, 10, 200, 10),
            { name: I18n.tr("cfg.notif.test"), comment: I18n.tr("cfg.notif.test.hint"), icon: "\uf1d8", keepOpen: true,
              run: () => Quickshell.execDetached(["notify-send", "-a", "Quickshell", I18n.tr("cfg.notif.test.title"), I18n.tr("cfg.notif.test.body")]) }
        ]
    }

    function cfgMedia() {
        const c = Config.media
        return [
            toggleItem(I18n.tr("cfg.media.enabled"), I18n.tr("cfg.media.enabled.hint"), "\uf04b",
                       () => c.enabled, v => c.enabled = v),
            toggleItem(I18n.tr("cfg.media.prevnext"), I18n.tr("cfg.media.prevnext.hint"), "\uf051",
                       () => c.showPrevNext, v => c.showPrevNext = v),
            { name: I18n.tr("cfg.media.app"), comment: I18n.tr("cfg.media.app.hint"), icon: "\uf009",
              value: c.pinnedApp || I18n.tr("media.any"), page: "cfg.media.app" }
        ]
    }

    // "Любое приложение" + сейчас запущенные плееры (+ текущая привязка, даже если плеер закрыт)
    function cfgMediaApp() {
        const c = Config.media
        const names = Mpris.players.values.map(p => p.identity)
        if (c.pinnedApp && !names.some(n => n.toLowerCase() === c.pinnedApp)) names.push(c.pinnedApp)
        const pick = (label, value, glyph) => ({
            name: label, icon: glyph, active: c.pinnedApp === value,
            keepOpen: true, backAfter: 1, run: () => c.pinnedApp = value
        })
        return [pick(I18n.tr("media.any"), "", "\uf0ac"),
                ...names.map(n => pick(n, n.toLowerCase(), "\uf001"))]
    }

    // Адаптеры BlueZ с MAC (+ текущий выбор, даже если адаптер отключён)
    function cfgBluetooth() {
        const c = Config.bluetooth
        const list = Bluetooth.adapters.values.map(a => ({ mac: BtAdapters.macOf(a), alias: a.name, on: a.enabled }))
        if (c.adapter && !list.some(x => x.mac === c.adapter)) list.push({ mac: c.adapter, alias: "", on: null })
        const pick = (label, hint, value) => ({
            name: label, comment: hint, icon: "\uf293", active: c.adapter === value,
            keepOpen: true, run: () => c.adapter = value
        })
        return [pick(I18n.tr("cfg.bt.default"), I18n.tr("cfg.bt.default.hint"), ""),
                ...list.map(x => pick(x.mac || x.alias,
                    (x.alias ? x.alias + " · " : "") + (x.on === null ? I18n.tr("cfg.bt.missing") : x.on ? I18n.tr("common.on") : I18n.tr("common.off")),
                    x.mac))]
    }

    function cfgClock() {
        const c = Config.clock
        return [
            toggleItem(I18n.tr("cfg.clock.date"), "", "\uf073", () => c.showDate, v => c.showDate = v),
            toggleItem(I18n.tr("cfg.clock.monday"), I18n.tr("cfg.clock.monday.hint"), "\uf133",
                       () => c.weekStartsMonday, v => c.weekStartsMonday = v),
            toggleItem(I18n.tr("cfg.clock.seconds"), "", "\uf017", () => c.showSeconds, v => c.showSeconds = v),
            toggleItem(I18n.tr("cfg.clock.tooldnd"), I18n.tr("cfg.clock.tool.hint"), "\uf0f3", () => c.toolDnd, v => c.toolDnd = v),
            toggleItem(I18n.tr("cfg.clock.toolnight"), I18n.tr("cfg.clock.tool.hint"), "\uf186", () => c.toolNight, v => c.toolNight = v),
            toggleItem(I18n.tr("cfg.clock.toolshot"), I18n.tr("cfg.clock.tool.hint"), "\uf030", () => c.toolScreenshot, v => c.toolScreenshot = v)
        ]
    }

    function cfgTray() {
        const c = Config.tray
        return [toggleItem(I18n.tr("cfg.tray.collapsed"), I18n.tr("cfg.tray.collapsed.hint"), "\uf104",
                           () => c.collapsed, v => c.collapsed = v)]
    }

    function cfgNight() {
        const c = Config.night
        return [
            toggleItem(I18n.tr("cfg.night.enabled"),
                       NightLight.available ? I18n.tr("cfg.night.enabled.hint") : I18n.tr("cfg.night.missing"),
                       "\uf186", () => c.enabled, v => c.enabled = v),
            numberItem(I18n.tr("cfg.night.temp"), I18n.tr("cfg.night.temp.hint"), "\uf2c9",
                       () => c.temperature, v => c.temperature = v, 1500, 6500, 250, v => v + " K")
        ]
    }

    function cfgShot() {
        const c = Config.screenshot
        return [
            toggleItem(I18n.tr("cfg.shot.save"), I18n.tr("cfg.shot.save.hint"), "\uf0c7", () => c.save, v => c.save = v),
            toggleItem(I18n.tr("cfg.shot.copy"), I18n.tr("cfg.shot.copy.hint"), "\uf0ea", () => c.copy, v => c.copy = v),
            toggleItem(I18n.tr("cfg.shot.notify"), I18n.tr("cfg.shot.notify.hint"), "\uf0f3", () => c.notify, v => c.notify = v)
        ]
    }

    function cfgClip() {
        const c = Config.clipboard
        return [
            toggleItem(I18n.tr("cfg.clip.enabled"),
                       Clipboard.available ? I18n.tr("cfg.clip.enabled.hint") : I18n.tr("cfg.clip.missing"),
                       "\uf0ea", () => c.enabled, v => c.enabled = v),
            numberItem(I18n.tr("cfg.clip.max"), I18n.tr("cfg.clip.max.hint"), "\uf0ca",
                       () => c.maxItems, v => c.maxItems = v, 10, 500, 10),
            confirmed("clipwipe", { name: I18n.tr("cfg.clip.wipe"), comment: I18n.tr("cfg.clip.wipe.hint"), icon: "\uf1f8",
                                    danger: true, run: () => Clipboard.wipe() })
        ]
    }

    function cfgBackup() {
        return [
            { name: I18n.tr("cfg.backup.export"), comment: Config.bundlePath, icon: "\uf093", keepOpen: true,
              run: () => Config.exportSettings() },
            { name: I18n.tr("cfg.backup.import"), comment: I18n.tr("cfg.backup.import.hint"), icon: "\uf019", keepOpen: true,
              run: () => Config.importSettings() }
        ]
    }

    readonly property var monitorModes: ["off", "always", "yellow", "red"]

    function cfgSys() {
        return Config.metricIds.map(id => ({
            name: I18n.tr("metric." + id),
            icon: id.endsWith("Temp") ? "\uf2c9" : id === "ram" || id === "vram" ? "\uf2db" : "\uf080",
            value: I18n.tr("mode." + Config.sysmon[id].mode),
            page: "cfg.sys.metric:" + id
        }))
    }

    function cfgSysMetric(id) {
        const c = Config.sysmon[id]
        const modes = monitorModes
        const cycle = d => { c.mode = modes[(modes.indexOf(c.mode) + d + modes.length) % modes.length] }
        const unit = id.endsWith("Temp") ? "°C" : "%"
        return [
            { name: I18n.tr("cfg.sys.mode"), comment: I18n.tr("cfg.sys.mode.hint"), icon: "\uf06e",
              value: I18n.tr("mode." + c.mode), adjust: cycle, keepOpen: true, run: () => cycle(1) },
            numberItem(I18n.tr("cfg.sys.yellow"), I18n.tr("cfg.sys.thr.hint"), "\uf071",
                       () => c.yellow, v => c.yellow = v, 0, 120, 5, v => v + unit),
            numberItem(I18n.tr("cfg.sys.red"), I18n.tr("cfg.sys.thr.hint"), "\uf06a",
                       () => c.red, v => c.red = v, 0, 120, 5, v => v + unit)
        ]
    }

    function cfgOsd() {
        const c = Config.osd
        const positions = ["bottom", "top"]
        const cyclePos = d => { c.position = positions[(positions.indexOf(c.position) + d + positions.length) % positions.length] }
        return [
            toggleItem(I18n.tr("cfg.osd.enabled"), I18n.tr("cfg.osd.enabled.hint"), "\uf028", () => c.enabled, v => c.enabled = v),
            numberItem(I18n.tr("cfg.osd.timeout"), I18n.tr("cfg.osd.timeout.hint"), "\uf017",
                       () => c.timeoutMs, v => c.timeoutMs = v, 300, 5000, 100, v => v + " " + I18n.tr("unit.ms")),
            { name: I18n.tr("cfg.osd.position"), comment: I18n.tr("cfg.osd.position.hint"), icon: "\uf0ab",
              value: I18n.tr("pos." + c.position), adjust: cyclePos, keepOpen: true, run: () => cyclePos(1) },
            { name: I18n.tr("cfg.osd.test"), comment: I18n.tr("cfg.osd.test.hint"), icon: "\uf1d8", keepOpen: true,
              run: () => Osd.show("volume", 50) }
        ]
    }

    readonly property var barIcons: ({
        workspaces: "\uf009", apps: "\uf00a", media: "\uf001", sysmon: "\uf080", claude: "\uf121",
        tray: "\uf2d0", network: "\uf1eb", bluetooth: "\uf293", battery: "\uf240", power: "\uf0e7",
        language: "\uf11c", mixer: "\uf028"
    })

    // Порядок и видимость виджетов бара. Enter — показать/скрыть, ←/→ — сдвинуть;
    // строка-разделитель делит бар на левую и правую часть (виджеты за ней — справа).
    function cfgBar() {
        const order = Config.barOrder()
        const split = order.indexOf("|")
        const items = order.map((id, i) => {
            const move = d => Config.moveBarWidget(id, d) ? d : 0
            if (id === "|")
                return { name: I18n.tr("cfg.bar.split"), comment: I18n.tr("cfg.bar.split.hint"), icon: "\uf0db",
                         value: I18n.tr("cfg.bar.split.value"), adjust: move, keepOpen: true }
            return { name: I18n.tr("bar.w." + id), comment: I18n.tr("cfg.bar.item.hint"), icon: barIcons[id],
                     active: !Config.bar.hidden.includes(id),
                     value: I18n.tr(i < split ? "cfg.bar.left" : "cfg.bar.right"),
                     adjust: move, keepOpen: true, run: () => Config.toggleBarWidget(id) }
        })
        items.push({ name: I18n.tr("cfg.bar.mon"), comment: I18n.tr("cfg.bar.mon.hint"), icon: "\uf108", page: "cfg.bar.mon" })
        return items
    }

    function cfgBarMonitors() {
        return Quickshell.screens.map(s => ({
            name: s.name,
            comment: s.width + "×" + s.height,
            icon: "\uf108",
            value: I18n.tr(Config.barEnabledOn(s.name) ? "common.on" : "common.off"),
            page: "cfg.bar.mon.one:" + s.name
        }))
    }

    function cfgBarMonitor(name) {
        const items = [toggleItem(I18n.tr("cfg.bar.mon.enabled"), I18n.tr("cfg.bar.mon.enabled.hint"), "\uf108",
                                  () => Config.barEnabledOn(name), v => Config.setMonitorCfg(name, { enabled: v }))]
        for (const id of Config.barWidgetIds) {
            items.push(toggleItem(I18n.tr("bar.w." + id), I18n.tr("cfg.bar.mon.widget.hint"), barIcons[id],
                                  () => !(Config.monitorCfg(name).hidden ?? []).includes(id),
                                  v => Config.toggleMonitorWidget(name, id)))
        }
        return items
    }

    function cfgClaude() {
        const c = Config.claudeUsage
        return [
            toggleItem(I18n.tr("cfg.claude.enabled"), I18n.tr("cfg.claude.enabled.hint"), "\uf04b",
                       () => c.enabled, v => c.enabled = v),
            { name: I18n.tr("claude.session.title"), icon: "\uf017",
              value: I18n.tr("mode." + Config.claudeUsage.session.mode), page: "cfg.claude.metric:session" },
            { name: I18n.tr("claude.week.title"), icon: "\uf073",
              value: I18n.tr("mode." + Config.claudeUsage.week.mode), page: "cfg.claude.metric:week" }
        ]
    }

    function cfgClaudeMetric(id) {
        const c = Config.claudeUsage[id]
        const modes = monitorModes
        const cycle = d => { c.mode = modes[(modes.indexOf(c.mode) + d + modes.length) % modes.length] }
        return [
            { name: I18n.tr("cfg.sys.mode"), comment: I18n.tr("cfg.sys.mode.hint"), icon: "\uf06e",
              value: I18n.tr("mode." + c.mode), adjust: cycle, keepOpen: true, run: () => cycle(1) },
            numberItem(I18n.tr("cfg.sys.yellow"), I18n.tr("cfg.sys.thr.hint"), "\uf071",
                       () => c.yellow, v => c.yellow = v, 0, 100, 5, v => v + "%"),
            numberItem(I18n.tr("cfg.sys.red"), I18n.tr("cfg.sys.thr.hint"), "\uf06a",
                       () => c.red, v => c.red = v, 0, 100, 5, v => v + "%")
        ]
    }
}
