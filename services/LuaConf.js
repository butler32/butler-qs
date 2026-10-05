.pragma library
// Терпимый разбор подмножества Lua, которым пишутся конфиги Hyprland, и правка исходника «по месту».
//
// parse(src) → { src, stmts, error? }. У каждого узла есть смещения s/e в исходнике, поэтому
// правки — это замена/вставка/удаление диапазонов текста: комментарии, форматирование и всё,
// что разбор не понял (for/if/function → kind "block", сбой разбора → kind "raw"), остаются нетронутыми.
//
// Инструкции: { kind: "call"|"local"|"assign"|"block"|"return"|"raw", s, e, ... }
//   call   — call: узел вызова
//   local  — names, name, value (первое значение); call — если значение одно и это вызов (local r = hl.window_rule({…}))
//   assign — target, value; call — как у local
// Выражения (type): str{v} num{v,raw} bool{v} nil name{v} index{obj,key} idx call{fn,args,open,close}
//   table{fields:[{key,value,comma,s,e}]} function{body,endS} bin{op,l,r} un paren method vararg
// В QML-версии V4 нет lookbehind в регулярках — здесь их нет.

// ─── лексер ──────────────────────────────────────────────────────────────────

function longOpen(src, pos) {
    if (src.charAt(pos) !== "[") return -1
    var i = pos + 1, level = 0
    while (src.charAt(i) === "=") { level++; i++ }
    return src.charAt(i) === "[" ? level : -1
}

function longEnd(src, pos, level) {
    var close = "]" + new Array(level + 1).join("=") + "]"
    var i = src.indexOf(close, pos)
    return i < 0 ? src.length : i + close.length
}

function unescape(body) {
    return body.replace(/\\(.)/g, function (m, c) {
        if (c === "n") return "\n"
        if (c === "t") return "\t"
        if (c === "r") return "\r"
        return c
    })
}

var NUM_RE = /^(0[xX][0-9a-fA-F]+|[0-9]+\.?[0-9]*([eE][+-]?[0-9]+)?|\.[0-9]+([eE][+-]?[0-9]+)?)/
var OPS3 = { "...": 1 }
var OPS2 = { "..": 1, "==": 1, "~=": 1, "<=": 1, ">=": 1, "//": 1, "::": 1, "<<": 1, ">>": 1 }

function tokenize(src) {
    var toks = [], i = 0, n = src.length
    while (i < n) {
        var c = src.charAt(i)
        if (c === " " || c === "\t" || c === "\r" || c === "\n") { i++; continue }
        if (c === "-" && src.charAt(i + 1) === "-") {
            var lb = longOpen(src, i + 2)
            if (lb >= 0) { i = longEnd(src, i + 2, lb); continue }
            var nl = src.indexOf("\n", i)
            i = nl < 0 ? n : nl
            continue
        }
        var s = i
        if (/[A-Za-z_]/.test(c)) {
            while (i < n && /[A-Za-z0-9_]/.test(src.charAt(i))) i++
            toks.push({ t: "name", v: src.slice(s, i), s: s, e: i })
            continue
        }
        if (/[0-9]/.test(c) || (c === "." && /[0-9]/.test(src.charAt(i + 1)))) {
            var m = NUM_RE.exec(src.slice(i, i + 64))
            i += m[0].length
            toks.push({ t: "num", v: m[0], s: s, e: i })
            continue
        }
        if (c === '"' || c === "'") {
            var j = i + 1
            while (j < n && src.charAt(j) !== c) {
                if (src.charAt(j) === "\\") j++
                if (src.charAt(j) === "\n") throw new Error("unterminated string at " + s)
                j++
            }
            if (j >= n) throw new Error("unterminated string at " + s)
            toks.push({ t: "str", val: unescape(src.slice(i + 1, j)), s: s, e: j + 1 })
            i = j + 1
            continue
        }
        var lb2 = c === "[" ? longOpen(src, i) : -1
        if (lb2 >= 0) {
            var end = longEnd(src, i, lb2)
            var body = src.slice(i + lb2 + 2, end - lb2 - 2)
            if (body.charAt(0) === "\n") body = body.slice(1)
            toks.push({ t: "str", val: body, s: s, e: end, long: true })
            i = end
            continue
        }
        var three = src.substr(i, 3), two = src.substr(i, 2)
        var op = OPS3[three] ? three : OPS2[two] ? two : c
        i += op.length
        toks.push({ t: "op", v: op, s: s, e: i })
    }
    return toks
}

// ─── разбор ──────────────────────────────────────────────────────────────────

var BIN = {
    "or": [1, 1], "and": [2, 2],
    "<": [3, 3], ">": [3, 3], "<=": [3, 3], ">=": [3, 3], "~=": [3, 3], "==": [3, 3],
    "|": [4, 4], "~": [5, 5], "&": [6, 6], "<<": [7, 7], ">>": [7, 7],
    "..": [9, 8], "+": [10, 10], "-": [10, 10],
    "*": [11, 11], "/": [11, 11], "//": [11, 11], "%": [11, 11], "^": [14, 13]
}

function parse(src) {
    var toks
    try { toks = tokenize(src) } catch (e) { return { src: src, stmts: [], error: String(e) } }
    var EOF = { t: "eof", v: "", s: src.length, e: src.length }
    var p = 0

    function peek(k) { return toks[p + (k || 0)] || EOF }
    function next() { return toks[p++] || EOF }
    function prevEnd() { return p > 0 ? toks[p - 1].e : 0 }
    function isOp(v, k) { var t = peek(k); return t.t === "op" && t.v === v }
    function isKw(v, k) { var t = peek(k); return t.t === "name" && t.v === v }
    function expectOp(v) {
        var t = next()
        if (t.t !== "op" || t.v !== v) throw new Error("expected '" + v + "' at " + t.s)
        return t
    }
    function atLineStart(tok) {
        var i = tok.s - 1
        while (i >= 0 && (src.charAt(i) === " " || src.charAt(i) === "\t")) i--
        return i < 0 || src.charAt(i) === "\n"
    }

    function parseBlock() {
        var out = []
        for (;;) {
            var t = peek()
            if (t.t === "eof") break
            if (t.t === "name" && (t.v === "end" || t.v === "else" || t.v === "elseif" || t.v === "until")) break
            if (isOp(";")) { p++; continue }
            out.push(parseStatementSafe())
        }
        return out
    }

    function parseStatementSafe() {
        var save = p, t = peek()
        try { return parseStatement() } catch (e) {
            p = save + 1
            while (peek().t !== "eof" && !atLineStart(peek())) p++
            return { kind: "raw", s: t.s, e: toks[p - 1].e, error: String(e) }
        }
    }

    function parseStatement() {
        var t = peek(), s = t.s
        if (t.t === "name") {
            switch (t.v) {
            case "local": return parseLocal()
            case "function": case "for": case "while": case "if": case "do": case "repeat":
                return skipBlock()
            case "return":
                p++
                if (!(peek().t === "eof" || isOp(";") || isKw("end") || isKw("else") || isKw("elseif") || isKw("until")))
                    parseExprList()
                return { kind: "return", s: s, e: prevEnd() }
            case "break": p++; return { kind: "raw", s: s, e: prevEnd() }
            case "goto": p += 2; return { kind: "raw", s: s, e: prevEnd() }
            }
        }
        var ex = parseSuffixed()
        if (isOp("=") || isOp(",")) {
            while (isOp(",")) { p++; parseSuffixed() }
            expectOp("=")
            var vals = parseExprList()
            var as = { kind: "assign", target: ex, value: vals[0], s: s, e: prevEnd() }
            if (vals.length === 1 && vals[0].type === "call") as.call = vals[0]
            return as
        }
        if (ex.type === "call") return { kind: "call", call: ex, s: s, e: ex.e }
        throw new Error("unexpected expression at " + s)
    }

    function skipBlock() {
        var s = peek().s, depth = 0, head = peek().v
        for (;;) {
            var t = next()
            if (t.t === "eof") throw new Error("unterminated block at " + s)
            if (t.t !== "name") continue
            if (t.v === "function" || t.v === "if" || t.v === "do" || t.v === "repeat") depth++
            else if (t.v === "end" || t.v === "until") { depth--; if (depth <= 0) break }
        }
        return { kind: "block", head: head, s: s, e: prevEnd() }
    }

    function parseLocal() {
        var s = next().s
        if (isKw("function")) { var b = skipBlock(); b.s = s; return b }
        var names = []
        for (;;) {
            names.push(next().v)
            if (isOp("<")) { p += 3 }                 // <const> / <close>
            if (isOp(",")) p++; else break
        }
        var values = []
        if (isOp("=")) { p++; values = parseExprList() }
        var st = { kind: "local", names: names, name: names[0], value: values[0], s: s, e: prevEnd() }
        if (values.length === 1 && values[0].type === "call") st.call = values[0]     // local r = hl.window_rule({...})
        return st
    }

    function parseExprList() {
        var out = [parseExpr(0)]
        while (isOp(",")) { p++; out.push(parseExpr(0)) }
        return out
    }

    function binOp() {
        var t = peek()
        if (t.t === "op" && BIN[t.v]) return t.v
        if (t.t === "name" && (t.v === "or" || t.v === "and")) return t.v
        return null
    }

    function parseExpr(limit) {
        var left = parseUnary()
        for (;;) {
            var op = binOp()
            if (!op || BIN[op][0] <= limit) break
            p++
            var right = parseExpr(BIN[op][1])
            left = { type: "bin", op: op, l: left, r: right, s: left.s, e: right.e }
        }
        return left
    }

    function parseUnary() {
        var t = peek()
        if ((t.t === "op" && (t.v === "-" || t.v === "#" || t.v === "~")) || (t.t === "name" && t.v === "not")) {
            p++
            var arg = parseExpr(12)
            if (t.v === "-" && arg.type === "num" && arg.s === t.e)
                return { type: "num", v: -arg.v, raw: "-" + arg.raw, s: t.s, e: arg.e }
            return { type: "un", op: t.v, arg: arg, s: t.s, e: arg.e }
        }
        return parseSuffixed()
    }

    function parseFunction() {
        var s = next().s
        expectOp("(")
        while (!isOp(")")) { if (peek().t === "eof") throw new Error("bad params"); p++ }
        p++
        var body = parseBlock()
        var endTok = peek()
        if (!isKw("end")) throw new Error("expected 'end' at " + endTok.s)
        p++
        return { type: "function", body: body, endS: endTok.s, s: s, e: endTok.e }
    }

    function parseTable() {
        var o = expectOp("{"), fields = []
        while (!isOp("}")) {
            var t = peek(), f
            if (t.t === "eof") throw new Error("unterminated table")
            if (t.t === "name" && isOp("=", 1)) {
                p += 2
                var v = parseExpr(0)
                f = { key: t.v, value: v, s: t.s, e: v.e }
            } else if (isOp("[")) {
                p++
                var kx = parseExpr(0)
                expectOp("]"); expectOp("=")
                var v2 = parseExpr(0)
                f = { key: (kx.type === "str" || kx.type === "num") ? String(kx.v) : null, value: v2, s: t.s, e: v2.e, bracket: true }
            } else {
                var v3 = parseExpr(0)
                f = { key: null, value: v3, s: v3.s, e: v3.e }
            }
            f.comma = -1
            if (isOp(",") || isOp(";")) { f.comma = peek().s; p++ }
            fields.push(f)
            if (f.comma < 0 && !isOp("}")) throw new Error("expected ',' or '}' at " + peek().s)
        }
        var c = expectOp("}")
        return { type: "table", fields: fields, s: o.s, e: c.e }
    }

    function parsePrimary() {
        var t = peek()
        if (t.t === "num") {
            p++
            var v = t.v.charAt(1) === "x" || t.v.charAt(1) === "X" ? parseInt(t.v, 16) : parseFloat(t.v)
            return { type: "num", v: v, raw: t.v, s: t.s, e: t.e }
        }
        if (t.t === "str") { p++; return { type: "str", v: t.val, s: t.s, e: t.e } }
        if (t.t === "name") {
            if (t.v === "true" || t.v === "false") { p++; return { type: "bool", v: t.v === "true", s: t.s, e: t.e } }
            if (t.v === "nil") { p++; return { type: "nil", s: t.s, e: t.e } }
            if (t.v === "function") return parseFunction()
            p++
            return { type: "name", v: t.v, s: t.s, e: t.e }
        }
        if (t.t === "op") {
            if (t.v === "(") {
                p++
                var ex = parseExpr(0)
                expectOp(")")
                return { type: "paren", inner: ex, s: t.s, e: prevEnd() }
            }
            if (t.v === "{") return parseTable()
            if (t.v === "...") { p++; return { type: "vararg", s: t.s, e: t.e } }
        }
        throw new Error("unexpected '" + (t.v || t.t) + "' at " + t.s)
    }

    function parseCallArgs() {
        var t = peek()
        if (t.t === "str") { p++; return { args: [{ type: "str", v: t.val, s: t.s, e: t.e }], open: -1, close: -1, e: t.e } }
        if (isOp("{")) { var tb = parseTable(); return { args: [tb], open: -1, close: -1, e: tb.e } }
        var o = expectOp("("), args = []
        if (!isOp(")")) args = parseExprList()
        var c = expectOp(")")
        return { args: args, open: o.s, close: c.s, e: c.e }
    }

    function parseSuffixed() {
        var e = parsePrimary()
        for (;;) {
            var t = peek(), c
            if (t.t === "op") {
                if (t.v === ".") {
                    p++
                    var k = next()
                    e = { type: "index", obj: e, key: k.v, s: e.s, e: k.e }
                    continue
                }
                if (t.v === "[") {
                    p++
                    var ke = parseExpr(0)
                    expectOp("]")
                    e = { type: "idx", obj: e, key: ke, s: e.s, e: prevEnd() }
                    continue
                }
                if (t.v === ":") {
                    p++
                    var m = next()
                    c = parseCallArgs()
                    e = { type: "call", fn: { type: "method", obj: e, key: m.v, s: e.s, e: m.e },
                          args: c.args, open: c.open, close: c.close, s: e.s, e: c.e }
                    continue
                }
                if (t.v === "(" || t.v === "{") {
                    c = parseCallArgs()
                    e = { type: "call", fn: e, args: c.args, open: c.open, close: c.close, s: e.s, e: c.e }
                    continue
                }
            } else if (t.t === "str") {
                c = parseCallArgs()
                e = { type: "call", fn: e, args: c.args, open: c.open, close: c.close, s: e.s, e: c.e }
                continue
            }
            break
        }
        return e
    }

    var stmts = parseBlock()
    var res = { src: src, stmts: stmts }
    if (peek().t !== "eof") {
        var t0 = peek()
        stmts.push({ kind: "raw", s: t0.s, e: src.length, error: "unexpected '" + t0.v + "'" })
        res.error = "unexpected '" + t0.v + "' at " + t0.s
    }
    return res
}

// Проверка, что text — одно выражение Lua (для полей «выражение»).
function isExpr(text) {
    var r = parse("x = " + text)
    if (r.error || r.stmts.length !== 1 || r.stmts[0].kind !== "assign") return false
    return r.stmts[0].value.e === ("x = " + text).replace(/\s+$/, "").length
}

// ─── чтение узлов ────────────────────────────────────────────────────────────

function dotted(node) {
    if (!node) return null
    if (node.type === "name") return node.v
    if (node.type === "index") { var o = dotted(node.obj); return o === null ? null : o + "." + node.key }
    return null
}

function callName(stmt) { return stmt && stmt.call ? dotted(stmt.call.fn) : null }

function findField(tbl, key) {
    if (!tbl || tbl.type !== "table") return null
    for (var i = 0; i < tbl.fields.length; i++) if (tbl.fields[i].key === key) return tbl.fields[i]
    return null
}

function valueOf(node) {
    if (!node) return undefined
    if (node.type === "str" || node.type === "num" || node.type === "bool") return node.v
    return undefined
}

function kindOf(node) {
    if (!node) return "expr"
    if (node.type === "str" || node.type === "num" || node.type === "bool") return node.type
    if (node.type === "table") {
        for (var i = 0; i < node.fields.length; i++) if (node.fields[i].key === null) return "expr"
        return "table"
    }
    return "expr"
}

function srcOf(src, node) { return src.slice(node.s, node.e) }

// Поля таблицы для формы: [{key, kind, value, text, path, fields?}]
function describeTable(src, tbl, prefix) {
    var out = []
    prefix = prefix || []
    for (var i = 0; i < tbl.fields.length; i++) {
        var f = tbl.fields[i]
        if (f.key === null) continue
        var k = kindOf(f.value), path = prefix.concat([f.key])
        var d = { key: f.key, kind: k, value: valueOf(f.value), text: srcOf(src, f.value), path: path }
        if (f.value.type === "num") d.raw = f.value.raw
        if (k === "table") d.fields = describeTable(src, f.value, path)
        out.push(d)
    }
    return out
}

// ─── литералы ────────────────────────────────────────────────────────────────

function quote(s) {
    return '"' + String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\n/g, "\\n").replace(/\r/g, "\\r") + '"'
}

function lit(kind, v) {
    if (kind === "str") return quote(v)
    if (kind === "num") return String(Number(v))
    if (kind === "bool") return v ? "true" : "false"
    return String(v)
}

// ─── правка исходника ────────────────────────────────────────────────────────

function replace(src, s, e, text) { return src.slice(0, s) + text + src.slice(e) }
function lineStart(src, i) { return src.lastIndexOf("\n", i - 1) + 1 }
function lineEnd(src, i) { var n = src.indexOf("\n", i); return n < 0 ? src.length : n }
function indentOf(src, i) { return /^[ \t]*/.exec(src.slice(lineStart(src, i), lineEnd(src, i)))[0] }

function detectUnit(src) {
    var m = /\n( +)\S/.exec(src)
    return m ? (m[1].length >= 4 ? "    " : m[1]) : "    "
}

function tableInsert(src, tbl, key, text) {
    var entry = key + " = " + text
    if (!tbl.fields.length) {
        if (src.slice(tbl.s, tbl.e).indexOf("\n") < 0) return replace(src, tbl.s, tbl.e, "{ " + entry + " }")
        var close = tbl.e - 1
        var ind = indentOf(src, close)
        var ls = lineStart(src, close)
        if (src.slice(ls, close).replace(/[ \t]/g, "") === "")
            return src.slice(0, ls) + ind + detectUnit(src) + entry + ",\n" + src.slice(ls)
        return replace(src, tbl.s, tbl.e, "{ " + entry + " }")
    }
    var last = tbl.fields[tbl.fields.length - 1]
    var after = last.comma >= 0 ? last.comma + 1 : last.e
    var hasComma = last.comma >= 0
    if (src.slice(after, tbl.e - 1).indexOf("\n") < 0) {
        // всё в одной строке: `{ a = 1, b = 2 }`
        return src.slice(0, after) + (hasComma ? "" : ",") + " " + entry + (hasComma ? "," : "") + src.slice(after)
    }
    var ind2 = indentOf(src, last.s)
    var eol = lineEnd(src, after)
    var out = src.slice(0, eol) + "\n" + ind2 + entry + (hasComma ? "," : "") + src.slice(eol)
    if (!hasComma) out = out.slice(0, last.e) + "," + out.slice(last.e)
    return out
}

function tableRemove(src, tbl, key) {
    var idx = -1
    for (var i = 0; i < tbl.fields.length; i++) if (tbl.fields[i].key === key) { idx = i; break }
    if (idx < 0) return src
    var f = tbl.fields[idx]
    var after = f.comma >= 0 ? f.comma + 1 : f.e
    var ls = lineStart(src, f.s), le = lineEnd(src, after)
    if (/^[ \t]*$/.test(src.slice(ls, f.s)) && /^\s*(--.*)?$/.test(src.slice(after, le)))
        return src.slice(0, ls) + src.slice(Math.min(le + 1, src.length))
    if (f.comma >= 0) return src.slice(0, f.s) + src.slice(after).replace(/^[ \t]+/, "")
    if (idx > 0) return src.slice(0, tbl.fields[idx - 1].comma) + src.slice(f.e)
    return src.slice(0, f.s) + src.slice(f.e)
}

function nestLiteral(path, text) {
    return path.length ? "{ " + path[0] + " = " + nestLiteral(path.slice(1), text) + " }" : text
}

// Задать значение по пути ключей; недостающие вложенные таблицы создаются. null — путь упирается в не-таблицу.
function setPath(src, tbl, path, text) {
    for (var i = 0; i < path.length - 1; i++) {
        var f = findField(tbl, path[i])
        if (!f) return tableInsert(src, tbl, path[i], nestLiteral(path.slice(i + 1), text))
        if (f.value.type !== "table") return null
        tbl = f.value
    }
    var last = path[path.length - 1], fl = findField(tbl, last)
    return fl ? replace(src, fl.value.s, fl.value.e, text) : tableInsert(src, tbl, last, text)
}

function removePath(src, tbl, path) {
    for (var i = 0; i < path.length - 1; i++) {
        var f = findField(tbl, path[i])
        if (!f || f.value.type !== "table") return src
        tbl = f.value
    }
    return tableRemove(src, tbl, path[path.length - 1])
}

function getPath(tbl, path) {
    var f = null
    for (var i = 0; i < path.length; i++) {
        f = findField(tbl, path[i])
        if (!f) return null
        if (i < path.length - 1) { if (f.value.type !== "table") return null; tbl = f.value }
    }
    return f
}

function stmtRemove(src, st) {
    var ls = lineStart(src, st.s), le = lineEnd(src, st.e)
    if (/^[ \t]*$/.test(src.slice(ls, st.s)) && /^\s*(--.*)?$/.test(src.slice(st.e, le)))
        return src.slice(0, ls) + src.slice(Math.min(le + 1, src.length))
    return src.slice(0, st.s) + src.slice(st.e)
}

// Новая строка сразу под инструкцией st (с её отступом).
function insertAfterStmt(src, st, text) {
    var eol = lineEnd(src, st.e)
    return src.slice(0, eol) + "\n" + indentOf(src, st.s) + text + src.slice(eol)
}

// Новая инструкция в конец файла (через пустую строку).
function appendStmt(src, text) {
    var out = src
    if (out.length && out.charAt(out.length - 1) !== "\n") out += "\n"
    if (out.replace(/\s/g, "").length) out += "\n"
    return out + text + "\n"
}

// Новая инструкция в конец тела function (перед `end`).
function insertInBody(src, fn, text) {
    var ind = fn.body.length ? indentOf(src, fn.body[fn.body.length - 1].s) : indentOf(src, fn.s) + detectUnit(src)
    var ls = lineStart(src, fn.endS)
    if (/^[ \t]*$/.test(src.slice(ls, fn.endS))) return src.slice(0, ls) + ind + text + "\n" + src.slice(ls)
    return src.slice(0, fn.endS) + "\n" + ind + text + "\n" + src.slice(fn.endS)
}
