pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../i18n"

// Работа с NetworkManager через nmcli: активные подключения с IP и применение
// IP-профилей (DHCP / статика), список Wi-Fi сетей и подключение к ним.
// Quickshell.Networking намеренно НЕ используется: удаление точек доступа в нём роняло
// весь шелл (segfault сразу после «Access point removed»). Здесь только plain-данные.
Singleton {
    id: root

    property var active: []          // [{ device, type, name, ip, gateway }]
    property var wifi: []            // [{ name, signal (0..100), secure, connected, known }], сильнейшие сверху
    property bool wifiEnabled: true
    property bool hasWifi: false     // есть Wi-Fi адаптер
    property bool fast: false        // окно сети открыто — опрашиваем чаще
    property bool busy: false
    property string status: ""
    property bool statusError: false

    // VPN — butler-vpn.service (systemd): OpenVPN + kill switch, see scripts/vpn/.
    // Passwordless sudo is scoped to exactly `systemctl start/stop butler-vpn.service`
    // (scripts/vpn/sudoers-butler-vpn) — nothing else needs elevation.
    property string vpnState: "disconnected"   // disconnected | connecting | connected | failed
    readonly property bool vpnConnected: vpnState === "connected"
    readonly property bool vpnBusy: vpnState === "connecting" || vpnRunner.running
    // .ovpn, найденные в типичных местах; Config.network.vpnConfig пусто = vpnDefaultConfig
    readonly property string vpnDefaultConfig: Quickshell.env("HOME") + "/vpn/germany/openvpn_full.ovpn"
    property var vpnConfigs: []
    function refreshVpnConfigs() { if (!vpnFind.running) vpnFind.running = true }
    Process {
        id: vpnFind
        command: ["sh", "-c", "find \"$HOME/vpn\" \"$HOME/.config/openvpn\" \"$HOME/Downloads\" -maxdepth 4 -type f -name '*.ovpn' 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root.vpnConfigs = text.split("\n").filter(l => l.endsWith(".ovpn")).sort()
        }
    }
    property string vpnStatus: ""
    property bool vpnStatusError: false

    function refresh() {
        if (!info.running) info.running = true
        if (!wifiList.running) wifiList.running = true
        if (!known.running) known.running = true
        if (!radio.running) radio.running = true
        if (!vpnPoll.running) vpnPoll.running = true
    }

    // ---------- Wi-Fi ----------

    function rescan() { Quickshell.execDetached(["nmcli", "device", "wifi", "rescan"]) }
    function setWifiEnabled(on) { run([["nmcli", "radio", "wifi", on ? "on" : "off"]]) }
    // password — только для новой защищённой сети; известные подключаются по сохранённому профилю
    function connectWifi(n, password) {
        if (password) run([["nmcli", "device", "wifi", "connect", n.name, "password", password]])
        else if (n.known) run([["nmcli", "connection", "up", "id", n.name]])
        else run([["nmcli", "device", "wifi", "connect", n.name]])
    }
    function disconnectWifi(n) { run([["nmcli", "connection", "down", "id", n.name]]) }

    // ---------- VPN ----------

    // systemctl start/stop blocks until butler-vpn.service actually reports ready
    // (Type=notify — the unit signals readiness only once the tunnel and kill
    // switch are up) or fails, so vpnRunner.running alone covers "connecting".
    function vpnRun(cmd) {
        if (vpnRunner.running) return
        vpnStatus = ""
        vpnStatusError = false
        vpnRunner.command = cmd
        vpnRunner.running = true
    }
    function connectVpn() { vpnRun(["sudo", "-n", "/usr/bin/systemctl", "start", "butler-vpn.service"]) }
    function disconnectVpn() { vpnRun(["sudo", "-n", "/usr/bin/systemctl", "stop", "butler-vpn.service"]) }
    function toggleVpn() { vpnConnected ? disconnectVpn() : connectVpn() }

    Process {
        id: vpnRunner
        stderr: StdioCollector { id: vpnErr }
        onExited: code => {
            if (code === 0) {
                root.vpnStatusError = false
                root.vpnStatus = ""
            } else {
                root.vpnStatusError = true
                // most likely causes: sudoers rule not installed yet (-n makes sudo fail
                // fast instead of hanging on a password prompt it can't show), or the
                // unit itself failed — see journalctl -u butler-vpn -e
                root.vpnStatus = vpnErr.text.trim() || I18n.tr("vpn.failed")
            }
            vpnPoll.running = true
        }
    }

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
        run(cmds)
    }

    // последовательно выполняет команды; результат — в status/statusError
    function run(cmds) {
        if (busy) return
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

    Timer { interval: root.fast ? 3000 : 10000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }

    // разбор строки nmcli -t: поля через неэкранированное ":"
    function fields(line) {
        const out = [""]
        for (let i = 0; i < line.length; i++) {
            const ch = line[i]
            if (ch === "\\" && i + 1 < line.length) out[out.length - 1] += line[++i]
            else if (ch === ":") out.push("")
            else out[out.length - 1] += ch
        }
        return out
    }

    Process {
        id: radio
        command: ["nmcli", "radio", "wifi"]
        stdout: StdioCollector { onStreamFinished: root.wifiEnabled = text.trim() === "enabled" }
    }

    property var knownNames: []
    Process {
        id: known
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: root.knownNames = text.split("\n").map(root.fields)
                .filter(f => f[1] === "802-11-wireless").map(f => f[0])
        }
    }

    // "systemctl is-active" itself needs no privilege and exits non-zero for every
    // state that isn't "active" — that's expected, so only stdout is read here.
    Process {
        id: vpnPoll
        command: ["/usr/bin/systemctl", "is-active", "butler-vpn.service"]
        stdout: StdioCollector {
            onStreamFinished: {
                const s = text.trim()
                if (s === "active") root.vpnState = "connected"
                else if (s === "activating" || s === "deactivating") root.vpnState = "connecting"
                else if (s === "failed") root.vpnState = "failed"
                else root.vpnState = "disconnected"
            }
        }
    }

    Process {
        id: wifiList
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "no"]
        stdout: StdioCollector {
            onStreamFinished: {
                const best = {}
                for (const line of text.split("\n")) {
                    const f = root.fields(line)
                    if (f.length < 4 || f[1] === "") continue
                    const n = { name: f[1], signal: Number(f[2]) || 0, secure: f[3] !== "",
                                connected: f[0] === "*", known: root.knownNames.includes(f[1]) }
                    const prev = best[n.name]
                    if (!prev || n.connected || (!prev.connected && n.signal > prev.signal)) best[n.name] = n
                }
                root.wifi = Object.values(best).sort((a, b) => (b.connected - a.connected) || (b.signal - a.signal))
            }
        }
    }

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
                root.hasWifi = out.some(d => d.type === "wifi")
                // без loopback, VPN-туннелей и неподключённых устройств
                root.active = out.filter(d => d.name !== "" && d.type !== "loopback" && d.type !== "tun")
            }
        }
    }
}
