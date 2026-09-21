import QtQuick
import QtQuick.Layouts
import Quickshell
import "../theme"

// Регулятор громкости одного узла PipeWire: [mute] ━━━━ 53%.
// Если задан title — сверху показывается иконка и название (для приложений).
ColumnLayout {
    id: root
    property var node                 // PwNode
    property string glyph: ""   // иконка кнопки mute (когда звук включён)
    property string mutedGlyph: ""
    property string title
    property string subtitle
    property url iconSource

    readonly property var audio: node?.audio ?? null
    readonly property real volume: audio?.volume ?? 0
    readonly property bool muted: audio?.muted ?? false

    Layout.fillWidth: true
    spacing: 2

    RowLayout {
        Layout.fillWidth: true
        visible: root.title !== ""
        spacing: Theme.gap
        Item {
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            Image {
                anchors.fill: parent
                visible: root.iconSource != ""
                source: root.iconSource
                sourceSize: Qt.size(40, 40)
                asynchronous: true
            }
            Label { anchors.centerIn: parent; visible: root.iconSource == ""; text: ""; color: Theme.accent }
        }
        Label { text: root.title; font.bold: true; elide: Text.ElideRight; Layout.maximumWidth: 150 }
        Label {
            Layout.fillWidth: true
            text: root.subtitle
            color: Theme.textDim
            font.pixelSize: Theme.fontSize - 2
            elide: Text.ElideRight
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.gap
        Chip {
            icon: root.muted ? root.mutedGlyph : root.glyph
            danger: root.muted
            enabled: root.audio !== null
            onClicked: root.audio.muted = !root.audio.muted
        }
        Slider {
            Layout.fillWidth: true
            value: root.volume
            dimmed: root.muted
            enabled: root.audio !== null
            onMoved: v => { root.audio.muted = false; root.audio.volume = v }
        }
        Label {
            Layout.preferredWidth: Theme.fontSize * 3
            horizontalAlignment: Text.AlignRight
            text: Math.round(root.volume * 100) + "%"
            color: root.muted ? Theme.textDim : Theme.text
        }
    }
}
