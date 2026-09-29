pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Оставшийся процент лимитов подписки Claude Code: 5-часовая сессия и неделя.
// Раз в 2 мин запускает scripts/claude_usage.py (тот дёргает бесплатную встроенную
// команду `claude -p "/usage"`) и разбирает JSON.
Singleton {
    id: root

    property var session: null   // {used, resets} | null — нет данных
    property var week: null

    Timer {
        interval: 120000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!proc.running) proc.running = true
    }

    Process {
        id: proc
        command: ["python3", Quickshell.shellPath("scripts/claude_usage.py")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const v = JSON.parse(text)
                    root.session = v.session ?? null
                    root.week = v.week ?? null
                } catch (e) {
                    // битый вывод — оставляем прошлое значение
                }
            }
        }
    }
}
