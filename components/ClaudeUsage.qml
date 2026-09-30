import QtQuick
import QtQuick.Layouts
import Quickshell
import "../theme"
import "../i18n"
import "../config"
import "../services"

// Кнопка Claude Code в баре — только иконка, без цифр; клик открывает попап с
// процентами подписки (5ч-сессия и неделя, ClaudeUsage.session/.week: {used, resets} | null).
// Цвет иконки — предупреждение, если хоть одна метрика пересекла порог
// (Config.claudeUsage.<session|week>, тот же механизм mode+пороги, что у SysMon:
// пороги — от used%, симметрично CPU/RAM).
Panel {
    id: root
    wanted: Config.claudeUsage.enabled
    readonly property var ids: ["session", "week"]

    function data(id) { return id === "session" ? ClaudeUsage.session : ClaudeUsage.week }
    // -1 нет данных, 0 норма, 1 жёлтый, 2 красный
    function level(id) {
        const d = data(id)
        if (!d) return -1
        const c = Config.claudeUsage[id]
        return d.used >= c.red ? 2 : d.used >= c.yellow ? 1 : 0
    }
    function flagged(id) {
        const l = level(id)
        if (l < 0) return false
        const m = Config.claudeUsage[id].mode
        return m === "always" || (m === "yellow" && l >= 1) || (m === "red" && l >= 2)
    }
    readonly property int worst: Math.max(...root.ids.map(id => flagged(id) ? level(id) : -1))
    function tint(l) { return l >= 2 ? Theme.danger : l === 1 ? Theme.warn : Theme.text }

    Label { text: ""; color: root.worst >= 0 ? root.tint(root.worst) : Theme.text }

    overlay: MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: popup.toggle()
    }

    BarPopup {
        id: popup
        anchorItem: root
        ipcName: "claudeusage"
        screen: root.QsWindow.window?.screen ?? null
        minWidth: 260

        RowLayout {
            Layout.fillWidth: true
            Label { text: ""; font.pixelSize: Theme.fontSize + 7; color: Theme.accent }
            Label { text: I18n.tr("cfg.claude"); font.bold: true; font.pixelSize: Theme.fontSize + 2 }
        }

        Repeater {
            model: root.ids
            delegate: ColumnLayout {
                id: row
                required property string modelData
                readonly property var d: root.data(modelData)
                Layout.fillWidth: true
                visible: d !== null
                spacing: 2
                RowLayout {
                    Layout.fillWidth: true
                    Label { text: I18n.tr("claude." + row.modelData + ".title"); Layout.fillWidth: true }
                    Label {
                        text: (row.d ? row.d.used : 0) + "% " + I18n.tr("claude.used")
                        color: Theme.textDim
                        font.pixelSize: Theme.fontSize - 1
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.trackHeight
                    radius: Theme.radiusTrack
                    color: Theme.surfaceAlt
                    Rectangle {
                        width: parent.width * (row.d ? row.d.used : 0) / 100
                        height: parent.height
                        radius: parent.radius
                        color: root.tint(root.level(row.modelData))
                    }
                }
                Label {
                    visible: row.d !== null
                    text: I18n.tr("claude.resets") + ": " + (row.d ? row.d.resets : "")
                    color: Theme.textDim
                    font.pixelSize: Theme.fontSize - 2
                }
            }
        }

        Label {
            visible: !ClaudeUsage.session && !ClaudeUsage.week
            text: I18n.tr("claude.unavailable")
            color: Theme.textDim
            font.pixelSize: Theme.fontSize - 1
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}
