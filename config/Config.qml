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
            }
        }
    }

    function setWorkspaceIcon(id, spec) {
        const icons = Object.assign({}, ws.icons)
        if (spec) icons[id] = spec
        else delete icons[id]
        ws.icons = icons
    }
}
