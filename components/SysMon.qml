import QtQuick
import QtQuick.Layouts
import "../theme"
import "../config"
import "../services"

// Нагрузка и температуры. Для каждой метрики в Config.sysmon.<id> свой режим показа
// (выкл / всегда / от жёлтого / от красного порога) и пороги. Меню → Конфигурация → Монитор.
Panel {
    id: root
    readonly property var defs: [
        { id: "cpuLoad", prefix: "CPU" },
        { id: "cpuTemp", prefix: "" },
        { id: "gpuLoad", prefix: "GPU" },
        { id: "gpuTemp", prefix: "" },
        { id: "ram", prefix: "RAM" },
        { id: "vram", prefix: "VRAM" }
    ]

    // -1 нет данных, 0 норма, 1 жёлтый, 2 красный
    function level(id) {
        const v = SysStats[id]
        if (isNaN(v)) return -1
        const c = Config.sysmon[id]
        return v >= c.red ? 2 : v >= c.yellow ? 1 : 0
    }
    function shown(id) {
        const l = level(id)
        if (l < 0) return false
        const m = Config.sysmon[id].mode
        return m === "always" || (m === "yellow" && l >= 1) || (m === "red" && l >= 2)
    }
    function fmt(id) {
        const g = mb => (mb / 1024).toFixed(1)
        switch (id) {
        case "ram": return g(SysStats.ramUsed) + "/" + Math.round(SysStats.ramTotal / 1024) + "G"
        case "vram": return g(SysStats.vramUsed) + "/" + Math.round(SysStats.vramTotal / 1024) + "G"
        case "cpuTemp": case "gpuTemp": return Math.round(SysStats[id]) + "°C"
        default: return Math.round(SysStats[id]) + "%"
        }
    }

    visible: defs.some(d => shown(d.id))

    Repeater {
        model: root.defs
        delegate: RowLayout {
            id: item
            required property var modelData
            readonly property int lvl: root.level(modelData.id)
            visible: root.shown(modelData.id)
            spacing: 4
            Label {
                text: item.modelData.prefix
                color: Theme.textDim
                font.pixelSize: Theme.fontSize - 2
            }
            Label {
                text: root.fmt(item.modelData.id)
                color: item.lvl >= 2 ? Theme.danger : item.lvl === 1 ? Theme.warn : Theme.text
                font.pixelSize: Theme.fontSize - 1
            }
        }
    }
}
