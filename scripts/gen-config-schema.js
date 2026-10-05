#!/usr/bin/env node
// Генерирует services/ConfigOptions.js из Lua-заглушек Hyprland (список всех hl.config опций и их типов).
//   node scripts/gen-config-schema.js [/usr/share/hypr/stubs/hl.meta.lua] > services/ConfigOptions.js
const fs = require("fs")
const stub = process.argv[2] || "/usr/share/hypr/stubs/hl.meta.lua"
const text = fs.readFileSync(stub, "utf8")
const start = text.indexOf("---@class HL.ConfigValueTypes")
const end = text.indexOf("local __HL_ConfigValueTypes")
if (start < 0 || end < 0) throw new Error("ConfigValueTypes not found in " + stub)

const map = t => {
    t = t.trim()
    if (t === "boolean") return "bool"
    if (t === "integer|boolean") return "int"
    if (t === "number|boolean") return "num"
    if (t === "string") return "str"
    if (t === "string|HL.Gradient") return "color"
    if (t === "integer|HL.CssGap") return "gap"
    return "expr"
}

const rows = []
for (const m of text.slice(start, end).matchAll(/---@field \['([^']+)'\]\s+(.+)/g))
    rows.push([m[1], map(m[2])])

// спецификации аргументов hl.monitor / hl.device / …: ---@class HL.XxxSpec + ---@field key? тип
const specMap = t => {
    t = t.trim()
    if (t === "boolean") return "bool"
    if (/^integer/.test(t) && !/string/.test(t)) return "int"
    if (/^number/.test(t) && !/string/.test(t)) return "num"
    if (/string/.test(t)) return "str"
    return "expr"
}
const specs = {}
for (const [name, cls] of [["monitor", "MonitorSpec"], ["device", "DeviceSpec"], ["workspace_rule", "WorkspaceRuleSpec"],
                           ["layer_rule", "LayerRuleSpec"], ["gesture", "GestureSpec"], ["bind_options", "BindOptions"]]) {
    const i = text.indexOf("---@class HL." + cls + "\n")
    if (i < 0) throw new Error(cls + " not found")
    const j = text.indexOf("local __HL_", i)
    specs[name] = [...text.slice(i, j).matchAll(/---@field (\w+)\??\s+(.+)/g)].map(m => [m[1], specMap(m[2])])
}

let out = ".pragma library\n"
out += "// Сгенерировано scripts/gen-config-schema.js из " + stub + " — руками не править.\n"
out += "// [путь опции в hl.config, тип]: bool | int | num | str | color | gap | expr\n"
out += "var OPTIONS = [\n" + rows.map(r => "    " + JSON.stringify(r)).join(",\n") + "\n]\n"
out += "// Аргументы hl.monitor / hl.device / hl.workspace_rule / hl.layer_rule / hl.gesture / опции hl.bind: [ключ, тип]\n"
out += "var SPECS = {\n" + Object.keys(specs).map(k => "    " + k + ": [\n" + specs[k].map(r => "        " + JSON.stringify(r)).join(",\n") + "\n    ]").join(",\n") + "\n}\n"
process.stdout.write(out)
