pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

// Ночной режим: держит запущенным `hyprsunset -t <K>`, пока включён Config.night.enabled.
// Без hyprsunset в системе (available = false) кнопка в баре скрыта.
// Процессом управляем только через sync(): присваивание `running` ломает привязку,
// поэтому состояние всегда выводится из `active`, а не из того, что было присвоено раньше.
Singleton {
    id: root

    property bool available: false
    readonly property bool active: available && Config.night.enabled
    property bool restarting: false

    function toggle() { Config.night.enabled = !Config.night.enabled }

    function sync() { sunset.running = active }
    onActiveChanged: sync()

    Process {
        command: ["sh", "-c", "command -v hyprsunset"]
        running: true
        onExited: code => root.available = code === 0
    }

    Process {
        id: sunset
        command: ["hyprsunset", "-t", String(Config.night.temperature)]
        // после остановки ради новой температуры — запуск заново, если режим всё ещё включён
        onRunningChanged: if (!running && root.restarting) { root.restarting = false; root.sync() }
    }

    // hyprsunset не меняет температуру на лету — перезапускаем процесс с новым значением
    Connections {
        target: Config.night
        function onTemperatureChanged() { if (sunset.running) { root.restarting = true; sunset.running = false } }
    }
}
