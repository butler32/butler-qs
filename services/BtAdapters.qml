pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

// MAC-адреса адаптеров BlueZ: Quickshell их не отдаёт, берём у bluez через busctl.
// MAC (в отличие от hciN и имени) стабилен, поэтому в конфиге хранится он.
Singleton {
    id: root
    property var macs: ({})   // { "hci1": "BC:C7:..." }

    function macOf(adapter) {
        const id = (adapter?.dbusPath ?? "").split("/").pop()
        return macs[id] ?? ""
    }
    function find(mac) {
        return mac ? Bluetooth.adapters.values.find(a => macOf(a) === mac) ?? null : null
    }

    function refresh() { if (!proc.running) proc.running = true }
    Connections { target: Bluetooth.adapters; function onValuesChanged() { root.refresh() } }
    Component.onCompleted: refresh()

    Process {
        id: proc
        command: ["sh", "-c", "for p in $(busctl --system tree org.bluez --list 2>/dev/null | grep -E '^/org/bluez/hci[0-9]+$'); do echo \"${p##*/} $(busctl --system get-property org.bluez $p org.bluez.Adapter1 Address | cut -d'\"' -f2)\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = {}
                for (const l of text.split("\n")) {
                    const [id, mac] = l.trim().split(" ")
                    if (id && mac) m[id] = mac
                }
                root.macs = m
            }
        }
    }
}
