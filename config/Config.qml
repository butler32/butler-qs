pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Настройки бара, редактируются через Меню → Конфигурация и хранятся в JSON
// в state-директории шелла. Любая новая опция бара: поле здесь + пункт в
// MenuPages.qml + строки в i18n.
Singleton {
    id: root

    readonly property var ws: adapter.workspaces
    readonly property var notifications: adapter.notifications
    readonly property var media: adapter.media
    readonly property var clock: adapter.clock
    readonly property var apps: adapter.apps
    readonly property var sysmon: adapter.sysmon
    readonly property var network: adapter.network
    readonly property var osd: adapter.osd
    readonly property var claudeUsage: adapter.claudeUsage

    FileView {
        id: file
        path: Quickshell.statePath("config.json")
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter() }

        adapter: JsonAdapter {
            id: adapter
            property JsonObject workspaces: JsonObject {
                // Стиль для воркспейсов без своей иконки: "dot" | "number"
                property string defaultStyle: "dot"
                // id → "dot" | "number" | "icon:<имя иконки>"; нет записи = стиль по умолчанию
                property var icons: ({})
                property int total: 10
                property bool collapsible: true
                property int visibleCount: 6
                // Показывать воркспейсы с окнами даже в свёрнутом виде
                property bool showOccupied: true
                property bool notifyHighlight: true
            }
            property JsonObject notifications: JsonObject {
                // Сколько уведомлений одновременно на экране; остальные ждут в очереди
                property int maxVisible: 4
                // Секунд до автоисчезания, 0 = никогда (critical не исчезают сами)
                property int timeoutSec: 5
                // Длительность затухания opacity 1 → 0, мс
                property int fadeMs: 400
                // true: пока курсор над любым уведомлением, таймеры всех остановлены
                property bool pauseAllOnHover: false
            }
            property JsonObject media: JsonObject {
                property bool enabled: true
                property bool showPrevNext: true
                // Показывать только плеер этого приложения (часть identity/desktop-entry,
                // например "spotify"); пусто = любой, играющий в приоритете
                property string pinnedApp: ""
            }
            property JsonObject clock: JsonObject {
                property bool showDate: true
                property bool weekStartsMonday: true
                property bool showSeconds: false
            }
            property JsonObject apps: JsonObject {
                // id .desktop-файлов приложений в виджете иконок; по умолчанию пусто
                property var pinned: []
            }
            property JsonObject sysmon: JsonObject {
                property MetricConfig cpuLoad: MetricConfig { mode: "always"; yellow: 60; red: 85 }
                property MetricConfig cpuTemp: MetricConfig { mode: "yellow"; yellow: 70; red: 85 }
                property MetricConfig gpuLoad: MetricConfig { mode: "always"; yellow: 60; red: 85 }
                property MetricConfig gpuTemp: MetricConfig { mode: "yellow"; yellow: 70; red: 85 }
                property MetricConfig ram: MetricConfig { mode: "always"; yellow: 70; red: 90 }
                property MetricConfig vram: MetricConfig { mode: "yellow"; yellow: 70; red: 90 }
            }
            property JsonObject osd: JsonObject {
                property bool enabled: true
                property int timeoutMs: 1200
                property string position: "bottom"   // bottom | top
            }
            property JsonObject claudeUsage: JsonObject {
                // порог/видимость — процент ИСПОЛЬЗОВАННОГО лимита подписки (как у sysmon);
                // в баре при этом показывается остаток (100 − used), см. components/ClaudeUsage.qml
                property MetricConfig session: MetricConfig { mode: "always"; yellow: 70; red: 90 }
                property MetricConfig week: MetricConfig { mode: "always"; yellow: 70; red: 90 }
            }
            property JsonObject network: JsonObject {
                // { name, network (имя NM-подключения), mode: "dhcp"|"static", ip, mask, gateway, dns }
                property var profiles: []
                // домены, которые VPN не должен заворачивать в туннель; читается
                // напрямую из этого файла привилегированным butler-vpn-up.sh
                // (см. scripts/vpn/), резолвится один раз при подключении
                property var vpnExcludedDomains: []
            }
        }
    }

    function setWorkspaceIcon(id, spec) {
        const icons = Object.assign({}, ws.icons)
        if (spec) icons[id] = spec
        else delete icons[id]
        ws.icons = icons
    }

    readonly property var metricIds: ["cpuLoad", "cpuTemp", "gpuLoad", "gpuTemp", "ram", "vram"]

    // закрепление приложений в виджете иконок
    function togglePinnedApp(id) {
        const list = [...apps.pinned]
        const i = list.indexOf(id)
        if (i >= 0) list.splice(i, 1)
        else list.push(id)
        apps.pinned = list
    }

    // index = -1 — новый профиль
    function saveNetworkProfile(index, profile) {
        const list = [...network.profiles]
        if (index >= 0 && index < list.length) list[index] = profile
        else list.push(profile)
        network.profiles = list
    }
    function deleteNetworkProfile(index) {
        network.profiles = network.profiles.filter((_, i) => i !== index)
    }

    function addVpnExcludedDomain(domain) {
        const d = domain.trim().toLowerCase()
        if (!d || network.vpnExcludedDomains.includes(d)) return
        network.vpnExcludedDomains = [...network.vpnExcludedDomains, d]
    }
    function removeVpnExcludedDomain(index) {
        network.vpnExcludedDomains = network.vpnExcludedDomains.filter((_, i) => i !== index)
    }
}
