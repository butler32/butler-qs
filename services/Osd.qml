pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "../i18n"
import "../config"

// Состояние OSD (громкость / микрофон / яркость / Caps Lock).
// Громкость и микрофон отслеживаются сами — по изменениям PipeWire, откуда бы они ни
// пришли (клавиши, микшер, колесо, приложения). Яркость и Caps Lock приходят по IPC:
//   qs -c butler ipc call osd event <brightness|capslock> <значение>
Singleton {
    id: root

    // { kind, glyph, label, fraction, muted } или null
    property var current: null
    property int serial: 0            // растёт при каждом показе — перезапускает таймер скрытия

    function show(kind, value) {
        if (!Config.osd.enabled) return
        const v = Number(value)
        const pct = isNaN(v) ? 0 : Math.round(v)
        let e = null
        switch (kind) {
        case "volume": e = volumeEvent(pct / 100, false); break
        case "volume-muted": e = volumeEvent(pct / 100, true); break
        case "mic": e = { glyph: value === "off" ? "" : "", muted: value === "off",
                          label: I18n.tr(value === "off" ? "osd.mic.off" : "osd.mic.on"), fraction: value === "off" ? 0 : 1 }; break
        case "brightness": e = { glyph: "", muted: false, label: pct + "%", fraction: pct / 100 }; break
        case "capslock": e = { glyph: "", muted: value !== "on",
                               label: I18n.tr(value === "on" ? "osd.caps.on" : "osd.caps.off"), fraction: value === "on" ? 1 : 0 }; break
        }
        if (!e) return
        current = e
        serial++
    }

    function volumeEvent(vol, muted) {
        const pct = Math.round(vol * 100)
        return { glyph: muted ? "" : vol < 0.34 ? "" : "", muted: muted,
                 label: pct + "%" + (muted ? " (" + I18n.tr("osd.muted") + ")" : ""), fraction: Math.min(1, vol) }
    }

    // ---------- реакция на PipeWire ----------

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [root.sink, root.source] }

    // Не показываем OSD на старте и сразу после смены устройства по умолчанию
    // (у нового устройства «меняется» громкость просто оттого, что мы её впервые прочитали).
    property bool armed: false
    Timer { id: settle; interval: 1500; running: true; onTriggered: root.armed = true }
    onSinkChanged: { armed = false; settle.restart() }
    onSourceChanged: { armed = false; settle.restart() }

    // пока открыто окно микшера, его ползунки и так всё показывают
    readonly property bool quiet: !armed || Popups.activeId !== ""

    Connections {
        target: root.sink?.audio ?? null
        function onVolumeChanged() { if (!root.quiet) root.show(root.sink.audio.muted ? "volume-muted" : "volume", root.sink.audio.volume * 100) }
        function onMutedChanged() { if (!root.quiet) root.show(root.sink.audio.muted ? "volume-muted" : "volume", root.sink.audio.volume * 100) }
    }
    Connections {
        target: root.source?.audio ?? null
        function onMutedChanged() { if (!root.quiet) root.show("mic", root.source.audio.muted ? "off" : "on") }
    }
}
