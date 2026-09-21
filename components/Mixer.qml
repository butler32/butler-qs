import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import "../theme"

Panel {
    id: root
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink?.audio ?? null
    readonly property real volume: audio?.volume ?? 0
    readonly property bool muted: audio?.muted ?? true

    PwObjectTracker { objects: [root.sink] }

    function setVolume(v) {
        if (!audio) return
        audio.muted = false
        audio.volume = Math.max(0, Math.min(1, v))
    }

    Label {
        text: root.muted ? "" : root.volume < 0.34 ? "" : ""
        color: root.muted ? Theme.danger : Theme.accent
        Layout.preferredWidth: Theme.fontSize * 1.2
        horizontalAlignment: Text.AlignHCenter
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: if (root.audio) root.audio.muted = !root.audio.muted
        }
    }

    // Слайдер
    Rectangle {
        id: track
        Layout.preferredWidth: 80
        Layout.preferredHeight: Theme.trackHeight
        radius: Theme.radiusTrack
        color: Theme.surfaceAlt

        Rectangle {
            width: parent.width * (root.muted ? 0 : Math.min(1, root.volume))
            height: parent.height
            radius: parent.radius
            color: Theme.accent
            Behavior on width { NumberAnimation { duration: 80 } }
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            function apply(mx) { root.setVolume((mx - anchors.margins * -1) / track.width) }
            onPressed: m => apply(m.x)
            onPositionChanged: m => { if (pressed) apply(m.x) }
        }
    }

    Label {
        text: Math.round(root.volume * 100) + "%"
        Layout.preferredWidth: Theme.fontSize * 3
        horizontalAlignment: Text.AlignRight
    }

    // Колесо мыши над всей панелью
    overlay: MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: w => root.setVolume(root.volume + (w.angleDelta.y > 0 ? 0.05 : -0.05))
    }
}
