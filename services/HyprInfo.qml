pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "ConfigCatalog.js" as Cat

// Живые данные для списков выбора в редакторе конфигов: мониторы и их режимы, классы открытых окон,
// устройства ввода, раскладки клавиатуры (из xkb), приложения и текущие значения опций Hyprland
// (по ним показываем «по умолчанию» у тех настроек, которые не заданы в конфиге).
Singleton {
    id: root

    property var monitors: []          // [{name, description, width, height, refresh, modes:[…]}]
    property var classes: []           // классы открытых окон
    property var devices: []           // [{name, type}]
    property var layouts: []           // [{value, label}]  — раскладки xkb
    property var switchOptions: []     // [{value, label}]  — grp:* из xkb options
    property var defaults: ({})        // "general.gaps_in" → значение (ничего не задано → умолчание Hyprland)
    property int defaultsRev: 0

    readonly property var apps: DesktopEntries.applications.values
        .filter(e => !e.noDisplay)
        .map(e => ({ name: e.name, exec: stripCodes(e.execString || (e.command ? e.command.join(" ") : "")), icon: e.icon, id: e.id }))
        .sort((a, b) => a.name.localeCompare(b.name))

    function stripCodes(s) { return String(s).replace(/%[a-zA-Z]/g, "").replace(/\s+/g, " ").trim() }

    function refresh() {
        monitorsProc.running = true
        clientsProc.running = true
        devicesProc.running = true
    }

    // Текущие значения опций (по ним «по умолчанию»): один вызов hyprctl --batch на все пути из каталога.
    function fetchDefaults(paths) {
        if (!paths.length) return
        defaultsProc.command = ["hyprctl", "--batch", paths.map(p => "j/getoption " + p.replace(/\./g, ":")).join(" ; ")]
        defaultsProc.running = true
    }
    function defaultOf(path) {
        void defaultsRev
        const v = defaults[path]
        return v === "[[EMPTY]]" ? undefined : v
    }

    function monitorByName(name) { for (const m of monitors) if (m.name === name) return m; return null }

    // Режимы монитора для списка: значение как в конфиге ("2560x1440@165"), подпись «2560×1440 · 165 Гц».
    function modeKey(m) {
        const r = /^(\d+x\d+)@([\d.]+)Hz$/.exec(m)
        return r ? r[1] + "@" + Math.round(parseFloat(r[2])) : m
    }
    function sameMode(a, b) { return modeKey(a) === modeKey(b) }

    Process {
        id: monitorsProc
        command: ["hyprctl", "-j", "monitors", "all"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.monitors = JSON.parse(text).map(m => ({
                        name: m.name, description: m.description, width: m.width, height: m.height,
                        refresh: m.refreshRate, modes: m.availableModes ?? []
                    }))
                } catch (e) {}
            }
        }
    }
    Process {
        id: clientsProc
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.classes = [...new Set(JSON.parse(text).map(c => c.class).filter(c => c))].sort() } catch (e) {}
            }
        }
    }
    Process {
        id: devicesProc
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text), out = []
                    for (const k of ["mice", "keyboards", "tablets", "touch"])
                        for (const x of (d[k] ?? [])) out.push({ name: x.name, type: k })
                    root.devices = out
                } catch (e) {}
            }
        }
    }
    Process {
        id: defaultsProc
        stdout: StdioCollector {
            onStreamFinished: {
                const out = {}
                for (const chunk of text.split(/\n\s*\n/)) {
                    try {
                        const o = JSON.parse(chunk.trim())
                        const v = o.bool ?? o.int ?? o.float ?? o.str ?? o.css
                        if (v !== undefined) out[o.option.replace(/:/g, ".")] = v
                    } catch (e) {}
                }
                root.defaults = out
                root.defaultsRev++
            }
        }
    }

    // Раскладки и сочетания переключения — из справочника xkb
    FileView {
        path: "/usr/share/X11/xkb/rules/base.lst"
        printErrors: false
        onLoaded: {
            let sec = "", lay = [], opt = []
            for (const line of text().split("\n")) {
                if (line.charAt(0) === "!") { sec = line.slice(1).trim(); continue }
                const m = /^\s+(\S+)\s+(.*)$/.exec(line)
                if (!m) continue
                if (sec === "layout") lay.push({ value: m[1], label: m[2] + " — " + m[1] })
                else if (sec === "option" && m[1].indexOf("grp:") === 0) opt.push({ value: m[1], label: m[2] })
            }
            root.layouts = lay
            root.switchOptions = opt
        }
    }
}
