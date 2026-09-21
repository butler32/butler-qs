import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import "../theme"
import "../i18n"

// Значок громкости; клик — микшер: системный вывод и ввод с выбором устройств
// и отдельные регуляторы каждого приложения. Колесо над значком — громкость,
// средняя кнопка — mute.
Panel {
    id: root
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var audio: sink?.audio ?? null
    readonly property real volume: audio?.volume ?? 0
    readonly property bool muted: audio?.muted ?? true

    // Списки для окна. Узлы появляются/исчезают (потоки приложений — постоянно),
    // поэтому это простые массивы, пересобираемые целиком.
    readonly property var nodes: Pipewire.nodes.values
    readonly property var sinks: nodes.filter(n => n.isSink && !n.isStream && n.audio)
    readonly property var sources: nodes.filter(n => !n.isSink && !n.isStream && n.audio)
    readonly property var streams: nodes.filter(n => n.isSink && n.isStream && n.audio)

    // без трекера у узлов нет данных о громкости
    PwObjectTracker { objects: root.nodes }

    implicitWidth: Theme.barHeight
    Label {
        Layout.alignment: Qt.AlignCenter
        text: root.muted ? "" : root.volume < 0.34 ? "" : ""
        color: root.muted ? Theme.danger : Theme.accent
    }

    overlay: MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: m => {
            if (m.button === Qt.MiddleButton) { if (root.audio) root.audio.muted = !root.audio.muted }
            else popup.toggle()
        }
        onWheel: w => {
            if (!root.audio) return
            root.audio.muted = false
            root.audio.volume = Math.max(0, Math.min(1, root.volume + (w.angleDelta.y > 0 ? 0.05 : -0.05)))
        }
    }

    function appIcon(n) {
        const p = n.properties
        const app = p["application.name"] ?? n.name
        const entry = DesktopEntries.heuristicLookup(app)
        const name = p["application.icon-name"] || entry?.icon || (app ?? "").toLowerCase()
        return Quickshell.iconPath(name, true) || ""
    }

    BarPopup {
        id: popup
        anchorItem: root
        ipcName: "mixer"
        screen: root.QsWindow.window?.screen ?? null
        minWidth: 400

        // ---------- общий системный ----------
        Label { text: I18n.tr("mixer.output"); color: Theme.accent; font.pixelSize: Theme.fontSize - 2 }
        VolumeRow { node: root.sink }
        DevicePicker {
            nodes: root.sinks
            current: root.sink
            onPicked: n => Pipewire.preferredDefaultAudioSink = n
        }

        Label { text: I18n.tr("mixer.input"); color: Theme.accent; font.pixelSize: Theme.fontSize - 2 }
        VolumeRow { node: root.source; glyph: ""; mutedGlyph: "" }
        DevicePicker {
            nodes: root.sources
            current: root.source
            onPicked: n => Pipewire.preferredDefaultAudioSource = n
        }

        // ---------- приложения ----------
        Label {
            visible: root.streams.length > 0
            text: I18n.tr("mixer.apps")
            color: Theme.accent
            font.pixelSize: Theme.fontSize - 2
        }
        ListView {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 260)
            visible: root.streams.length > 0
            clip: true
            spacing: Theme.gap
            boundsBehavior: Flickable.StopAtBounds
            model: root.streams
            delegate: VolumeRow {
                required property var modelData
                width: ListView.view.width
                node: modelData
                title: modelData.properties["application.name"] ?? modelData.name
                subtitle: modelData.properties["media.name"] ?? ""
                iconSource: root.appIcon(modelData)
            }
        }
    }
}
