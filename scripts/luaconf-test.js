#!/usr/bin/env node
// Проверка services/LuaConf.js на реальных конфигах Hyprland (по умолчанию ~/.config/hypr/**/*.lua).
//   node scripts/luaconf-test.js [файл.lua ...]
// Для каждой инструкции-вызова с таблицей: вставить поле → результат парсится и грузится настоящим Lua;
// удалить поле → исходник совпадает с оригиналом (когда у последнего поля была запятая).
const fs = require("fs"), path = require("path"), cp = require("child_process")
const code = fs.readFileSync(path.join(__dirname, "../services/LuaConf.js"), "utf8").replace(/^\.pragma library\n/, "")
const L = new Function(code + "\nreturn { parse, isExpr, setPath, removePath, getPath, stmtRemove, insertAfterStmt, appendStmt, insertInBody, callName, describeTable, lit }")()

function walk(d) {
    return fs.readdirSync(d, { withFileTypes: true }).flatMap(e =>
        e.isDirectory() ? walk(path.join(d, e.name)) : e.name.endsWith(".lua") ? [path.join(d, e.name)] : [])
}
const files = process.argv.length > 2 ? process.argv.slice(2) : walk(path.join(process.env.HOME, ".config/hypr"))

let fails = 0, checks = 0
const fail = (f, msg) => { fails++; console.log("FAIL", f, msg) }
const luaOk = (src) => {
    const tmp = "/tmp/luaconf-test.lua"
    fs.writeFileSync(tmp, src)
    return cp.spawnSync("luajit", ["-bl", tmp], { encoding: "utf8" }).status === 0
}
const nodesOf = (st) => st.kind === "call" ? st.call.args.filter(a => a.type === "table") : []

for (const f of files) {
    const src = fs.readFileSync(f, "utf8")
    const r = L.parse(src)
    const raws = r.stmts.filter(s => s.kind === "raw")
    const kinds = {}
    for (const s of r.stmts) kinds[s.kind] = (kinds[s.kind] || 0) + 1
    console.log(path.relative(process.env.HOME, f), JSON.stringify(kinds), r.error || "")
    if (r.error || raws.length) fail(f, "parse error/raw: " + (r.error || raws.map(x => x.error).join(";")))
    if (!luaOk(src)) { console.log("  (source itself is not valid for luajit -bl, skipping edits)"); continue }

    r.stmts.forEach((st, si) => {
        for (const tbl of nodesOf(st)) {
            // identity: записать поле само в себя
            for (const fl of tbl.fields) {
                if (fl.key === null) continue
                const out = L.setPath(src, tbl, [fl.key], src.slice(fl.value.s, fl.value.e))
                checks++
                if (out !== src) fail(f, "identity set " + fl.key)
            }
            // вставка нового поля и откат
            const ins = L.setPath(src, tbl, ["zz_test", "inner"], '"v"')
            const r2 = L.parse(ins)
            checks++
            if (!ins || r2.error || !luaOk(ins)) { fail(f, "insert nested at stmt " + si); continue }
            const t2 = nodesOf(r2.stmts[si]).find(t => L.getPath(t, ["zz_test", "inner"]))
            if (!t2) { fail(f, "inserted field not found at stmt " + si); continue }
            const back = L.removePath(ins, t2, ["zz_test"])
            const last = tbl.fields[tbl.fields.length - 1]
            checks++
            if (!luaOk(back)) fail(f, "remove broke syntax at stmt " + si)
            else if ((!last || last.comma >= 0) && back !== src) fail(f, "insert+remove not identical at stmt " + si)
        }
        // удаление инструкции и вставка после неё
        if (st.kind === "call") {
            const rem = L.stmtRemove(src, st)
            checks++
            if (!luaOk(rem)) fail(f, "stmtRemove broke syntax at stmt " + si)
            const add = L.insertAfterStmt(src, st, "hl.env(\"ZZ\", \"1\")")
            checks++
            if (!luaOk(add)) fail(f, "insertAfterStmt broke syntax at stmt " + si)
        }
    })
    checks++
    const tail = r.stmts[r.stmts.length - 1]
    if (!(tail && tail.kind === "return") && !luaOk(L.appendStmt(src, 'hl.env("ZZ", "1")'))) fail(f, "appendStmt")
}

// модульные проверки
const eq = (a, b, m) => { checks++; if (JSON.stringify(a) !== JSON.stringify(b)) fail("unit", m + ": " + JSON.stringify(a) + " != " + JSON.stringify(b)) }
eq(L.isExpr('{ {0.23, 1}, {0.32, 1} }'), true, "isExpr table")
eq(L.isExpr('"a" .. "b"'), true, "isExpr concat")
eq(L.isExpr('1 +'), false, "isExpr bad")
eq(L.isExpr('1, 2'), false, "isExpr list")
const one = L.parse('hl.config({ a = { b = -0.4, c = 0xee1a1a1a } }) -- x\nlocal s = "q"\nfor i = 1, 3 do hl.bind("x", hl.dsp.exec_cmd("y")) end\n')
eq(one.stmts.map(s => s.kind), ["call", "local", "block"], "kinds")
eq(L.describeTable(one.src, one.stmts[0].call.args[0])[0].fields.map(f => [f.key, f.value]), [["b", -0.4], ["c", 0xee1a1a1a]], "describe")
eq(L.setPath("hl.config({})", L.parse("hl.config({})").stmts[0].call.args[0], ["a", "b"], "1"), "hl.config({ a = { b = 1 } })", "empty table")
eq(L.lit("str", 'a"b'), '"a\\"b"', "quote")

console.log(fails ? fails + " FAILED" : "OK", "(" + checks + " checks)")
process.exit(fails ? 1 : 0)
