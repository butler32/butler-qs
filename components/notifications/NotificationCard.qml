import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import ".."
import "../../theme"
import "../../config"

// Одно уведомление: фон-форма (см. frames/PanelFrame.qml) + иконка приложения,
// имя приложения, заголовок и текст. Сам управляет своим временем жизни.
Item {
    id: card
    required property var modelData   // Notification
    readonly property var n: modelData
    readonly property bool critical: n.urgency === NotificationUrgency.Critical
    readonly property var cfg: Config.notifications
    property bool leaving: false

    readonly property real insetL: frame.item?.insetLeft ?? Theme.padding
    readonly property real insetR: frame.item?.insetRight ?? Theme.padding
    readonly property real insetT: frame.item?.insetTop ?? Theme.padding
    readonly property real insetB: frame.item?.insetBottom ?? Theme.padding

    implicitWidth: Theme.notifWidth
    implicitHeight: content.implicitHeight + insetT + insetB
    opacity: 0

    // Форма выбирается темой: Theme.notifFrame = "panel" → frames/PanelFrame.qml
    Loader {
        id: frame
        anchors.fill: parent
        source: Qt.resolvedUrl("frames/" + Theme.notifFrame.charAt(0).toUpperCase() + Theme.notifFrame.slice(1) + "Frame.qml")
    }
    Binding { target: frame.item; property: "critical"; value: card.critical; when: frame.item !== null }

    // ---------- жизненный цикл ----------

    NumberAnimation { id: fadeIn; target: card; property: "opacity"; to: 1; duration: 150 }
    NumberAnimation {
        id: fadeOut
        target: card; property: "opacity"; to: 0
        duration: card.cfg.fadeMs
        onFinished: card.n.expire()    // → сигнал closed → Notifs.forget → слот освобождается
    }
    Component.onCompleted: fadeIn.start()

    function leave() {
        if (leaving) return
        leaving = true
        fadeIn.stop()
        if (cfg.fadeMs > 0) fadeOut.start()
        else n.expire()
    }

    Timer {
        interval: card.cfg.timeoutSec * 1000
        // на паузе, пока курсор над уведомлением; срочные сами не исчезают
        running: card.cfg.timeoutSec > 0 && !card.critical && !card.leaving && !hover.hovered
        onTriggered: card.leave()
    }
    HoverHandler { id: hover }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            for (const a of card.n.actions) if (a.identifier === "default") { a.invoke(); break }
            card.n.dismiss()
        }
    }

    // ---------- содержимое ----------

    function iconSource() {
        const fromName = s => !s ? "" : s.startsWith("/") ? "file://" + s : s.startsWith("file:") ? s : Quickshell.iconPath(s, true)
        const entry = DesktopEntries.heuristicLookup(n.desktopEntry || n.appName)
        return fromName(n.appIcon) || fromName(entry?.icon)
    }

    RowLayout {
        id: content
        x: card.insetL
        y: card.insetT
        width: card.width - card.insetL - card.insetR
        spacing: Theme.gap + 2

        Item {
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            readonly property string src: card.iconSource()
            Image {
                anchors.fill: parent
                visible: parent.src !== ""
                sourceSize: Qt.size(96, 96)
                source: parent.src
                asynchronous: true
            }
            // нет иконки у приложения — общий значок колокольчика
            Label {
                anchors.centerIn: parent
                visible: parent.src === ""
                text: "\uf0f3"
                color: Theme.accent
                font.pixelSize: 24
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Label {
                Layout.fillWidth: true
                text: card.n.appName
                color: Theme.accent
                font.pixelSize: Theme.fontSize - 2
                elide: Text.ElideRight
            }
            Label {
                Layout.fillWidth: true
                visible: text !== ""
                text: card.n.summary
                font.bold: true
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            Label {
                Layout.fillWidth: true
                visible: text !== ""
                text: card.n.body
                textFormat: Text.StyledText
                color: Theme.textDim
                font.pixelSize: Theme.fontSize - 1
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
            }
        }
    }
}
