pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Поиск окон Hyprland по идентификаторам приложения и переход к окну.
Singleton {
    function norm(s) { return (s ?? "").toLowerCase().replace(/\.desktop$/, "").replace(/[^a-z0-9]/g, "") }

    // окна, чей class совпадает с любым из ключей (id .desktop, StartupWMClass, имя, identity плеера…)
    function matching(keys) {
        const ks = keys.map(norm).filter(k => k.length > 1)
        return Hyprland.toplevels.values.filter(t => {
            const c = [norm(t.lastIpcObject?.class), norm(t.lastIpcObject?.initialClass)].filter(x => x.length > 1)
            return c.some(x => ks.some(k => x === k || x.endsWith(k) || k.endsWith(x)))
        })
    }

    // фокус на окно; если оно на другом воркспейсе — переключает и его
    function focus(t) {
        const a = t.address
        Hyprland.dispatch("hl.dsp.focus({ window = \"address:" + (a.startsWith("0x") ? a : "0x" + a) + "\" })")
    }
}
