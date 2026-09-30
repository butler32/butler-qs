import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import "../theme"
import "../config"
import "../services"

// Текущий MPRIS-плеер: название, ⏮ ⏯ ⏭. Клик по тексту — перейти к окну плеера.
// Настройки — Меню → Конфигурация → Медиа.
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

    wanted: Config.media.enabled && player !== null
    spacing: Theme.gap + 2

    // Переход к источнику звука. Для браузеров окон может быть несколько —
    // берём то, в заголовке которого есть название трека.
    function focusSource() {
        const p = player
        if (!p) return
        const wins = Windows.matching([p.desktopEntry, p.identity])
        if (wins.length === 0) { if (p.canRaise) p.raise(); return }
        const title = (p.trackTitle ?? "").toLowerCase()
        Windows.focus(wins.find(t => title !== "" && (t.title ?? "").toLowerCase().includes(title)) ?? wins[0])
    }

    // иконка + название: вся область кликабельна
    Item {
        implicitWidth: info.implicitWidth
        implicitHeight: info.implicitHeight
        RowLayout {
            id: info
            anchors.fill: parent
            spacing: Theme.gap
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
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -2
            cursorShape: Qt.PointingHandCursor
            onClicked: root.focusSource()
        }
    }

    // Крупные кнопки с зазором, чтобы не промахиваться
    component Btn: Rectangle {
        id: btn
        property string glyph
        property bool active: true
        property bool accent: false
        signal clicked()
        implicitWidth: 30
        implicitHeight: 28
        radius: Theme.radiusItem
        color: area.containsMouse && active ? Theme.surfaceAlt : "transparent"
        opacity: active ? 1 : 0.4
        Behavior on color { ColorAnimation { duration: 100 } }
        Label {
            anchors.centerIn: parent
            text: btn.glyph
            font.pixelSize: Theme.fontSize + 2
            color: btn.accent ? Theme.accent : Theme.text
        }
        MouseArea {
            id: area
            anchors.fill: parent
            enabled: btn.active
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    RowLayout {
        spacing: 6
        Btn {
            visible: Config.media.showPrevNext
            glyph: ""
            active: root.player?.canGoPrevious ?? false
            onClicked: root.player.previous()
        }
        Btn {
            glyph: root.player?.isPlaying ? "" : ""
            accent: true
            active: root.player?.canTogglePlaying ?? false
            onClicked: root.player.togglePlaying()
        }
        Btn {
            visible: Config.media.showPrevNext
            glyph: ""
            active: root.player?.canGoNext ?? false
            onClicked: root.player.next()
        }
    }
}
