import QtQuick
import Quickshell.Io
import Quickshell.Hyprland
import "../theme"

Panel {
    id: root
    property string layout: "??"

    readonly property var known: ({ "English (US)": "EN", "Russian": "RU" })
    function short(name) { return known[name] ?? name.slice(0, 2).toUpperCase() }

    // Через hyprctl берём раскладку именно основной клавиатуры;
    // raw-событие activelayout приходит и от виртуальных устройств.
    Process {
        id: query
        command: ["hyprctl", "devices", "-j"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kbs = JSON.parse(text).keyboards
                    const kb = kbs.find(k => k.main) ?? kbs[0]
                    if (kb) root.layout = root.short(kb.active_keymap)
                } catch (e) {}
            }
        }
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout") {
                query.running = false
                query.running = true
            }
        }
    }

    Label { text: ""; color: Theme.accent }
    Label { text: root.layout; font.bold: true }
}
