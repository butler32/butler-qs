pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Системные метрики: раз в 2 с запускает scripts/sysstat.sh и разбирает вывод.
// Загрузка CPU считается по разнице счётчиков /proc/stat между запусками.
Singleton {
    id: root

    // проценты (кроме температур, °C); NaN — данных нет
    property real cpuLoad: NaN
    property real cpuTemp: NaN
    property real gpuLoad: NaN
    property real gpuTemp: NaN
    property real ram: NaN
    property real vram: NaN
    property real ramUsed: NaN    // МБ
    property real ramTotal: NaN
    property real vramUsed: NaN
    property real vramTotal: NaN

    property real _prevTotal: NaN
    property real _prevIdle: NaN

    function pct(used, total) { return total > 0 ? used * 100 / total : NaN }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!proc.running) proc.running = true
    }

    Process {
        id: proc
        command: ["sh", Quickshell.shellPath("scripts/sysstat.sh")]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = {}
                for (const line of text.split("\n")) {
                    const [k, val] = line.trim().split(" ")
                    if (k && val !== undefined) v[k] = Number(val)
                }
                if (v.cpu_total !== undefined) {
                    if (!isNaN(root._prevTotal) && v.cpu_total > root._prevTotal)
                        root.cpuLoad = 100 * (1 - (v.cpu_idle - root._prevIdle) / (v.cpu_total - root._prevTotal))
                    root._prevTotal = v.cpu_total
                    root._prevIdle = v.cpu_idle
                }
                root.cpuTemp = v.cpu_temp ?? NaN
                root.gpuLoad = v.gpu_load ?? NaN
                root.gpuTemp = v.gpu_temp ?? NaN
                root.ramUsed = v.ram_used ?? NaN
                root.ramTotal = v.ram_total ?? NaN
                root.vramUsed = v.vram_used ?? NaN
                root.vramTotal = v.vram_total ?? NaN
                root.ram = root.pct(root.ramUsed, root.ramTotal)
                root.vram = root.pct(root.vramUsed, root.vramTotal)
            }
        }
    }
}
