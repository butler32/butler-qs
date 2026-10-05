#!/usr/bin/env node
// Проверка services/ConfigCatalog.js: каждая опция каталога существует в схеме Hyprland (ConfigOptions.js),
// у каждой есть название и пояснения на обоих языках там, где они заданы, а select-значения не пустые.
const fs = require("fs"), path = require("path")
// выполняет .pragma library-файл и возвращает все его top-level var/function
const sandbox = f => {
    const code = fs.readFileSync(path.join(__dirname, "../services", f), "utf8").replace(/^\.pragma library\n/, "")
    const names = [...code.matchAll(/^(?:var|function) (\w+)/gm)].map(m => m[1])
    return new Function(code + "\nreturn { " + names.join(", ") + " }")()
}
const Opt = sandbox("ConfigOptions.js"), Cat = sandbox("ConfigCatalog.js")
const known = {}
for (const [p, t] of Opt.OPTIONS) known[p] = t
let bad = 0
const err = m => { bad++; console.log("FAIL", m) }
const text = (t, where) => { if (!t || !t.ru || !t.en) err("missing ru/en text: " + where) }
let n = 0
for (const s of Cat.SECTIONS) {
    text(s.title, s.id); text(s.hint, s.id + " hint")
    for (const b of s.blocks) {
        if (b.type !== "options") continue
        text(b.title, s.id + " block")
        for (const i of b.items) {
            n++
            if (!known[i.path]) err("unknown option " + i.path)
            text(i.title, i.path)
            if (i.hint) text(i.hint, i.path + " hint")
            if (i.ctl === "select" && !i.options && !i.from) err("select without options " + i.path)
            if ((i.ctl === "int" || i.ctl === "num") && known[i.path] && !/int|num|gap/.test(known[i.path])) err("type mismatch " + i.path + " " + known[i.path])
            if (i.ctl === "toggle" && known[i.path] !== "bool") err("toggle on non-bool " + i.path + " " + known[i.path])
        }
    }
}
console.log(bad ? bad + " problems" : "OK", "(" + n + " options)")
process.exit(bad ? 1 : 0)
