pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../config"
import "../i18n"

// Скриншоты: take("area" | "screen" | "window"). Съёмка стартует с небольшой
// задержкой, чтобы успели закрыться попап или меню, из которых её вызвали.
// Куда сохранять и что делать со снимком — Config.screenshot.
Singleton {
    id: root

    property string pendingMode: ""
    readonly property string script: Quickshell.shellPath("scripts/screenshot.sh")

    function take(mode) {
        pendingMode = mode
        if (mode === "window") Hyprland.refreshToplevels()
        Hyprland.refreshMonitors()
        delay.restart()
    }

    Timer { id: delay; interval: 400; onTriggered: root.run(root.pendingMode) }

    // области окон на видимых сейчас воркспейсах — из них slurp даёт выбрать одно
    function windowRegions() {
        const visible = new Set(Hyprland.monitors.values.map(m => m.activeWorkspace?.id))
        return Hyprland.toplevels.values
            .map(t => t.lastIpcObject)
            .filter(o => o && o.mapped && !o.hidden && visible.has(o.workspace?.id))
            .map(o => o.at[0] + "," + o.at[1] + " " + o.size[0] + "x" + o.size[1])
            .join("\n")
    }

    function run(mode) {
        const c = Config.screenshot
        proc.environment = {
            REGIONS: mode === "window" ? windowRegions() : "",
            OUTPUT: Hyprland.focusedMonitor?.name ?? ""
        }
        proc.command = [script, mode, c.save ? "1" : "0", c.copy ? "1" : "0", c.notify ? "1" : "0",
                       I18n.tr("shot.title"), I18n.tr("shot.saved"), I18n.tr("shot.copied")]
        proc.running = true
    }

    Process { id: proc }
}
