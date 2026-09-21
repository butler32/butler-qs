pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../i18n"

// Работа с NetworkManager через nmcli: активные подключения с IP и применение
// IP-профилей (DHCP / статика). Список сетей и Wi-Fi — через Quickshell.Networking.
Singleton {
    id: root

    property var active: []          // [{ device, type, name, ip, gateway }]
    property bool busy: false
    property string status: ""
    property bool statusError: false

    function refresh() { if (!info.running) info.running = true }

    // ---------- валидация ----------

    function validIp(s) {
        const m = /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/.exec((s ?? "").trim())
        return !!m && m.slice(1).every(x => Number(x) <= 255)
    }
    // маска "255.255.255.0" или "24" / "/24" → длина префикса, иначе -1
    function toPrefix(mask) {
        const s = (mask ?? "").trim().replace(/^\//, "")
        if (/^\d{1,2}$/.test(s)) return Number(s) <= 32 ? Number(s) : -1
        if (!validIp(s)) return -1
        const bits = s.split(".").map(x => Number(x).toString(2).padStart(8, "0")).join("")
        return /^1*0*$/.test(bits) ? bits.indexOf("0") === -1 ? 32 : bits.indexOf("0") : -1
    }
    function prefixToMask(p) {
        const b = "1".repeat(p) + "0".repeat(32 - p)
        return [0, 8, 16, 24].map(i => parseInt(b.slice(i, i + 8), 2)).join(".")
    }

    // ---------- применение профиля ----------

    // profile: { network, mode: "dhcp"|"static", ip, mask, gateway, dns }
    function apply(p) {
        if (busy) return
        const net = p.network
        const cmds = []
        if (p.mode === "dhcp") {
            cmds.push(["nmcli", "connection", "modify", net,
                       "ipv4.method", "auto", "ipv4.addresses", "", "ipv4.gateway", "", "ipv4.dns", ""])
        } else {
            const dns = (p.dns ?? "").split(/[\s,;]+/).filter(Boolean).join(",")
            cmds.push(["nmcli", "connection", "modify", net,
                       "ipv4.method", "manual", "ipv4.addresses", p.ip.trim() + "/" + toPrefix(p.mask),
                       "ipv4.gateway", (p.gateway ?? "").trim(), "ipv4.dns", dns])
        }
        // переподключаем только активную сеть; для неактивной настройки применятся при подключении
        if (active.some(a => a.name === net)) cmds.push(["nmcli", "connection", "up", "id", net])
        busy = true
        status = ""
        statusError = false
        runner.queue = cmds
        runner.next()
    }

    Process {
        id: runner
        property var queue: []
        stderr: StdioCollector { id: err }
        function next() {
            if (queue.length === 0) {
                root.busy = false
                root.status = I18n.tr("net.applied")
                root.refresh()
                return
            }
            command = queue[0]
            queue = queue.slice(1)
            running = true
        }
        onExited: code => {
            if (code === 0) { next(); return }
            queue = []
            root.busy = false
            root.statusError = true
            root.status = err.text.trim() || I18n.tr("net.failed")
            root.refresh()
        }
    }

    // ---------- чтение состояния ----------

    Timer { interval: 8000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }

    Process {
        id: info
        command: ["nmcli", "-t", "-f", "GENERAL.DEVICE,GENERAL.TYPE,GENERAL.CONNECTION,IP4.ADDRESS,IP4.GATEWAY", "device", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = []
                let cur = null
                for (const line of text.split("\n")) {
                    const i = line.indexOf(":")
                    if (i < 0) continue
                    const key = line.slice(0, i)
                    const val = line.slice(i + 1).replace(/\\:/g, ":")
                    if (key === "GENERAL.DEVICE") { cur = { device: val, type: "", name: "", ip: "", gateway: "" }; out.push(cur) }
                    else if (!cur) continue
                    else if (key === "GENERAL.TYPE") cur.type = val
                    else if (key === "GENERAL.CONNECTION") cur.name = val
                    else if (key === "IP4.ADDRESS[1]") cur.ip = val
                    else if (key === "IP4.GATEWAY") cur.gateway = val
                }
                // без loopback, VPN-туннелей и неподключённых устройств
                root.active = out.filter(d => d.name !== "" && d.type !== "loopback" && d.type !== "tun")
            }
        }
    }
}
