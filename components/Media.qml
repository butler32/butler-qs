import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import "../theme"
import "../config"

// Текущий MPRIS-плеер: название, ⏮ ⏯ ⏭. Настройки — Меню → Конфигурация → Медиа.
Panel {
    id: root
    readonly property string pin: Config.media.pinnedApp.toLowerCase()
    function matches(p) {
        return !pin || (p.identity ?? "").toLowerCase().includes(pin)
            || (p.desktopEntry ?? "").toLowerCase().includes(pin)
    }
    readonly property var player: {
        const list = Mpris.players.values.filter(matches)
        return list.find(p => p.isPlaying) ?? list[0] ?? null
    }

    visible: player !== null

    Label { text: ""; color: Theme.accent }
    Label {
        Layout.maximumWidth: 200
        elide: Text.ElideRight
        text: {
            const p = root.player
            if (!p) return ""
            return p.trackArtist ? p.trackArtist + " — " + p.trackTitle : p.trackTitle || p.identity
        }
    }

    component Btn: Label {
        id: btn
        property bool active: true
        signal clicked()
        color: active ? Theme.text : Theme.textDim
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            enabled: btn.active
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    Btn {
        visible: Config.media.showPrevNext
        text: ""
        active: root.player?.canGoPrevious ?? false
        onClicked: root.player.previous()
    }
    Btn {
        text: root.player?.isPlaying ? "" : ""
        color: Theme.accent
        active: root.player?.canTogglePlaying ?? false
        onClicked: root.player.togglePlaying()
    }
    Btn {
        visible: Config.media.showPrevNext
        text: ""
        active: root.player?.canGoNext ?? false
        onClicked: root.player.next()
    }
}
