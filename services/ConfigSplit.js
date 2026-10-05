.pragma library
.import "LuaConf.js" as Lua
// Разбиение одного большого конфига Hyprland (hyprland.lua из коробки) на файлы по смыслу.
// Чистая функция: на входе исходник и разобранные инструкции (LuaConf.parse), на выходе — новый текст
// главного файла и тексты файлов, куда переехали инструкции. Комментарии перед инструкцией едут с ней,
// баннеры из «----» выбрасываются. Файлы создаёт и подключает через require ConfigEditor.

var ROLE_BY_FN = {
    "hl.monitor": "monitors", "hl.exec_cmd": "autostart", "hl.env": "environment", "hl.permission": "permissions",
    "hl.curve": "look", "hl.animation": "look", "hl.workspace_rule": "workspaces", "hl.gesture": "input",
    "hl.device": "devices", "hl.bind": "keybindings", "hl.window_rule": "windows", "hl.layer_rule": "windows"
}
var CONFIG_KEY_ROLE = { input: "input", misc: "misc" }       // как в ConfigKinds.OPTION_FILE; остальное — look
var ORDER = ["programs", "monitors", "autostart", "environment", "permissions", "look", "devices", "misc", "input",
             "keybindings", "workspaces", "windows"]
var GLOBALS_ROLE = "programs"                                 // сюда переезжают переменные (local → глобальные)

function path(role) { return "configs/" + role + ".lua" }

function roleOfText(text) {
    var m = /\bhl\.(\w+)/.exec(text)
    while (m) {
        var fn = "hl." + m[1]
        if (ROLE_BY_FN[fn]) return ROLE_BY_FN[fn]
        if (fn === "hl.on") return /"hyprland\.start"/.test(text) ? "autostart" : null
        if (fn === "hl.config") {
            var k = /hl\.config\(\s*\{\s*(?:--[^\n]*\n\s*)*(\w+)/.exec(text)
            return k ? (CONFIG_KEY_ROLE[k[1]] || "look") : "look"
        }
        var rest = text.slice(m.index + m[0].length)
        m = /\bhl\.(\w+)/.exec(rest)
        text = rest
    }
    return null
}

function isBanner(line) { return /^\s*-{4,}.*$/.test(line) && /^[\s\-A-Za-z&]*$/.test(line) && !/[a-z]/.test(line) }

function escRe(s) { return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") }

// have — пути файлов, которые уже есть (в них инструкции дописываются, require для них не нужен).
function plan(src, have) {
    have = have || []
    var d = Lua.parse(src)
    if (d.error || d.stmts.some(function (s) { return s.kind === "raw" })) return null

    var items = [], pos = 0
    d.stmts.forEach(function (st, i) {
        var ls = src.lastIndexOf("\n", st.s - 1) + 1
        var e = st.e
        var tail = /^[ \t]*(--[^\n]*)?(?=\n|$)/.exec(src.slice(e))
        if (tail) e += tail[0].length
        var lead = src.slice(pos, ls).split("\n").filter(function (l) { return !isBanner(l) }).join("\n")
        pos = Math.min(src.length, e + 1)
        items.push({ st: st, lead: lead, text: src.slice(st.s, e), head: i === 0, role: null, pinned: false })
    })
    var tailText = src.slice(pos)
    // шапка файла остаётся в главном файле; комментарий, приклеенный к первой инструкции, едет с ней
    var header = ""
    if (items.length) {
        var parts = /^([\s\S]*\n[ \t]*\n)([^\n]*(?:\n[^\n]*)*)$/.exec(items[0].lead)
        header = parts ? parts[1] : items[0].lead
        items[0].lead = parts ? parts[2] : ""
        items[0].head = false
    }

    // роль каждой инструкции
    items.forEach(function (it) {
        var st = it.st
        if (st.kind === "local") {
            var v = st.value
            if (st.names.length === 1 && v && (v.type === "str" || v.type === "num" || v.type === "bool")) it.role = GLOBALS_ROLE, it.global = true
            else if (st.names.length === 1 && st.call) it.role = roleOfText(it.text.slice(it.text.indexOf("=")))
        } else if (st.kind === "call") {
            var fn = Lua.callName(st)
            it.role = ROLE_BY_FN[fn] || fn === "hl.config" || fn === "hl.on" ? roleOfText(it.text) : null
        } else if (st.kind === "block") {
            it.role = /^local\b/.test(it.text) ? null : roleOfText(it.text)
        }
        if (!it.role) it.pinned = true
    })

    // локальные значения-вызовы (handle правила и т.п.) видны только в своём файле: пользователи едут вместе с ними
    for (var pass = 0; pass < 3; pass++) {
        items.forEach(function (loc) {
            if (loc.st.kind !== "local" || loc.global) return
            var re = new RegExp("(^|[^\\w.])" + escRe(loc.st.name) + "\\b")
            items.forEach(function (o) {
                if (o === loc || !re.test(o.text)) return
                if (loc.pinned) o.role = null, o.pinned = true
                else if (!o.global) o.role = loc.role, o.pinned = false
            })
        })
    }

    var byRole = {}, pinned = []
    items.forEach(function (it) {
        if (it.pinned || !it.role) pinned.push(it)
        else (byRole[it.role] = byRole[it.role] || []).push(it)
    })

    function render(list) {
        var out = ""
        list.forEach(function (it, i) {
            var lead = it.lead.replace(/^\s*\n/, "")
            var gap = /\S/.test(lead) || /\n\s*\n/.test(it.lead)
            var text = it.global ? it.text.replace(/^local\s+/, "") : it.text
            lead = lead.replace(/\s+$/, "")
            var chunk = (lead ? lead + "\n" : "") + text
            out += i === 0 ? chunk : (gap ? "\n\n" : "\n") + chunk
        })
        return out + "\n"
    }

    var files = []
    ORDER.forEach(function (r) { if (byRole[r]) files.push({ role: r, path: path(r), text: render(byRole[r]) }) })

    var head = header.replace(/\s+$/, "")
    var pinnedText = pinned.length ? render(pinned.map(function (p, i) { return p })) : ""
    var requires = files.filter(function (f) { return have.indexOf(f.path) < 0 }).map(function (f) { return 'require("' + f.path.replace(/\.lua$/, "").replace(/\//g, ".") + '")' })
    var main = head ? head + "\n\n" : ""
    var progReq = requires.filter(function (r) { return r.indexOf("programs") > 0 })
    var otherReq = requires.filter(function (r) { return r.indexOf("programs") < 0 })
    if (progReq.length) main += progReq.join("\n") + "\n\n"
    if (pinnedText) main += pinnedText + "\n"
    if (otherReq.length) main += otherReq.join("\n") + "\n"
    if (/\S/.test(tailText)) main += "\n" + tailText.replace(/^\s+/, "")
    return { main: main, files: files, moved: items.length - pinned.length }
}
