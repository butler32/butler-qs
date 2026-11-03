pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../config"
import "../i18n"

// Оконный режим: тайлинг ⇄ плавающие окна на одном воркспейсе каждого монитора.
// План и обоснование: docs/window-mode.md. Владелец состояния — этот синглтон:
// снимки окон лежат в <state>/winmode.json, режим для hyprland-конфига — в winmode.mode
// (его читает scripts/hypr/winmode.lua при reload). Любая правка окон идёт через
// `hyprctl --batch`, строго по очереди.
Singleton {
    id: root

    property string mode: "tiling"          // "tiling" | "windowed"
    readonly property bool windowed: mode === "windowed"
    property bool busy: false

    // { tiling: снимок на момент входа в оконный режим, windowed: последний снимок оконного,
    //   classMemory: "class@монитор" → геометрия, minOrigin: address → воркспейс до сворачивания }
    property var snaps: ({ tiling: null, windowed: null, classMemory: ({}), minOrigin: ({}) })
    property var homeRules: ({})            // class (нижний регистр) → воркспейс из windows.lua
    property bool loaded: false

    readonly property string signature: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ?? ""
    readonly property int cascadeStep: 32

    // ───────────────────────── хранение ─────────────────────────

    FileView {
        id: store
        path: Quickshell.statePath("winmode.json")
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text())
                root.snaps = {
                    tiling: d.tiling ?? null, windowed: d.windowed ?? null,
                    classMemory: d.classMemory ?? ({}), minOrigin: d.minOrigin ?? ({})
                }
                // после перезапуска Hyprland режим «окна» не имеет смысла: окна уже другие
                root.mode = (d.signature === root.signature && d.mode === "windowed") ? "windowed" : "tiling"
            } catch (e) { console.warn("winmode: bad state file:", e) }
            root.afterLoad()
        }
        onLoadFailed: root.afterLoad()
    }
    FileView { id: modeFile; path: Quickshell.statePath("winmode.mode"); printErrors: false }

    function afterLoad() {
        loaded = true
        writeMode()
        frameProbe.running = true
        readHomeRules()
        if (mode === "windowed") exec(["hyprctl", "eval", "WM_SET(true)"], () => {})
    }

    function writeMode() { modeFile.setText(mode + "\n") }

    // ───────────────────── заголовки окон (hyprbars) ─────────────────────

    readonly property string frameStyle: Config.windowing.frameStyle
    readonly property string hyprbarsSo: (Quickshell.env("HOME") ?? "") + "/.local/share/butler/hyprbars/libhyprbars.so"
    property bool frameAvailable: false      // плагин собран (scripts/hyprbars/build.sh)
    FileView { id: frameFile; path: Quickshell.statePath("winmode.style"); printErrors: false }
    Process {
        id: frameProbe
        command: ["sh", "-c", "test -f \"" + root.hyprbarsSo + "\""]
        onExited: code => { root.frameAvailable = code === 0; root.applyFrame() }
    }

    // записать стиль для winframe.lua; плагин грузим здесь, а не из конфига (hl.plugin.load в конфиге
    // вызывает reload, а он выгружает плагин — бесконечный цикл); затем reload, чтобы применить стиль
    function applyFrame() {
        if (!loaded) return
        frameFile.setText(frameStyle + "\n")
        const want = frameStyle !== "none" && frameAvailable
        exec(["sh", "-c",
              "loaded=$(hyprctl plugin list | grep -c hyprbars); " +
              (want ? "if [ \"$loaded\" = 0 ]; then hyprctl plugin load \"" + hyprbarsSo + "\"; fi; hyprctl reload"
                    : "if [ \"$loaded\" != 0 ]; then hyprctl reload; fi")],
             () => {})
    }
    onFrameStyleChanged: applyFrame()

    function save() {
        store.setText(JSON.stringify({
            mode: mode, signature: signature,
            tiling: snaps.tiling, windowed: snaps.windowed,
            classMemory: snaps.classMemory, minOrigin: snaps.minOrigin
        }))
    }

    // ───────────────────── очередь процессов ─────────────────────

    property var jobs: []
    property var current: null

    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: {
                const j = root.current
                root.current = null
                if (j) j.cb(text)
                root.pump()
            }
        }
    }

    function exec(argv, cb) { jobs.push({ argv: argv, cb: cb }); pump() }

    function pump() {
        if (current || jobs.length === 0) return
        current = jobs.shift()
        proc.command = current.argv
        proc.running = true
    }

    // steps: [{ cmds: [...] } | { wait: мс } | { gather: fn(state) -> steps }]; потом done()
    function runSteps(steps, done) {
        let i = 0
        const next = () => {
            if (i >= steps.length) { done(); return }
            const s = steps[i++]
            if (s.notify) { notifyPlaced(s.notify); next() }
            else if (s.wait !== undefined) waitTimer(s.wait, next)
            else if (s.gather) gather(st => { steps.splice(i, 0, ...s.gather(st)); next() })
            else if (s.cmds && s.cmds.length) batch(s.cmds, next)
            else next()
        }
        next()
    }

    Component { id: timerComp; Timer { property var cb; onTriggered: { cb(); destroy() } } }
    function waitTimer(ms, cb) { timerComp.createObject(root, { interval: ms, running: true, cb: cb }) }

    function notifyPlaced(n) {
        exec(["notify-send", "-a", "butler", I18n.tr("winmode.placed.title"), I18n.tr("winmode.placed").replace("%1", n)], () => {})
    }

    // команды: "eval <lua>" или текст Lua-диспетчера
    function batch(cmds, cb) {
        const line = cmds.map(c => c.startsWith("eval ") ? c : "dispatch " + c).join(" ; ")
        exec(["hyprctl", "--batch", line], cb)
    }

    // ───────────────────── чтение состояния ─────────────────────

    function gather(cb) {
        exec(["sh", "-c",
              "hyprctl clients -j; echo @@@; hyprctl monitors -j; echo @@@; hyprctl workspacerules -j; echo @@@; hyprctl activewindow -j; echo @@@; hyprctl workspaces -j"],
             out => {
            const p = out.split("\n@@@\n")
            const j = s => { try { return JSON.parse(s) } catch (e) { return null } }
            const st = { clients: j(p[0]) ?? [], monitors: j(p[1]) ?? [], rules: j(p[2]) ?? [], active: j(p[3]), workspaces: j(p[4]) ?? [] }
            st.monName = {}
            for (const m of st.monitors) st.monName[m.id] = m.name
            cb(st)
        })
    }

    function wsNum(s) { const n = parseInt(s); return n === 0 ? 10 : n }   // "0" на клавише = 10

    // «Оконный» воркспейс монитора: тот, что на нём активен (воркспейсы между мониторами не переносим:
    // workspace-rules и реальное расположение воркспейсов могут не совпадать)
    function oneWorkspace(st, mon) {
        return mon.activeWorkspace.id > 0 ? mon.activeWorkspace.id : 1
    }

    // окна, которыми управляем: обычные воркспейсы и наш special:minimized
    function managed(st) {
        return st.clients.filter(c => c.mapped && (c.workspace.id > 0 || c.workspace.name === "special:minimized"))
    }

    function record(c, st) {
        const min = c.workspace.name === "special:minimized"
        return {
            addr: c.address, cls: c.class, title: c.title, mon: st.monName[c.monitor] ?? "",
            ws: min ? (snaps.minOrigin[c.address] ?? 0) : c.workspace.id,
            floating: c.floating, x: c.at[0], y: c.at[1], w: c.size[0], h: c.size[1],
            fs: c.fullscreen, fsc: c.fullscreenClient, pinned: c.pinned,
            order: c.focusHistoryID, minimized: min
        }
    }

    function snapshot(st) {
        const windows = {}
        for (const c of managed(st)) windows[c.address] = record(c, st)
        const activeWs = {}, oneWs = {}
        for (const m of st.monitors) { activeWs[m.name] = m.activeWorkspace.id; oneWs[m.name] = oneWorkspace(st, m) }
        const focusedMon = st.monitors.find(m => m.focused)?.name ?? ""
        return { windows: windows, activeWs: activeWs, oneWs: oneWs, focusedMon: focusedMon,
                 activeAddr: st.active?.address ?? "" }
    }

    // ───────────────────── строки диспетчеров ─────────────────────

    function sel(a) { return "window = \"address:" + a + "\"" }
    function dFloat(a, on) { return "hl.dsp.window.float({ action = \"" + (on ? "set" : "unset") + "\", " + sel(a) + " })" }
    function dMoveWs(a, ws) { return "hl.dsp.window.move({ workspace = " + ws + ", follow = false, " + sel(a) + " })" }
    function dMoveXY(a, x, y) { return "hl.dsp.window.move({ x = " + Math.round(x) + ", y = " + Math.round(y) + ", " + sel(a) + " })" }
    function dResize(a, w, h) { return "hl.dsp.window.resize({ x = " + Math.round(w) + ", y = " + Math.round(h) + ", relative = false, " + sel(a) + " })" }
    function dFs(a, internal, client) {
        return "hl.dsp.window.fullscreen_state({ internal = " + internal + ", client = " + client + ", action = \"set\", " + sel(a) + " })"
    }
    function dPin(a, on) { return "hl.dsp.window.pin({ action = \"" + (on ? "enable" : "disable") + "\", " + sel(a) + " })" }
    function dFocusWin(a) { return "hl.dsp.focus({ window = \"address:" + a + "\" })" }
    function dTop(a) { return "hl.dsp.window.alter_zorder({ mode = \"top\", " + sel(a) + " })" }
    function dFocusWs(id) { return "hl.dsp.focus({ workspace = " + id + " })" }
    function dFocusMon(name) { return "hl.dsp.focus({ monitor = \"" + name + "\" })" }

    // ───────────────────── вход в оконный режим ─────────────────────

    function workArea(st, monName) {
        const m = st.monitors.find(x => x.name === monName) ?? st.monitors[0]
        const sc = m.scale || 1
        const r = m.reserved ?? [0, 0, 0, 0]
        return { x: m.x + r[0], y: m.y + r[1], w: m.width / sc - r[0] - r[2], h: m.height / sc - r[1] - r[3] }
    }

    function clampRect(r, a) {
        const w = Math.min(Math.max(r.w, 240), a.w), h = Math.min(Math.max(r.h, 160), a.h)
        return { x: Math.min(Math.max(r.x, a.x), a.x + a.w - w), y: Math.min(Math.max(r.y, a.y), a.y + a.h - h), w: w, h: h }
    }

    function enterWindowed() {
        if (busy || mode === "windowed") return
        busy = true
        gather(st => { try {
            const tiling = snapshot(st)
            snaps.tiling = tiling
            mode = "windowed"
            writeMode()
            const prev = snaps.windowed?.windows ?? ({})
            const cascade = {}
            const list = managed(st).sort((a, b) => b.focusHistoryID - a.focusHistoryID)   // от старых к свежим
            const steps = [{ cmds: ["eval WM_SET(true)"] }]
            const after = []
            for (const c of list) {
                const rec = tiling.windows[c.address]
                const monName = rec.mon
                const area = workArea(st, monName)
                const one = tiling.oneWs[monName] ?? c.workspace.id
                const old = prev[c.address]
                const mem = Config.windowing.rememberGeometry ? snaps.classMemory[c.class + "@" + monName] : null
                let r
                if (old && old.mon === monName) r = { x: old.x, y: old.y, w: old.w, h: old.h }
                else if (mem) r = { x: mem.x, y: mem.y, w: mem.w, h: mem.h }
                else if (c.floating || tiling.activeWs[monName] === rec.ws) r = { x: rec.x, y: rec.y, w: rec.w, h: rec.h }
                else {
                    const n = cascade[monName] = (cascade[monName] ?? 0) + 1
                    const w = area.w * 0.6, h = area.h * 0.6
                    r = { x: area.x + (area.w - w) / 2 + (n - 1) * cascadeStep, y: area.y + (area.h - h) / 2 + (n - 1) * cascadeStep, w: w, h: h }
                }
                r = clampRect(r, area)
                const cmds = []
                if (c.fullscreen > 0) cmds.push(dFs(c.address, 0, 0))
                if (!c.floating) cmds.push(dFloat(c.address, true))
                if (c.workspace.id !== one) cmds.push(dMoveWs(c.address, one))
                cmds.push(dResize(c.address, r.w, r.h), dMoveXY(c.address, r.x, r.y))
                steps.push({ cmds: cmds }, { wait: 40 })
                if (old?.fs > 0) after.push(dFs(c.address, old.fs, old.fsc))
                delete snaps.minOrigin[c.address]
            }
            // фокус от старых окон к свежим, затем активные воркспейсы мониторов; главный монитор — последним
            steps.push({ cmds: list.reduce((acc, c) => acc.concat([dFocusWin(c.address), dTop(c.address)]), []) })
            const mons = Object.keys(tiling.oneWs).sort((a, b) => (a === tiling.focusedMon) - (b === tiling.focusedMon))
            steps.push({ cmds: mons.map(m => dFocusMon(m)) })
            steps.push({ cmds: after })
            if (tiling.activeAddr) steps.push({ cmds: [dFocusWin(tiling.activeAddr)] })
            runSteps(steps, () => gather(st2 => { snaps.windowed = snapshot(st2); save(); busy = false; Hyprland.refreshToplevels() }))
        } catch (e) { console.warn("winmode: enter failed:", e); mode = "tiling"; writeMode(); busy = false } })
    }

    // ───────────────────── возврат в тайлинг ─────────────────────

    function targetWorkspace(c, st, tiling, rec) {
        if (rec && rec.ws > 0) return rec.ws
        const mon = st.monName[c.monitor]
        if (Config.windowing.newWindowPolicy === "last") return tiling.activeWs[mon] ?? 1
        // 1. правило windows.lua; 2. окна того же класса на этом мониторе; 3. воркспейс до входа
        const home = homeRules[(c.class ?? "").toLowerCase()]
        // воркспейс по правилу годится, только если он живёт на этом же мониторе
        if (home && st.workspaces.some(w => w.id === home && w.monitor === mon)) return home
        for (const o of Object.values(tiling.windows))
            if (o.cls === c.class && o.mon === mon && o.ws > 0) return o.ws
        return tiling.activeWs[mon] ?? 1
    }

    function leaveWindowed() {
        if (busy || mode !== "windowed") return
        busy = true
        gather(st => { try {
            const wsnap = snapshot(st)
            snaps.windowed = wsnap
            rememberClasses(wsnap)
            const tiling = snaps.tiling ?? { windows: {}, activeWs: {}, oneWs: {}, focusedMon: "", activeAddr: "" }
            mode = "tiling"
            writeMode()
            const list = managed(st)
            const items = list.map(c => {
                // окно, перетащенное на другой монитор, считаем новым для него
                const r0 = tiling.windows[c.address]
                // у свёрнутого окна монитор не показателен: доверяем снимку
                const rec = r0 && (r0.mon === st.monName[c.monitor] || c.workspace.id < 0) ? r0 : null
                return { c: c, rec: rec, ws: targetWorkspace(c, st, tiling, rec) }
            })
            // по воркспейсам, внутри — в порядке «слева направо, сверху вниз» по снимку тайлинга
            const key = it => it.rec ? [it.rec.x, it.rec.y] : [1e9, 1e9]
            items.sort((a, b) => a.ws - b.ws || key(a)[0] - key(b)[0] || key(a)[1] - key(b)[1])
            const steps = [{ cmds: ["eval WM_SET(false)"] }]
            const after = []
            const placed = {}        // воркспейс → уже посаженные в дерево окна (снимок тайлинга)
            for (const it of items) {
                const a = it.c.address
                const cmds = []
                if (it.c.fullscreen > 0) cmds.push(dFs(a, 0, 0))
                if (it.c.workspace.id !== it.ws) cmds.push(dMoveWs(a, it.ws))
                const stayFloating = it.rec?.floating
                if (!stayFloating) {
                    // dwindle сажает новое окно по позиции курсора: задаём сторону явно относительно соседа
                    const nb = it.rec ? neighbour(it.rec, placed[it.ws] ?? []) : splitLargest(placed[it.ws] ?? [])
                    if (nb) cmds.push(dFocusWin(nb.addr), "hl.dsp.layout(\"preselect " + nb.dir + "\")")
                    cmds.push(dFloat(a, false))
                    if (it.rec) (placed[it.ws] = placed[it.ws] ?? []).push(it.rec)
                }
                steps.push({ cmds: cmds }, { wait: 120 })
                if (it.rec?.fs > 0) after.push(dFs(a, it.rec.fs, it.rec.fsc))
            }
            // размеры: два прохода, второй после того, как дерево осело
            // на воркспейсах с новыми окнами размеры из снимка не возвращаем: иначе новое окно сожмётся
            const dirty = new Set(items.filter(it => !it.rec).map(it => it.ws))
            const sizes = []
            for (const it of items) {
                if (!it.rec || (dirty.has(it.ws) && !it.rec.floating)) continue
                sizes.push(dResize(it.c.address, it.rec.w, it.rec.h))
                if (it.rec.floating) sizes.push(dMoveXY(it.c.address, it.rec.x, it.rec.y))
            }
            steps.push({ cmds: sizes }, { wait: 120 }, { cmds: sizes })
            steps.push({ gather: st2 => verifySteps(st2, tiling, dirty) })
            const focus = items.filter(it => it.rec).sort((x, y) => y.rec.order - x.rec.order).map(it => dFocusWin(it.c.address))
            const fresh = items.filter(it => !it.rec).length
            if (fresh > 0) steps.push({ notify: fresh })
            steps.push({ cmds: after.concat(focus) })
            const mons = Object.keys(tiling.activeWs).sort((a, b) => (a === tiling.focusedMon) - (b === tiling.focusedMon))
            steps.push({ cmds: mons.map(m => dFocusWs(tiling.activeWs[m])) })
            if (tiling.activeAddr) steps.push({ cmds: [dFocusWin(tiling.activeAddr)] })
            runSteps(steps, () => { save(); busy = false; Hyprland.refreshToplevels() })
        } catch (e) { console.warn("winmode: leave failed:", e); busy = false } })
    }

    // окно без записи в снимке: делим пополам самое большое из уже стоящих (не позиция курсора)
    function splitLargest(others) {
        let best = null
        for (const o of others) if (!best || o.w * o.h > best.w * best.h) best = o
        return best ? { addr: best.addr, dir: best.w >= best.h ? "r" : "d" } : null
    }

    // ближайший сосед из уже посаженных окон и сторона, с которой к нему надо подсадить окно r
    function neighbour(r, others) {
        let best = null, bestLen = 0
        for (const o of others) {
            const ox = Math.min(r.x + r.w, o.x + o.w) - Math.max(r.x, o.x)
            const oy = Math.min(r.y + r.h, o.y + o.h) - Math.max(r.y, o.y)
            let dir = null, len = 0
            if (oy > 0 && r.x >= o.x + o.w - 4) { dir = "r"; len = oy }
            else if (oy > 0 && r.x + r.w <= o.x + 4) { dir = "l"; len = oy }
            else if (ox > 0 && r.y >= o.y + o.h - 4) { dir = "d"; len = ox }
            else if (ox > 0 && r.y + r.h <= o.y + 4) { dir = "u"; len = ox }
            if (dir && len > bestLen) { best = { addr: o.addr, dir: dir }; bestLen = len }
        }
        return best
    }

    // третий проход только для тайловых окон, чей размер разошёлся со снимком
    function verifySteps(st, tiling, dirty) {
        const cmds = []
        for (const c of st.clients) {
            const r = tiling.windows[c.address]
            if (!r || r.floating || c.floating || dirty.has(c.workspace.id)) continue
            if (Math.abs(c.size[0] - r.w) > 2 || Math.abs(c.size[1] - r.h) > 2) cmds.push(dResize(c.address, r.w, r.h))
        }
        return cmds.length ? [{ cmds: cmds }] : []
    }

    function rememberClasses(snap) {
        if (!Config.windowing.rememberGeometry) return
        const mem = snaps.classMemory
        for (const r of Object.values(snap.windows))
            if (!r.minimized) mem[r.cls + "@" + r.mon] = { x: r.x, y: r.y, w: r.w, h: r.h }
    }

    // ───────────────────── сворачивание ─────────────────────

    function minimize(address) {
        gather(st => {
            const c = st.clients.find(x => x.address === address)
            if (!c || c.workspace.id <= 0) return
            snaps.minOrigin[address] = c.workspace.id
            save()
            batch([dMoveWs(address, "\"special:minimized\"")], () => Hyprland.refreshToplevels())
        })
    }

    // свернуть активное окно (кнопка заголовка: клик по полосе сначала фокусирует окно)
    function minimizeActive() {
        const t = Hyprland.activeToplevel
        if (t) minimize(address(t))
    }

    function address(t) { return t.address.startsWith("0x") ? t.address : "0x" + t.address }

    function unminimize(address) {
        gather(st => {
            const c = st.clients.find(x => x.address === address)
            if (!c || c.workspace.name !== "special:minimized") return
            const mon = st.monitors.find(m => m.id === c.monitor) ?? st.monitors[0]
            const ws = snaps.minOrigin[address] ?? mon.activeWorkspace.id
            delete snaps.minOrigin[address]
            save()
            batch([dMoveWs(address, ws)], () => { raise(address); Hyprland.refreshToplevels() })
        })
    }

    // вывести окно на передний план и сфокусировать (для плавающих focus сам порядок не меняет)
    function raise(address) {
        // без переноса курсора на окно: no_warps включаем только на время фокуса
        batch(["eval hl.config({ cursor = { no_warps = true } })", dFocusWin(address), dTop(address),
               "eval hl.config({ cursor = { no_warps = false } })"], () => {})
    }

    // ───────────────────── публичное API ─────────────────────

    function toggle() { windowed ? leaveWindowed() : enterWindowed() }
    function set(m) { m === "windowed" ? enterWindowed() : leaveWindowed() }

    // ───────────────────── правила «домашних» воркспейсов ─────────────────────

    Process {
        id: rulesRead
        command: ["sh", "-c", "cat \"$HOME/.config/hypr/configs/windows.lua\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {}
                const re = /class\s*=\s*"([^"]+)"[^}]*\}\s*,\s*workspace\s*=\s*"(\d+)"/g
                let m
                while ((m = re.exec(text)) !== null) map[m[1].toLowerCase()] = parseInt(m[2])
                root.homeRules = map
            }
        }
    }
    function readHomeRules() { rulesRead.running = true }

    // ───────────────────── живое сохранение ─────────────────────

    Timer {
        interval: 4000
        repeat: true
        running: root.loaded && !root.busy
        onTriggered: root.gather(st => {
            if (root.busy) return
            root.updateLayout(st)
            if (!root.windowed || root.hasAbsent()) return
            root.snaps.windowed = root.snapshot(st)
            root.rememberClasses(root.snaps.windowed)
            root.save()
        })
    }

    // ───────────────────── мониторы: отключение и подключение ─────────────────────

    property var layout: ({})        // монитор → { ws: [воркспейсы на нём], active: активный }
    property var absent: ({})        // отключённые мониторы, пока не вернулись
    property var parked: ({})        // address → запись окна, эвакуированного с отключённого монитора

    function hasAbsent() { return Object.keys(absent).length > 0 }

    // пока какой-то монитор отсутствует, раскладку не обновляем: она нужна для возврата
    function updateLayout(st) {
        if (hasAbsent()) return
        const l = {}
        for (const m of st.monitors)
            l[m.name] = { ws: st.workspaces.filter(w => w.monitor === m.name && w.id > 0).map(w => w.id),
                          active: m.activeWorkspace.id }
        layout = l
    }

    function onMonitorRemoved(name) {
        absent[name] = true
        if (!windowed) return
        waitTimer(700, evacuate)
    }

    // оконный режим: воркспейсы отключённого монитора переехали на оставшийся —
    // собираем все окна на его активный воркспейс
    function evacuate() {
        if (busy) { waitTimer(500, evacuate); return }
        busy = true
        gather(st => { try {
            const wins = snaps.windowed?.windows ?? ({})
            const cmds = []
            for (const c of managed(st)) {
                const m = st.monitors.find(x => x.id === c.monitor)
                if (!m || c.workspace.id < 0 || c.workspace.id === m.activeWorkspace.id) continue
                const rec = wins[c.address] ?? record(c, st)
                parked[c.address] = rec
                const area = workArea(st, m.name)
                const r = clampRect({ x: area.x + 40, y: area.y + 40, w: rec.w, h: rec.h }, area)
                cmds.push(dMoveWs(c.address, m.activeWorkspace.id), dResize(c.address, r.w, r.h), dMoveXY(c.address, r.x, r.y))
            }
            runSteps([{ cmds: cmds }], () => { busy = false; Hyprland.refreshToplevels() })
        } catch (e) { console.warn("winmode: evacuate failed:", e); busy = false } })
    }

    function onMonitorAdded(name) {
        waitTimer(900, () => restoreMonitor(name))
    }

    // вернуть воркспейсы на «свои» мониторы и (в оконном режиме) окна на их монитор
    function restoreMonitor(name) {
        if (busy) { waitTimer(500, () => restoreMonitor(name)); return }
        busy = true
        gather(st => { try {
            const steps = []
            const back = []
            for (const addr of Object.keys(parked)) {
                const rec = parked[addr]
                const c = st.clients.find(x => x.address === addr)
                const l = layout[rec.mon]
                if (!c || !l || rec.mon !== name) continue
                const area = workArea(st, rec.mon)
                const r = clampRect(rec, area)
                back.push(dMoveWs(addr, l.active), dResize(addr, r.w, r.h), dMoveXY(addr, r.x, r.y))
                delete parked[addr]
            }
            steps.push({ cmds: back }, { wait: 250 })
            steps.push({ gather: st2 => {
                const cmds = []
                for (const mon of Object.keys(layout)) {
                    if (!st2.monitors.some(m => m.name === mon)) continue
                    for (const id of layout[mon].ws) {
                        const cur = st2.workspaces.find(w => w.id === id)
                        if (cur && cur.monitor !== mon) cmds.push("hl.dsp.workspace.move({ workspace = " + id + ", monitor = \"" + mon + "\" })")
                    }
                }
                const focused = st2.monitors.find(m => m.focused)?.name ?? ""
                const mons = Object.keys(layout).filter(m => st2.monitors.some(x => x.name === m))
                    .sort((a, b) => (a === focused) - (b === focused))
                // активный воркспейс каждого монитора: если он успел исчезнуть (пустой), создаём
                // заново на этом мониторе, а не там, куда его отправит workspace-rule
                for (const mon of mons) {
                    const id = layout[mon].active
                    cmds.push(dFocusMon(mon), dFocusWs(id),
                              "hl.dsp.workspace.move({ workspace = " + id + ", monitor = \"" + mon + "\" })")
                }
                return [{ cmds: cmds }]
            } })
            runSteps(steps, () => { delete absent[name]; busy = false; Hyprland.refreshToplevels() })
        } catch (e) { console.warn("winmode: restore failed:", e); delete absent[name]; busy = false } })
    }

    // QS перезапустился или Hyprland перечитал конфиг: winmode.lua сам читает winmode.mode,
    // а на всякий случай повторно ставим флаги
    // новые окна приходят в Hyprland.toplevels с пустым lastIpcObject — без обновления
    // док (и всё, что читает lastIpcObject) их не видит
    Timer {
        id: refreshTimer
        interval: 120
        onTriggered: Hyprland.refreshToplevels()
    }
    readonly property var refreshEvents: ["openwindow", "closewindow", "movewindowv2", "changefloatingmode",
                                          "fullscreen", "windowtitlev2", "minimized", "activewindowv2"]

    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (root.refreshEvents.includes(ev.name)) refreshTimer.restart()
            if (ev.name === "configreloaded" && root.loaded && !root.busy)
                root.exec(["hyprctl", "eval", "WM_SET(" + (root.windowed ? "true" : "false") + ")"], () => {})
            else if (ev.name === "monitorremovedv2" && root.loaded) root.onMonitorRemoved(ev.data.split(",")[1])
            else if (ev.name === "monitoraddedv2" && root.loaded) root.onMonitorAdded(ev.data.split(",")[1])
            else if (ev.name === "minimized" && root.loaded) {
                const p = ev.data.split(",")
                p[1] === "1" ? root.minimize("0x" + p[0].replace(/^0x/, "")) : root.unminimize("0x" + p[0].replace(/^0x/, ""))
            }
        }
    }
}
