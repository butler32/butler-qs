import QtQuick
import Quickshell
import "../services"
import Quickshell.Services.Mpris
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
    function title(id) {
        const [base, arg] = id.split(":")
        if (base === "cfg.sys.metric") return I18n.tr("metric." + arg)
        return I18n.tr("menu.title." + base) + (arg ? " " + arg : "")
    }

    function build(id) {
        const [base, arg] = id.split(":")
        switch (base) {
        case "apps": return apps()
        case "themes": return themes()
        case "power": return power()
        case "lang": return langs()
        case "config": return config()
        case "cfg.ws": return cfgWorkspaces()
        case "cfg.notif": return cfgNotifications()
        case "cfg.media": return cfgMedia()
        case "cfg.media.app": return cfgMediaApp()
        case "cfg.clock": return cfgClock()
        case "cfg.apps": return apps(e => Config.togglePinnedApp(e.id), 0, e => Config.apps.pinned.includes(e.id))
        case "cfg.sys": return cfgSys()
        case "cfg.osd": return cfgOsd()
        case "cfg.sys.metric": return cfgSysMetric(arg)
        case "cfg.ws.icons": return cfgWorkspaceIcons()
        case "cfg.ws.icon": return cfgWorkspaceIcon(arg)
        case "cfg.ws.app": return apps(e => Config.setWorkspaceIcon(arg, "icon:" + e.icon), 2)
        default: return root()
        }
    }

    function root() {
        return [
            { name: I18n.tr("menu.apps"), comment: I18n.tr("menu.apps.hint"), icon: "", page: "apps" },
            { name: I18n.tr("menu.config"), comment: I18n.tr("menu.config.hint"), icon: "", page: "config" },
            { name: I18n.tr("menu.themes"), comment: I18n.tr("menu.themes.hint"), icon: "", page: "themes" },
            { name: I18n.tr("menu.lang"), comment: I18n.tr("menu.lang.hint"), icon: "", page: "lang" },
            { name: I18n.tr("menu.power"), comment: I18n.tr("menu.power.hint"), icon: "", page: "power" }
        ]
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

    function themes() {
        return Theme.names.map(n => ({
            name: I18n.tr("theme." + n),
            icon: "",
            active: Theme.name === n,
            keepOpen: true,   // применяется сразу, меню остаётся — удобно листать
            run: () => Theme.set(n)
        }))
    }

    function power() {
        return [
            { name: I18n.tr("power.off"), icon: "", danger: true, run: () => Quickshell.execDetached(["systemctl", "poweroff"]) },
            { name: I18n.tr("power.reboot"), icon: "", danger: true, run: () => Quickshell.execDetached(["systemctl", "reboot"]) },
            { name: I18n.tr("power.suspend"), icon: "", run: () => Quickshell.execDetached(["systemctl", "suspend"]) },
            { name: I18n.tr("power.lock"), icon: "", run: () => Quickshell.execDetached(["hyprlock"]) }
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
            { name: I18n.tr("cfg.ws"), comment: I18n.tr("cfg.ws.hint"), icon: "", page: "cfg.ws" },
            { name: I18n.tr("cfg.notif"), comment: I18n.tr("cfg.notif.hint"), icon: "\uf0f3", page: "cfg.notif" },
            { name: I18n.tr("cfg.media"), comment: I18n.tr("cfg.media.hint"), icon: "\uf001", page: "cfg.media" },
            { name: I18n.tr("cfg.clock"), comment: I18n.tr("cfg.clock.hint"), icon: "\uf017", page: "cfg.clock" },
            { name: I18n.tr("cfg.apps"), comment: I18n.tr("cfg.apps.hint"), icon: "\uf00a", page: "cfg.apps" },
            { name: I18n.tr("cfg.sys"), comment: I18n.tr("cfg.sys.hint"), icon: "\uf080", page: "cfg.sys" },
            { name: I18n.tr("cfg.osd"), comment: I18n.tr("cfg.osd.hint"), icon: "\uf028", page: "cfg.osd" }
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
            { name: I18n.tr("cfg.notif.test"), comment: I18n.tr("cfg.notif.test.hint"), icon: "\uf1d8", keepOpen: true,
              run: () => Quickshell.execDetached(["notify-send", "-a", "Quickshell", I18n.tr("cfg.notif.test.title"), I18n.tr("cfg.notif.test.body")]) }
        ]
    }

    function cfgMedia() {
        const c = Config.media
        return [
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

    function cfgClock() {
        const c = Config.clock
        return [
            toggleItem(I18n.tr("cfg.clock.date"), "", "\uf073", () => c.showDate, v => c.showDate = v),
            toggleItem(I18n.tr("cfg.clock.monday"), I18n.tr("cfg.clock.monday.hint"), "\uf133",
                       () => c.weekStartsMonday, v => c.weekStartsMonday = v),
            toggleItem(I18n.tr("cfg.clock.seconds"), "", "\uf017", () => c.showSeconds, v => c.showSeconds = v)
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
}
