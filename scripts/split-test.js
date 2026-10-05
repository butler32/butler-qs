#!/usr/bin/env node
// Проверка services/ConfigSplit.js: разбить /usr/share/hypr/hyprland.lua (или файл из аргумента),
// каждый получившийся файл должен компилироваться luajit, число инструкций сохраняться.
const fs = require("fs"), path = require("path"), cp = require("child_process")
const load = f => new Function(fs.readFileSync(path.join(__dirname, "../services/" + f), "utf8").replace(/^\.pragma library\n/, "") + "\nreturn this")
const rd = f => fs.readFileSync(path.join(__dirname, "../services/" + f), "utf8").replace(/^\.pragma library\n/, "")
const Lua = new Function(rd("LuaConf.js") + "\nreturn { parse, callName }")()
const Split = new Function("Lua", rd("ConfigSplit.js").replace(/^\.import.*\n/m, "") + "\nreturn { plan }")(Lua)
const src = fs.readFileSync(process.argv[2] || "/usr/share/hypr/hyprland.lua", "utf8")
const r = Split.plan(src)
let fails = 0
const check = (name, text) => {
    fs.writeFileSync("/tmp/split-test.lua", text)
    const ok = cp.spawnSync("luajit", ["-bl", "/tmp/split-test.lua"], { encoding: "utf8" }).status === 0
    if (!ok) { fails++; console.log("FAIL luajit", name) }
}
if (!r) { console.log("FAIL: plan returned null"); process.exit(1) }
const count = t => Lua.parse(t).stmts.length
let total = count(r.main)
check("hyprland.lua", r.main)
for (const f of r.files) { total += count(f.text); check(f.path, f.text); console.log(f.path, count(f.text)) }
const reqs = (r.main.match(/^require\(/mg) || []).length
if (total - reqs !== count(src)) { fails++; console.log("FAIL count", total - reqs, count(src)) }
if (process.env.SHOW) { console.log("--- main\n" + r.main); for (const f of r.files) console.log("--- " + f.path + "\n" + f.text) }
console.log(fails ? "FAILED" : "OK")
process.exit(fails ? 1 : 0)
