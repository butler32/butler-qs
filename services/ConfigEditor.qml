pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "LuaConf.js" as Lua
import "ConfigKinds.js" as Kinds
import "ConfigSplit.js" as Split
import "ConfigOptions.js" as Opts
import "ConfigCatalog.js" as Cat
import "../i18n"

// Редактор конфигов: хранит тексты файлов программы в памяти, разбирает их (LuaConf.js) и правит
// исходник по месту — формы в components/configs/ только вызывают функции отсюда. Тексты, которые
// не удалось разобрать, никогда не теряются: они остаются как есть и видны во вкладке «Файлы».
// Рисует всё components/ConfigEditorWindow.qml.
//
// Ссылка на запись (ref) = "<файл>|<индекс инструкции>[/<индекс в теле function>]".
// Все функции чтения зависят от `rev`, поэтому работают внутри биндингов и обновляются после правок.
Singleton {
    id: root

    property bool open: false
    property string provider: "hyprland"
    property string section: "windows"          // id секции или "file:<путь>"

    property int rev: 0
    property var texts: ({})                    // путь → текущий текст (с несохранёнными правками)
    property var origs: ({})                    // путь → текст на диске
    property var docs: ({})                     // путь → результат Lua.parse
    property var writers: ({})                  // путь → FileView

    // "", "saving", "ok", "error", "rejected", "backupfailed"
    property string status: ""
    property string statusDetail: ""
    property var saving: []
    property int savedCount: 0
    property var prev: ({})                     // что было на диске до последнего сохранения (для отката)
    readonly property bool dirty: dirtyList().length > 0
    readonly property bool busy: status === "saving"

    signal textReplaced(string path)            // текст изменён не пользователем в «Файлах»

    readonly property string home: Quickshell.env("HOME")
    readonly property string backupDir: Quickshell.statePath("config-backups")
    readonly property var providers: [
        {
            id: "hyprland",
            icon: "",
            dir: Quickshell.env("BUTLER_HYPR_DIR") || home + "/.config/hypr",   // переменная — для тестов на копии
            // порядок = порядок require в hyprland.lua; generated — перезаписывается темой (только чтение)
            files: [
                { path: "hyprland.lua" },
                { path: "configs/programs.lua" },
                { path: "configs/monitors.lua" },
                { path: "configs/autostart.lua" },
                { path: "configs/environment.lua" },
                { path: "configs/permissions.lua" },
                { path: "configs/look.lua" },
                { path: "configs/theme_colors.lua", generated: true },
                { path: "configs/devices.lua" },
                { path: "configs/misc.lua" },
                { path: "configs/input.lua" },
                { path: "configs/keybindings.lua" },
                { path: "configs/workspaces.lua" },
                { path: "configs/windows.lua" },
                { path: "hyprlock.conf", generated: true, plain: true }
            ]
        }
    ]

    readonly property var sections: Cat.SECTIONS
    readonly property var actions: Cat.ACTIONS
    function isExpr(text) { return Lua.isExpr(String(text).trim()) }

    // Описания полей записей из каталога (формы читают их отсюда)
    readonly property var monitorSpecs: [{ key: "output", ctl: "select", from: "monitors", title: Cat.T("Какой монитор", "Which monitor"),
                                           hint: Cat.T("Выбор среди подключённых мониторов.", "Pick among connected monitors.") }].concat(Cat.MONITOR_FIELDS)
    readonly property var wsSpecs: [
        { key: "workspace", ctl: "select", from: "workspaces", asString: true, title: Cat.T("Рабочий стол", "Workspace") },
        { key: "monitor", ctl: "select", from: "monitorsNone", title: Cat.T("Закрепить за монитором", "Pin to monitor"),
          hint: Cat.T("Этот стол будет открываться именно на выбранном мониторе.", "This workspace will always open on the chosen monitor.") }
    ].concat(Cat.WS_FIELDS)
    readonly property var wsExtras: Cat.WS_FIELDS
    readonly property var deviceSpecs: Cat.DEVICE_FIELDS
    readonly property var springSpecs: [
        { key: "mass", ctl: "num", min: 0.1, max: 10, step: 0.1, def: 1, title: Cat.T("Масса", "Mass"), hint: Cat.T("Чем больше, тем инертнее.", "Heavier feels more sluggish.") },
        { key: "stiffness", ctl: "num", min: 1, max: 300, step: 1, def: 70, title: Cat.T("Жёсткость", "Stiffness"), hint: Cat.T("Чем больше, тем быстрее возвращается.", "Higher snaps back faster.") },
        { key: "dampening", ctl: "num", min: 1, max: 60, step: 0.5, def: 15, title: Cat.T("Затухание", "Damping"), hint: Cat.T("Чем меньше, тем дольше колеблется.", "Lower oscillates longer.") }
    ]
    readonly property var gestureSpecs: Cat.GESTURE_FIELDS
    readonly property var matchFields: Cat.MATCH_FIELDS
    readonly property var effects: Cat.EFFECTS
    readonly property var bindMods: Cat.MODS
    readonly property var bindFlags: Cat.BIND_FLAGS
    readonly property var envPresets: Cat.ENV_PRESETS
    readonly property var keyOptions: Cat.keyList().map(o => ({ value: o.value, label: o.ru }))
    readonly property var curvePresets: Cat.CURVE_PRESETS
    readonly property var stylePct: Cat.STYLES_WITH_PERCENT

    // Текст каталога на текущем языке ({ru, en}); читает I18n.lang, поэтому работает в биндингах.
    function tx(t) { return t ? (t[I18n.lang] ?? t.en ?? "") : "" }

    function current() {
        for (const p of providers) if (p.id === provider) return p
        return providers[0]
    }
    function fullPath(path) { return current().dir + "/" + path }
    function fileInfo(path) {
        for (const f of current().files) if (f.path === path) return f
        return { path: path }
    }
    function isGenerated(path) { return !!fileInfo(path).generated }

    function openWindow() {
        if (status !== "saving") { status = ""; statusDetail = "" }
        open = true
        refreshInfo()
    }
    function refreshInfo() {
        HyprInfo.refresh()
        HyprInfo.fetchDefaults(Opts.OPTIONS.map(o => o[0]))
    }
    function closeWindow() { open = false }
    function select(id) { section = id }

    // ─── файлы ────────────────────────────────────────────────────────────────

    function textOf(path) { void rev; return texts[path] ?? "" }
    function doc(path) { void rev; return docs[path] ?? null }
    function isDirty(path) { void rev; return texts[path] !== undefined && texts[path] !== origs[path] }
    function dirtyList() {
        void rev
        const out = []
        for (const f of current().files) if (!f.generated && isDirty(f.path)) out.push(f.path)
        return out
    }
    function rawCount(d) {
        let n = 0
        if (d) for (const s of d.stmts) if (s.kind === "raw") n++
        return n
    }

    function fileLoaded(path, t) {
        if (isDirty(path)) return               // несохранённые правки важнее диска
        texts[path] = t
        origs[path] = t
        docs[path] = current().files.find(f => f.path === path)?.plain ? { src: t, stmts: [] } : Lua.parse(t)
        rev++
        textReplaced(path)
    }

    // Файл «по роли» (configs/monitors.lua …) может не существовать — например, когда весь конфиг лежит
    // в одном hyprland.lua. Тогда новые записи кладутся рядом с такими же уже имеющимися, а если таких
    // нет — файл создаётся и подключается через require в главном файле.
    function ensureFile(path) {
        if (docs[path]) return true
        const main = current().files[0].path
        if (!docs[main] || path === main) return false
        const mod = path.replace(/\.lua$/, "").replace(/\//g, ".")
        if (!commit(main, Lua.appendStmt(texts[main], 'require("' + mod + '")'))) return false
        texts[path] = ""
        docs[path] = Lua.parse("")
        rev++
        return true
    }
    function placeFile(preferred, fn) {
        if (docs[preferred]) return preferred
        let found = null
        for (const f of current().files) {
            const d = docs[f.path]
            if (!d || f.generated || f.plain) continue
            for (const st of d.stmts) if (Lua.callName(st) === fn) found = f.path
        }
        if (found) return found
        return ensureFile(preferred) ? preferred : current().files[0].path
    }

    // Разбиение главного файла по смыслу (ConfigSplit.js). Кэш — поля обычного объекта (см. _cache).
    readonly property var _split: ({ rev: -1, plan: null })
    function splitPlan() {
        void rev
        if (_split.rev === rev) return _split.plan
        const main = current().files[0].path
        let plan = null
        if (docs[main] && !current().files[0].plain) {
            plan = Split.plan(texts[main], current().files.filter(f => docs[f.path] && f.path !== main).map(f => f.path))
            if (plan && !plan.moved) plan = null
        }
        _split.plan = plan
        _split.rev = rev
        return plan
    }
    readonly property bool splittable: splitPlan() !== null

    function splitIntoFiles() {
        const plan = splitPlan()
        if (!plan) return false
        const main = current().files[0].path
        let ok = true
        for (const f of plan.files) {
            if (docs[f.path]) ok = commit(f.path, Lua.appendStmt(texts[f.path], f.text.replace(/\s+$/, ""))) && ok
            else { texts[f.path] = f.text; docs[f.path] = Lua.parse(f.text) }
        }
        rev++
        if (ok) ok = commit(main, plan.main)
        if (!ok) { revert(); return false }
        for (const f of plan.files) textReplaced(f.path)
        return true
    }

    // Принять новый текст файла из форм. Правка, после которой Lua перестаёт разбираться, отклоняется.
    function commit(path, src) {
        if (src === null || src === undefined || src === texts[path]) return false
        if (isGenerated(path)) return false
        const d = Lua.parse(src)
        if (d.error || rawCount(d) > rawCount(docs[path])) {
            status = "rejected"
            statusDetail = d.error ?? ""
            return false
        }
        texts[path] = src
        docs[path] = d
        status = ""
        rev++
        textReplaced(path)
        return true
    }

    // Правка текста во вкладке «Файлы»: принимается как есть (разбор может быть с ошибкой).
    function setSource(path, src) {
        if (isGenerated(path) || src === texts[path]) return
        texts[path] = src
        docs[path] = Lua.parse(src)
        status = ""
        rev++
    }

    function revert() {
        for (const p of dirtyList()) {
            if (origs[p] === undefined) { delete texts[p]; delete docs[p] }    // файл, созданный редактором
            else { texts[p] = origs[p]; docs[p] = Lua.parse(origs[p]) }
            textReplaced(p)
        }
        status = ""
        rev++
    }

    // ─── опции hl.config ──────────────────────────────────────────────────────

    readonly property var optionTypes: {
        const m = {}
        for (const o of Opts.OPTIONS) m[o[0]] = o[1]
        return m
    }
    // кэш — поля обычного объекта, а не свойства: запись в свойство внутри биндинга дала бы цикл
    readonly property var _cache: ({ idx: {}, rev: -1 })

    function walkConfig(tbl, prefix, stmtTbl, file, generated, out) {
        for (const f of tbl.fields) {
            if (f.key === null) continue
            const p = prefix ? prefix + "." + f.key : f.key
            if (optionTypes[p] !== undefined) out[p] = { file: file, tbl: stmtTbl, field: f, generated: generated }
            else if (f.value.type === "table") walkConfig(f.value, p, stmtTbl, file, generated, out)
        }
    }

    // Последнее (действующее) определение каждой опции среди всех файлов по порядку загрузки.
    function optionIndex() {
        void rev
        if (_cache.rev === rev) return _cache.idx
        const out = {}
        for (const f of current().files) {
            const d = docs[f.path]
            if (!d) continue
            for (const st of d.stmts) {
                if (Lua.callName(st) !== "hl.config") continue
                const tbl = st.call.args[0]
                if (tbl && tbl.type === "table") walkConfig(tbl, "", tbl, f.path, !!f.generated, out)
            }
        }
        _cache.idx = out
        _cache.rev = rev
        return out
    }

    function getOption(dotPath) {
        const o = optionIndex()[dotPath]
        if (!o) return { set: false }
        const node = o.field.value, k = Lua.kindOf(node)
        return {
            set: true, kind: k === "table" ? "expr" : k, value: Lua.valueOf(node),
            text: Lua.srcOf(texts[o.file], node), file: o.file, generated: o.generated
        }
    }

    function setOption(dotPath, kind, value) {
        const text = kind === "expr" ? String(value).trim() : Lua.lit(kind, value)
        if (kind === "expr" && !Lua.isExpr(text)) { status = "rejected"; return false }
        const path = dotPath.split(".")
        const o = optionIndex()[dotPath]
        if (o) return o.generated ? false : commit(o.file, Lua.setPath(texts[o.file], o.tbl, path, text))

        const file = placeFile(Kinds.OPTION_FILE[path[0]] ?? Kinds.OPTION_FILE_DEFAULT, "hl.config")
        const d = docs[file]
        if (!d) return false
        let best = null
        for (const st of d.stmts) {
            if (Lua.callName(st) !== "hl.config") continue
            const tbl = st.call.args[0]
            if (!tbl || tbl.type !== "table") continue
            if (Lua.findField(tbl, path[0])) { best = tbl; break }
            if (!best) best = tbl
        }
        if (best) return commit(file, Lua.setPath(texts[file], best, path, text))
        const body = path[0] + " = " + Lua.nestLiteral(path.slice(1), text)
        return commit(file, Lua.appendStmt(texts[file], "hl.config({\n    " + body + ",\n})"))
    }

    function unsetOption(dotPath) {
        const o = optionIndex()[dotPath]
        if (!o || o.generated) return false
        return commit(o.file, Lua.removePath(texts[o.file], o.tbl, dotPath.split(".")))
    }

    function optionsOf(groups) {
        const out = []
        for (const o of Opts.OPTIONS) if (groups.includes(o[0].split(".")[0])) out.push({ path: o[0], type: o[1] })
        return out
    }

    // ─── записи-таблицы (hl.monitor, hl.window_rule, …) ───────────────────────

    function resolve(ref) {
        const i = ref.indexOf("|")
        const file = ref.slice(0, i), loc = ref.slice(i + 1).split("/")
        const d = docs[file]
        if (!d) return null
        let st = d.stmts[+loc[0]]
        if (st && loc.length > 1) {
            const fn = st.call ? st.call.args.find(a => a.type === "function") : null
            st = fn ? fn.body[+loc[1]] : null
        }
        return st ? { file: file, st: st, src: texts[file] } : null
    }

    function summaryOf(fields, skip) {
        const parts = []
        for (const f of fields) {
            if (skip.includes(f.key) || f.kind === "table" || f.key === "name") continue
            parts.push(f.key + "=" + (f.kind === "str" ? f.value : f.text))
            if (parts.length >= 3) break
        }
        return parts.join("  ").replace(/\s+/g, " ")
    }

    function entries(kindId) {
        void rev
        const K = Kinds.KINDS[kindId], out = []
        for (const f of current().files) {
            const d = docs[f.path]
            if (!d) continue
            d.stmts.forEach((st, si) => {
                if (Lua.callName(st) !== K.fn) return
                const args = st.call.args, tbl = args[K.tableArg]
                if (!tbl || tbl.type !== "table") return
                const fields = Lua.describeTable(texts[f.path], tbl)
                const head = K.head && args[0] && args[0].type === "str" ? args[0].v : ""
                const titles = K.title.map(k => fields.find(x => x.key === k)).filter(x => x).map(x => x.value ?? x.text)
                const match = fields.find(x => x.key === "match")
                let title = head || titles.join(" · ")
                if (!title && match) { const c = match.fields.find(x => x.key === "class"); title = c ? String(c.value) : "" }
                out.push({
                    id: f.path + "|" + si, ref: f.path + "|" + si, kind: kindId, file: f.path, generated: !!f.generated,
                    title: title, head: head, hasHead: !!K.head, fields: fields,
                    summary: summaryOf(fields, K.title)
                })
            })
        }
        return out
    }



    function setEntryRaw(ref, path, text) {
        const r = resolve(ref)
        if (!r) return false
        const K = Kinds.KINDS[Kinds.KIND_BY_FN[Lua.callName(r.st)]]
        return commit(r.file, Lua.setPath(r.src, r.st.call.args[K.tableArg], path, text))
    }
    function setEntryField(ref, path, kind, value) {
        if (kind === "expr" && !Lua.isExpr(String(value).trim())) { status = "rejected"; return false }
        return setEntryRaw(ref, path, kind === "expr" ? String(value).trim() : Lua.lit(kind, value))
    }
    function removeEntryField(ref, path) {
        const r = resolve(ref)
        if (!r) return false
        const K = Kinds.KINDS[Kinds.KIND_BY_FN[Lua.callName(r.st)]]
        return commit(r.file, Lua.removePath(r.src, r.st.call.args[K.tableArg], path))
    }
    function setEntryHead(ref, value) {
        const r = resolve(ref)
        const a = r ? r.st.call.args[0] : null
        if (!a || a.type !== "str") return false
        return commit(r.file, Lua.replace(r.src, a.s, a.e, Lua.quote(value)))
    }
    function removeEntry(ref) {
        const r = resolve(ref)
        return r ? commit(r.file, Lua.stmtRemove(r.src, r.st)) : false
    }

    // Новая запись: после последней такой же в файле вида, иначе в конец файла.
    function insertStatement(file, fn, text) {
        file = placeFile(file, fn)
        const d = docs[file]
        let last = null
        for (const st of d.stmts) if (Lua.callName(st) === fn) last = st
        return commit(file, last ? Lua.insertAfterStmt(texts[file], last, text) : Lua.appendStmt(texts[file], text))
    }
    function addEntry(kindId) {
        const K = Kinds.KINDS[kindId]
        return insertStatement(K.file, K.fn, K.template)
    }

    // ─── бинды ────────────────────────────────────────────────────────────────

    function localStrings(d) {
        // строковые переменные: свои local файла + глобальные (mainMod = "SUPER" в другом файле, после разбиения)
        const m = {}
        const add = (doc, own) => {
            if (doc) for (const st of doc.stmts) {
                if (st.kind === "local" && own && st.value && st.value.type === "str") m[st.name] = st.value.v
                else if (st.kind === "assign" && st.target && st.target.type === "name" && st.value && st.value.type === "str") m[st.target.v] = st.value.v
            }
        }
        for (const f of current().files) if (docs[f.path] !== d) add(docs[f.path], false)
        add(d, true)
        return m
    }
    function flattenConcat(n) { return n.type === "bin" && n.op === ".." ? flattenConcat(n.l).concat(flattenConcat(n.r)) : [n] }

    // Строка клавиш бинда → текст с подставленными локальными строками; null, если выражение сложнее.
    function keyText(node, locals) {
        if (!node) return null
        if (node.type === "str") return node.v
        const parts = flattenConcat(node)
        let out = ""
        for (let i = 0; i < parts.length; i++) {
            const p = parts[i]
            if (p.type === "str") out += p.v
            else if (p.type === "name" && i === 0 && locals[p.v] !== undefined) out += locals[p.v]
            else return null
        }
        return out
    }

    function dotaAvailable() { void rev; return (texts["hyprland.lua"] ?? "").indexOf("unless_dota") >= 0 }

    function binds() {
        void rev
        const out = []
        for (const f of current().files) {
            const d = docs[f.path]
            if (!d) continue
            const locals = localStrings(d)
            d.stmts.forEach((st, si) => {
                if (Lua.callName(st) !== "hl.bind") return
                const a = st.call.args
                const info = {
                    id: f.path + "|" + si, ref: f.path + "|" + si, file: f.path, editable: false,
                    raw: Lua.srcOf(texts[f.path], st), mods: [], key: "", wrap: false, exec: false, command: "",
                    dispatcher: "", act: null, opts: [], generated: !!f.generated
                }
                const kt = a.length >= 2 ? keyText(a[0], locals) : null
                if (kt !== null) {
                    const parts = kt.split("+").map(x => x.trim()).filter(x => x !== "")
                    info.key = parts.length ? parts[parts.length - 1] : ""
                    info.mods = parts.slice(0, -1)
                    let inner = a[1]
                    if (inner.type === "call" && Lua.dotted(inner.fn) === "unless_dota" && inner.args.length === 1) {
                        info.wrap = true
                        inner = inner.args[0]
                    }
                    info.dispatcher = Lua.srcOf(texts[f.path], inner)
                    info.act = parseAction(info.dispatcher)
                    if (inner.type === "call" && Lua.dotted(inner.fn) === "hl.dsp.exec_cmd" && inner.args.length === 1
                        && inner.args[0].type === "str") {
                        info.exec = true
                        info.command = inner.args[0].v
                    }
                    if (a[2] && a[2].type === "table") info.opts = Lua.describeTable(texts[f.path], a[2])
                    info.editable = !f.generated && (a[2] === undefined || a[2].type === "table")
                }
                out.push(info)
            })
        }
        return out
    }

    function modVarFor(file, mod) {
        const l = localStrings(docs[file])
        if (l.mainMod === mod) return "mainMod"
        for (const k in l) if (l[k] === mod && Kinds.MODIFIERS.includes(mod)) return k
        return ""
    }

    function keyExpr(file, mods, key) {
        if (mods.length === 0) return Lua.quote(key)
        const v = modVarFor(file, mods[0])
        const rest = mods.slice(1).concat([key]).join(" + ")
        return v ? v + " .. " + Lua.quote(" + " + rest) : Lua.quote(mods.concat([key]).join(" + "))
    }

    function setBindKey(ref, mods, key) {
        const r = resolve(ref)
        if (!r || key.trim() === "") { status = "rejected"; return false }
        const a = r.st.call.args[0]
        return commit(r.file, Lua.replace(r.src, a.s, a.e, keyExpr(r.file, mods, key.trim())))
    }
    function setBindDispatcher(ref, text, wrap) {
        const r = resolve(ref)
        text = String(text).trim()
        if (!r || !Lua.isExpr(text)) { status = "rejected"; return false }
        const a = r.st.call.args[1]
        return commit(r.file, Lua.replace(r.src, a.s, a.e, wrap ? "unless_dota(" + text + ")" : text))
    }
    function setBindOpt(ref, key, kind, value) {
        const r = resolve(ref)
        if (!r) return false
        const a = r.st.call.args, text = kind === "expr" ? String(value) : Lua.lit(kind, value)
        if (a[2] && a[2].type === "table") return commit(r.file, Lua.setPath(r.src, a[2], [key], text))
        if (a.length === 2) {
            const close = r.st.call.close
            return commit(r.file, r.src.slice(0, close) + ", { " + key + " = " + text + " }" + r.src.slice(close))
        }
        return false
    }
    function removeBindOpt(ref, key) {
        const r = resolve(ref)
        const t = r ? r.st.call.args[2] : null
        return t && t.type === "table" ? commit(r.file, Lua.removePath(r.src, t, [key])) : false
    }
    function addBind() {
        const file = placeFile("configs/keybindings.lua", "hl.bind")
        const d = docs[file]
        const v = d ? modVarFor(file, "SUPER") : ""
        const keys = v ? v + ' .. " + X"' : '"SUPER + X"'
        return insertStatement(file, "hl.bind", "hl.bind(" + keys + ', hl.dsp.exec_cmd(""))')
    }

    // ─── переменные окружения и автозапуск ───────────────────────────────────

    function envs() {
        void rev
        const out = []
        for (const f of current().files) {
            const d = docs[f.path]
            if (!d) continue
            d.stmts.forEach((st, si) => {
                if (Lua.callName(st) !== "hl.env") return
                const a = st.call.args
                if (a.length < 2 || a[0].type !== "str" || a[1].type !== "str") return
                out.push({ id: f.path + "|" + si, ref: f.path + "|" + si, file: f.path, name: a[0].v, value: a[1].v })
            })
        }
        return out
    }
    function setEnv(ref, name, value) {
        const r = resolve(ref)
        if (!r || !/^[A-Za-z_][A-Za-z0-9_]*$/.test(name)) { status = "rejected"; return false }
        const a = r.st.call.args
        let s = Lua.replace(r.src, a[1].s, a[1].e, Lua.quote(value))
        s = Lua.replace(s, a[0].s, a[0].e, Lua.quote(name))
        return commit(r.file, s)
    }
    function addEnv(name, value) {
        return insertStatement("configs/environment.lua", "hl.env", "hl.env(" + Lua.quote(name || "NAME") + ", " + Lua.quote(value ?? "") + ")")
    }

    function startHooks() {
        const out = []
        for (const f of current().files) {
            const d = docs[f.path]
            if (!d) continue
            d.stmts.forEach((st, si) => {
                if (Lua.callName(st) !== "hl.on") return
                const a = st.call.args
                const fn = a.find(x => x.type === "function")
                if (a[0] && a[0].type === "str" && a[0].v === "hyprland.start" && fn) out.push({ file: f.path, si: si, fn: fn })
            })
        }
        return out
    }
    function execs() {
        void rev
        const out = []
        for (const h of startHooks()) {
            h.fn.body.forEach((st, ci) => {
                if (Lua.callName(st) !== "hl.exec_cmd") return
                const a = st.call.args[0]
                if (a && a.type === "str")
                    out.push({ id: h.file + "|" + h.si + "/" + ci, ref: h.file + "|" + h.si + "/" + ci, file: h.file, cmd: a.v })
            })
        }
        return out
    }
    function setExec(ref, cmd) {
        const r = resolve(ref)
        const a = r ? r.st.call.args[0] : null
        return a ? commit(r.file, Lua.replace(r.src, a.s, a.e, Lua.quote(cmd))) : false
    }

    // ─── значения для контролов ───────────────────────────────────────────────


    function wsList() {
        const out = []
        for (let i = 1; i <= 10; i++) out.push({ value: String(i), label: String(i) })
        out.push({ value: "special:magic", label: tx(Cat.T("Скрытый стол (scratchpad)", "Hidden workspace (scratchpad)")) })
        return out
    }

    // Элементы списка для select-контролов: { value, label }.
    function optionsFor(spec) {
        void HyprInfo.monitors
        if (spec.options) return spec.options.map(o => ({ value: o.value, label: tx(o) }))
        if (spec.from === "monitors" || spec.from === "monitorsNone") {
            const list = HyprInfo.monitors.map(m => ({ value: m.name, label: m.name, hint: m.description }))
            return spec.from === "monitorsNone"
                ? [{ value: "", label: tx(Cat.T("Нет", "None")) }].concat(list) : list
        }
        if (spec.from === "workspaces") return wsList()
        if (spec.from === "devices") return deviceOptions()
        return []
    }

    function modeOptions(monitorName) {
        const m = HyprInfo.monitorByName(monitorName)
        const out = [
            { value: "preferred", label: tx(Cat.T("Рекомендуемый", "Preferred")) },
            { value: "highres", label: tx(Cat.T("Максимальное разрешение", "Highest resolution")) },
            { value: "highrr", label: tx(Cat.T("Максимальная частота", "Highest refresh rate")) }
        ]
        if (m) {
            const seen = {}
            for (const mode of m.modes) {
                const key = HyprInfo.modeKey(mode)
                if (seen[key]) continue
                seen[key] = true
                const r = /^(\d+)x(\d+)@(\d+)/.exec(key)
                out.push({ value: key, label: r ? r[1] + "×" + r[2] + " · " + r[3] + " " + tx(Cat.T("Гц", "Hz")) : key })
            }
        }
        return out
    }

    function positionOptions() { return Cat.POSITIONS.map(o => ({ value: o.value, label: tx(o) })) }
    function keyItems() { return Cat.keyList().map(o => ({ value: o.value, label: tx(o) })) }
    function actionItems() {
        return Cat.ACTIONS.map(a => ({ value: a.id, label: tx(a.title), hint: tx(Cat.BIND_CATS[a.cat]) }))
            .concat([{ value: "__raw", label: tx(Cat.T("Другое (команда Lua)", "Other (Lua command)")) }])
    }
    function layoutOptions() { return HyprInfo.layouts }
    function switchOptions() {
        return [{ value: "", label: tx(Cat.T("Не переключать", "No switching")) }].concat(HyprInfo.switchOptions)
    }
    function classOptions() { return HyprInfo.classes.map(c => ({ value: "^(" + c + ")$", label: c })) }
    function deviceOptions() { return HyprInfo.devices.map(d => ({ value: d.name, label: d.name })) }

    function colorToHex(s) {
        let m = /^rgba\(([0-9a-fA-F]{6})([0-9a-fA-F]{2})\)$/.exec(s)
        if (m) return "#" + m[1] + (m[2].toLowerCase() === "ff" ? "" : m[2])
        m = /^rgb\(([0-9a-fA-F]{6})\)$/.exec(s)
        if (m) return "#" + m[1]
        m = /^0[xX]([0-9a-fA-F]{8})$/.exec(s)
        if (m) return "#" + m[1].slice(2) + (m[1].slice(0, 2).toLowerCase() === "ff" ? "" : m[1].slice(0, 2))
        return String(s)
    }
    function hexToColor(h) {
        const m = /^#?([0-9a-fA-F]{6})([0-9a-fA-F]{2})?$/.exec(String(h).trim())
        return m ? "rgba(" + m[1] + (m[2] ?? "ff") + ")" : null
    }
    // QML-цвет для образца: rgba(rrggbbaa) → #aarrggbb
    function swatch(s) {
        const m = /^rgba\(([0-9a-fA-F]{6})([0-9a-fA-F]{2})\)$/.exec(s) || /^#?([0-9a-fA-F]{6})([0-9a-fA-F]{2})?$/.exec(s)
        if (m) return "#" + (m[2] ?? "ff") + m[1]
        const n = /^0[xX]([0-9a-fA-F]{8})$/.exec(s)
        return n ? "#" + n[1] : "transparent"
    }

    // Раскладки: "us,ru" ↔ ["us","ru"]; переключение — группа "grp:*" в kb_options (остальные опции не трогаем).
    function splitList(s) { return String(s ?? "").split(",").map(x => x.trim()).filter(x => x !== "") }
    function switchOf(kbOptions) { return splitList(kbOptions).find(x => x.indexOf("grp:") === 0) ?? "" }
    function withSwitch(kbOptions, sw) {
        const rest = splitList(kbOptions).filter(x => x.indexOf("grp:") !== 0)
        return (sw ? [sw] : []).concat(rest).join(",")
    }

    // ─── поля записи ─────────────────────────────────────────────────────────

    function fieldOf(entry, key) {
        for (const f of entry.fields) if (f.key === key) return f
        return null
    }
    function fieldValue(entry, key, fallback) {
        const f = fieldOf(entry, key)
        return f && f.value !== undefined ? f.value : fallback
    }
    function matchOf(entry) {
        const m = fieldOf(entry, "match")
        return m && m.fields ? m.fields : []
    }
    function nextFreeWorkspace() {
        const used = entries("workspace_rule").map(e => String(fieldValue(e, "workspace", "")))
        for (let i = 1; i <= 10; i++) if (used.indexOf(String(i)) < 0) return String(i)
        return "1"
    }

    // Записать значение поля записи; path — ключ или массив ключей (вложенные таблицы, например ["match","class"]).
    function setEntryValue(ref, path, v) {
        const p = Array.isArray(path) ? path : [path]
        if (v === "" && p[p.length - 1] === "mods") return removeEntryField(ref, p)
        return setEntryField(ref, p, typeof v === "number" ? "num" : typeof v === "boolean" ? "bool" : "str", v)
    }
    function addDevice(name) {
        return insertStatement(Kinds.KINDS.device.file, "hl.device", 'hl.device({\n    name = ' + Lua.quote(name) + ',\n})')
    }
    function addAutostart(cmd) {
        const hooks = startHooks()
        const text = "hl.exec_cmd(" + Lua.quote(cmd) + ")"
        if (!hooks.length) {
            const f = placeFile("configs/autostart.lua", "hl.on")
            return docs[f] ? commit(f, Lua.appendStmt(texts[f], 'hl.on("hyprland.start", function ()\n    ' + text + '\nend)')) : false
        }
        const h = hooks[hooks.length - 1]
        let last = null
        for (const st of h.fn.body) if (Lua.callName(st) === "hl.exec_cmd") last = st
        const s = texts[h.file]
        return commit(h.file, last ? Lua.insertAfterStmt(s, last, text) : Lua.insertInBody(s, h.fn, text))
    }

    function addWorkspaceRule() {
        return insertStatement("configs/workspaces.lua", "hl.workspace_rule", 'hl.workspace_rule({ workspace = "' + nextFreeWorkspace() + '" })')
    }
    function addMonitor(name) {
        const m = HyprInfo.monitorByName(name)
        const mode = m ? m.width + "x" + m.height + "@" + Math.round(m.refresh) : "preferred"
        const K = Kinds.KINDS.monitor
        const text = 'hl.monitor({\n    output   = ' + Lua.quote(name) + ',\n    mode     = ' + Lua.quote(mode) + ',\n    position = "auto",\n    scale    = "1",\n})'
        return insertStatement(K.file, K.fn, text)
    }

    // ─── действия биндов ─────────────────────────────────────────────────────

    function actionById(id) { return Cat.ACTIONS.find(a => a.id === id) ?? null }

    // Разбор диспетчера в действие каталога: { id, values:{key→значение} } или null (тогда правка только текстом Lua).
    function parseAction(src) {
        const d = Lua.parse("x = " + src)
        if (d.error || d.stmts.length !== 1 || !d.stmts[0].call) return null
        const call = d.stmts[0].call, name = Lua.dotted(call.fn)
        const cands = Cat.ACTIONS.filter(a => a.fn === name)
        if (!cands.length) return null
        const arg = call.args[0]
        for (const a of cands) {
            const values = {}
            if (a.form === "table") {
                if (a.params.length === 0) { if (call.args.length === 0) return { id: a.id, values: values }; continue }
                if (!arg || arg.type !== "table" || call.args.length !== 1) continue
                const keys = arg.fields.map(f => f.key)
                if (keys.some(k => !a.params.some(p => p.key === k))) continue
                if (a.match && keys.indexOf(a.match) < 0) continue
                let ok = true
                for (const p of a.params) {
                    const f = Lua.findField(arg, p.key)
                    if (!f) continue
                    const v = Lua.valueOf(f.value)
                    if (v === undefined) { ok = false; break }
                    values[p.key] = v
                }
                if (ok) return { id: a.id, values: values }
            } else {
                if (call.args.length > a.params.length) continue
                let ok = true
                call.args.forEach((x, i) => {
                    const v = Lua.valueOf(x)
                    if (v === undefined) ok = false
                    else values[a.params[i].key] = v
                })
                if (ok) return { id: a.id, values: values }
            }
        }
        return null
    }

    function defaultParam(p) {
        if (p.def !== undefined) return p.def
        if (p.options && p.options.length) return p.options[0].value
        return ""
    }
    function buildAction(id, values) {
        const a = actionById(id)
        if (!a) return ""
        const lit = v => typeof v === "number" ? String(v) : typeof v === "boolean" ? String(v) : Lua.quote(v)
        const vals = a.params.map(p => values[p.key] !== undefined ? values[p.key] : defaultParam(p))
        if (a.form === "table")
            return a.fn + "(" + (a.params.length ? "{ " + a.params.map((p, i) => p.key + " = " + lit(vals[i])).join(", ") + " }" : "") + ")"
        return a.fn + "(" + vals.map(lit).join(", ") + ")"
    }
    function setBindAction(ref, id, values, wrap) { return setBindDispatcher(ref, buildAction(id, values), wrap) }

    // ─── анимации и кривые ───────────────────────────────────────────────────

    function numbersIn(text) { return (String(text).match(/-?\d*\.?\d+(?:e-?\d+)?/gi) ?? []).map(Number) }

    function curveUsage(name) {
        return entries("animation").filter(a => fieldValue(a, "bezier", "") === name || fieldValue(a, "spring", "") === name).length
    }
    function curvePoints(entry) {
        const pts = numbersIn(fieldOf(entry, "points")?.text ?? "")
        return pts.length === 4 ? pts : [0.25, 0.1, 0.25, 1]
    }

    function curveType(name) {
        const c = entries("curve").find(x => x.head === name)
        return c ? fieldValue(c, "type", "bezier") : "bezier"
    }
    function curveOptions() {
        void rev
        return [{ value: "default", label: tx(Cat.T("Стандартная", "Default")) }].concat(entries("curve").map(c => ({ value: c.head, label: c.head })))
    }

    function animations() {
        void rev
        const order = {}
        Cat.LEAVES.forEach((l, i) => order[l[0]] = i)
        return entries("animation").map(e => {
            const leaf = String(fieldValue(e, "leaf", ""))
            const st = /^(\w+)(?:\s+(\d+)%)?$/.exec(String(fieldValue(e, "style", "")))
            const known = Cat.LEAVES.find(l => l[0] === leaf)
            return {
                id: e.id, ref: e.ref, leaf: leaf, order: order[leaf] ?? 999,
                name: known ? tx(known[1]) : leaf,
                enabled: fieldValue(e, "enabled", true) !== false,
                speed: fieldValue(e, "speed", 5),
                curve: fieldValue(e, "spring", "") || fieldValue(e, "bezier", "default"),
                style: st ? st[1] : "", pct: st && st[2] ? Number(st[2]) : 0
            }
        }).sort((a, b) => a.order - b.order)
    }
    function styleOptions(leaf) {
        return [{ value: "", label: tx(Cat.T("Стандартный", "Default")) }].concat(
            Cat.stylesFor(leaf).map(s => ({ value: s, label: tx(Cat.STYLE_LABELS[s]) })))
    }
    function setAnimCurve(ref, name) {
        const spring = curveType(name) === "spring"
        removeEntryField(ref, [spring ? "bezier" : "spring"])
        return setEntryField(ref, [spring ? "spring" : "bezier"], "str", name)
    }
    function setAnimStyle(ref, style, pct) {
        if (!style) return removeEntryField(ref, ["style"])
        return setEntryField(ref, ["style"], "str", pct && Cat.STYLES_WITH_PERCENT[style] ? style + " " + pct + "%" : style)
    }
    function addAnimation(leaf) {
        const text = 'hl.animation({ leaf = ' + Lua.quote(leaf) + ', enabled = true, speed = 5, bezier = "default" })'
        return insertStatement(Kinds.KINDS.animation.file, "hl.animation", text)
    }
    function unusedLeaves() {
        const have = entries("animation").map(e => String(fieldValue(e, "leaf", "")))
        return Cat.LEAVES.filter(l => have.indexOf(l[0]) < 0).map(l => ({ value: l[0], label: tx(l[1]) }))
    }
    function addCurve() {
        const names = entries("curve").map(c => c.head)
        let n = 1
        while (names.indexOf("curve-" + n) >= 0) n++
        return insertStatement(Kinds.KINDS.curve.file, "hl.curve", 'hl.curve("curve-' + n + '", { type = "bezier", points = { {0.25, 0.1}, {0.25, 1} } })')
    }
    function setCurvePoints(ref, p) {
        const f = v => String(Math.round(v * 1000) / 1000)
        return setEntryRaw(ref, ["points"], "{ {" + f(p[0]) + ", " + f(p[1]) + "}, {" + f(p[2]) + ", " + f(p[3]) + "} }")
    }
    function setCurveType(ref, type) {
        if (type === "spring") {
            removeEntryField(ref, ["points"])
            setEntryField(ref, ["type"], "str", "spring")
            setEntryField(ref, ["mass"], "num", 1)
            setEntryField(ref, ["stiffness"], "num", 70)
            return setEntryField(ref, ["dampening"], "num", 15)
        }
        for (const k of ["mass", "stiffness", "dampening"]) removeEntryField(ref, [k])
        setEntryField(ref, ["type"], "str", "bezier")
        return setEntryRaw(ref, ["points"], "{ {0.25, 0.1}, {0.25, 1} }")
    }
    // Переименование кривой с обновлением ссылок на неё в анимациях.
    function renameCurve(ref, oldName, newName) {
        newName = newName.trim()
        if (!/^[A-Za-z0-9_-]+$/.test(newName) || newName === oldName || entries("curve").some(c => c.head === newName)) { status = "rejected"; return false }
        if (!setEntryHead(ref, newName)) return false
        for (const a of entries("animation")) {
            if (fieldValue(a, "bezier", "") === oldName) setEntryField(a.ref, ["bezier"], "str", newName)
            if (fieldValue(a, "spring", "") === oldName) setEntryField(a.ref, ["spring"], "str", newName)
        }
        return true
    }

    // ─── сохранение: бэкап → запись → hyprctl reload → hyprctl configerrors ─────

    function save() {
        if (busy) return
        const list = dirtyList()
        if (!list.length) return
        saving = list
        savedCount = 0
        prev = {}
        for (const p of list) prev[p] = origs[p] ?? ""
        status = "saving"
        statusDetail = ""
        backup.command = ["sh", "-c",
            'd="$1"; shift; mkdir -p "$d" || exit 1; ts=$(date +%Y%m%d-%H%M%S); ' +
            'for f; do mkdir -p "$(dirname "$f")"; [ -e "$f" ] || continue; cp -- "$f" "$d/$(printf %s "${f#$HOME/}" | tr / _).$ts" || exit 1; done; ' +
            'ls -1t "$d" | tail -n +301 | while read -r x; do rm -- "$d/$x"; done',
            "sh", backupDir].concat(list.map(fullPath))
        backup.running = true
    }

    // Вернуть файлы, как они были до последнего сохранения (после ошибки configerrors).
    function undoSave() {
        if (busy) return
        const list = Object.keys(prev)
        if (!list.length) return
        for (const p of list) {
            texts[p] = prev[p]
            docs[p] = Lua.parse(prev[p])
            textReplaced(p)
        }
        rev++
        saving = list
        savedCount = 0
        prev = {}
        status = "saving"
        statusDetail = ""
        writeAll()
    }

    function writeAll() {
        for (const p of saving) {
            const w = writers[p]
            if (!w) { fail("backupfailed", "no writer for " + p); return }
            w.setText(texts[p])
        }
    }
    function fail(st, detail) { status = st; statusDetail = detail ?? "" }

    function fileSaved(path) {
        if (!saving.includes(path)) return
        origs[path] = texts[path]
        savedCount++
        rev++
        if (savedCount >= saving.length) reloader.running = true
    }
    function saveFailed(path, err) { if (saving.includes(path)) fail("error", path + ": " + err) }

    Process {
        id: backup
        onExited: code => code === 0 ? root.writeAll() : root.fail("backupfailed", "")
    }
    Process {
        id: reloader
        command: ["hyprctl", "reload"]
        onExited: check.start()
    }
    Timer { id: check; interval: 400; onTriggered: errors.running = true }
    Process {
        id: errors
        command: ["hyprctl", "configerrors"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim()
                root.status = t ? "error" : "ok"
                root.statusDetail = t
                root.refreshInfo()
            }
        }
    }

    Instantiator {
        model: root.open ? root.current().files : []
        delegate: FileView {
            required property var modelData
            path: root.fullPath(modelData.path)
            printErrors: false
            watchChanges: true
            onLoaded: root.fileLoaded(modelData.path, text())
            onFileChanged: reload()
            onSaved: root.fileSaved(modelData.path)
            onSaveFailed: err => root.saveFailed(modelData.path, err)
        }
        onObjectAdded: (i, o) => root.writers[o.modelData.path] = o
        onObjectRemoved: (i, o) => delete root.writers[o.modelData.path]
    }
}
