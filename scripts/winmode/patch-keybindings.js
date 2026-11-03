#!/usr/bin/env node
// Оборачивает привязки смены воркспейсов в WM_GUARD(...), чтобы в оконном режиме они ничего не делали.
// Идемпотентно. Использование: patch-keybindings.js <keybindings.lua> [--undo]
// Затрагиваются только строки hl.bind(<клавиши>, <действие>) без таблицы опций
// с действиями focus/window.move на workspace и workspace.toggle_special.
const fs = require("fs")
const [file, flag] = process.argv.slice(2)
if (!file) { console.error("usage: patch-keybindings.js <keybindings.lua> [--undo]"); process.exit(2) }

const DEF = [
    "-- В оконном режиме (WM_LOCK, см. winmode.lua) смена воркспейсов заблокирована",
    "local function WM_GUARD(d)",
    "    return function() if not WM_LOCK then hl.dispatch(d) end end",
    "end",
    "",
].join("\n")
const ACTION = /(hl\.dsp\.(?:focus\(\{\s*workspace|window\.move\(\{\s*workspace|workspace\.toggle_special)\b)/
const WRAPPED = /^(\s*hl\.bind\(.*?,\s*)WM_GUARD\((hl\.dsp\..*)\)\)\s*$/
const PLAIN = /^(\s*hl\.bind\(.*?,\s*)(hl\.dsp\..*)\)\s*$/

let src = fs.readFileSync(file, "utf8")
let n = 0, skipped = []
const lines = src.split("\n").map((l, i) => {
    if (flag === "--undo") {
        const m = l.match(WRAPPED)
        if (m) { n++; return m[1] + m[2] + ")" }
        return l
    }
    if (l.includes("WM_GUARD") || !ACTION.test(l)) return l
    const m = l.match(PLAIN)
    if (!m || /\)\s*,\s*\{[^}]*\}\s*\)\s*$/.test(l)) { skipped.push(i + 1); return l }
    n++
    return m[1] + "WM_GUARD(" + m[2] + "))"
})
src = lines.join("\n")

if (flag === "--undo") {
    src = src.replace("\n" + DEF, "").replace(DEF, "")
} else if (!src.includes("local function WM_GUARD")) {
    // определение — в начало файла, после строки с mainMod (иначе в самое начало)
    const m = src.match(/^.*\bmainMod\b\s*=.*$/m)
    const at = m ? m.index + m[0].length + 1 : 0
    src = src.slice(0, at) + "\n" + DEF + src.slice(at)
}
fs.writeFileSync(file, src)
console.log(`${flag === "--undo" ? "unwrapped" : "wrapped"} ${n} bind(s)` + (skipped.length ? `; skipped (have options, wrap by hand) lines: ${skipped.join(", ")}` : ""))
