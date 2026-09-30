pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

// История буфера обмена поверх cliphist: пока включено Config.clipboard.enabled, шелл сам
// держит два `wl-paste --watch cliphist store` (текст и картинки). Без cliphist или
// wl-clipboard (available = false) пункт меню скрыт.
Singleton {
    id: root

    property bool available: false
    readonly property bool active: available && Config.clipboard.enabled
    // { id, text, image } от новых к старым
    property var entries: []

    Process {
        command: ["sh", "-c", "command -v cliphist && command -v wl-paste"]
        running: true
        onExited: code => root.available = code === 0
    }

    function watcher(type) {
        return ["wl-paste", "--type", type, "--watch", "cliphist", "-max-items", String(Config.clipboard.maxItems), "store"]
    }
    Process { id: textWatch; command: root.watcher("text"); running: root.active }
    Process { id: imageWatch; command: root.watcher("image"); running: root.active }

    // -max-items читается при старте watcher'а — перезапускаем с новым лимитом
    Connections {
        target: Config.clipboard
        function onMaxItemsChanged() { textWatch.running = false; imageWatch.running = false; restart.restart() }
    }
    Timer { id: restart; interval: 300; onTriggered: { textWatch.running = root.active; imageWatch.running = root.active } }

    function refresh() { if (available) list.running = true }

    Process {
        id: list
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = []
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t")
                    if (tab < 1) continue
                    const preview = line.slice(tab + 1).replace(/\s+/g, " ").trim()
                    const bin = preview.match(/^\[\[ binary data (.*) \]\]$/)
                    out.push({ id: line.slice(0, tab), text: bin ? bin[1] : preview, image: !!bin })
                    if (out.length >= 200) break
                }
                root.entries = out
            }
        }
    }

    // кладёт запись обратно в буфер обмена (вставка — Ctrl+V в нужном окне)
    function copy(id) {
        Quickshell.execDetached(["sh", "-c", "cliphist decode \"$1\" | wl-copy", "sh", id])
    }
    function wipe() {
        Quickshell.execDetached(["cliphist", "wipe"])
        entries = []
    }
}
