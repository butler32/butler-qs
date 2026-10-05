.pragma library
// Виды записей-таблиц конфига Hyprland, которые редактор находит и добавляет сам.
// fn — вызов в конфиге, tableArg — индекс аргумента-таблицы, head — у вызова первым аргументом идёт имя
// (hl.curve("name", {...})), title — поля для заголовка, file — куда добавлять новые, template — текст новой записи.
// Что показывать человеку и как это называется — в ConfigCatalog.js, схема опций hl.config — в ConfigOptions.js.
var KINDS = {
    monitor: {
        fn: "hl.monitor", tableArg: 0, title: ["output"], file: "configs/monitors.lua",
        template: 'hl.monitor({\n    output   = "",\n    mode     = "preferred",\n    position = "auto",\n    scale    = "1",\n})'
    },
    workspace_rule: {
        fn: "hl.workspace_rule", tableArg: 0, title: ["workspace", "monitor"], file: "configs/workspaces.lua",
        template: 'hl.workspace_rule({ workspace = "1" })'
    },
    device: {
        fn: "hl.device", tableArg: 0, title: ["name"], file: "configs/devices.lua",
        template: 'hl.device({\n    name = "",\n})'
    },
    gesture: {
        fn: "hl.gesture", tableArg: 0, title: ["fingers", "direction", "action"], file: "configs/input.lua",
        template: 'hl.gesture({\n    fingers   = 3,\n    direction = "horizontal",\n    action    = "workspace",\n})'
    },
    window_rule: {
        fn: "hl.window_rule", tableArg: 0, title: ["name"], file: "configs/windows.lua",
        template: 'hl.window_rule({\n    name  = "new-rule",\n    match = { class = "^(app)$" },\n    float = true,\n})'
    },
    curve: {
        fn: "hl.curve", tableArg: 1, head: true, title: [], file: "configs/look.lua",
        template: 'hl.curve("new-curve", { type = "bezier", points = { {0.25, 0.1}, {0.25, 1} } })'
    },
    animation: {
        fn: "hl.animation", tableArg: 0, title: ["leaf"], file: "configs/look.lua",
        template: 'hl.animation({ leaf = "global", enabled = true, speed = 5, bezier = "default" })'
    }
}

var KIND_BY_FN = (function () {
    var m = {}
    for (var k in KINDS) m[KINDS[k].fn] = k
    return m
})()

// Куда класть новую опцию hl.config, если она ещё нигде не задана (по группе).
var OPTION_FILE = { input: "configs/input.lua", misc: "configs/misc.lua" }
var OPTION_FILE_DEFAULT = "configs/look.lua"

var MODIFIERS = ["SUPER", "SHIFT", "CTRL", "ALT"]
