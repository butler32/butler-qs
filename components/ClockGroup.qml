import QtQuick
import QtQuick.Layouts
import Quickshell
import "../theme"
import "../i18n"
import "../config"
import "../services"

// Часы по центру + скрытая панель кнопок справа от них: появляется при наведении на часы,
// пока мышь над панелью или открыт её попап.
//   колокольчик — не беспокоить (клик) и история уведомлений (правый клик);
//   луна — ночной режим (клик; колесо — температура), только если есть hyprsunset;
//   камера — скриншот: область / экран / окно.
// Какие кнопки показывать — Меню → Конфигурация → Часы.
Item {
    id: root
    // Qt Quick не доставляет наведение детям за границами родителя, поэтому Item
    // резервирует место под панель и слева, и справа — часы остаются по центру бара
    implicitWidth: clock.implicitWidth + 2 * (tools.implicitWidth + Theme.gap)
    implicitHeight: clock.implicitHeight

    readonly property var c: Config.clock
    readonly property bool hasTools: c.toolDnd || (c.toolNight && NightLight.available) || c.toolScreenshot
    property bool revealed: false
    // наведение считаем по кнопкам: между ними промежутки перекрывает hideTimer
    readonly property bool toolsHovered: dndBtn.hovered || nightBtn.hovered || shotBtn.hovered
    readonly property bool over: clockHover.hovered || toolsHovered
                                 || historyPopup.open || shotPopup.open

    onOverChanged: {
        if (over) { hideTimer.stop(); revealed = hasTools }
        else hideTimer.restart()
    }
    Timer { id: hideTimer; interval: 350; onTriggered: root.revealed = false }

    Item {
        x: (root.width - width) / 2
        width: clock.implicitWidth
        height: clock.implicitHeight
        Clock { id: clock }
        HoverHandler { id: clockHover }
    }

    Panel {
        id: tools
        x: (root.width + clock.implicitWidth) / 2 + Theme.gap + (root.revealed ? 0 : -Theme.gap)
        opacity: root.revealed ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 150 } }
        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        ToolButton {
            id: dndBtn
            visible: root.c.toolDnd
            glyph: Config.notifications.dnd ? "" : ""
            active: Config.notifications.dnd
            badge: Notifs.missed
            onClicked: mouse => mouse.button === Qt.RightButton ? historyPopup.toggle() : Notifs.toggleDnd()
        }
        ToolButton {
            id: nightBtn
            visible: root.c.toolNight && NightLight.available
            glyph: ""
            active: NightLight.active
            onClicked: NightLight.toggle()
            // колесо — температура: вниз теплее
            onWheeled: delta => {
                const t = Config.night.temperature + (delta > 0 ? 250 : -250)
                Config.night.temperature = Math.max(1500, Math.min(6500, t))
            }
        }
        ToolButton {
            id: shotBtn
            visible: root.c.toolScreenshot
            glyph: ""
            active: shotPopup.open
            onClicked: shotPopup.toggle()
        }
    }

    BarPopup {
        id: historyPopup
        anchorItem: dndBtn
        align: "center"
        ipcName: "notifhistory"
        screen: root.QsWindow.window?.screen ?? null
        minWidth: 380
        onOpenChanged: if (open) Notifs.missed = 0

        RowLayout {
            Layout.fillWidth: true
            Label { text: I18n.tr("notif.history"); font.bold: true; Layout.fillWidth: true }
            Chip {
                icon: Config.notifications.dnd ? "" : ""
                text: I18n.tr("notif.dnd")
                accent: Config.notifications.dnd
                onClicked: Notifs.toggleDnd()
            }
            Chip {
                icon: ""
                text: I18n.tr("notif.clear")
                enabled: Notifs.history.length > 0
                onClicked: Notifs.clearHistory()
            }
        }
        Label {
            visible: Notifs.history.length === 0
            text: I18n.tr("notif.empty")
            color: Theme.textDim
        }
        ListView {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 380)
            visible: Notifs.history.length > 0
            clip: true
            spacing: Theme.gap / 2
            boundsBehavior: Flickable.StopAtBounds
            model: Notifs.history

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                width: ListView.view.width
                implicitHeight: col.implicitHeight + Theme.padding
                height: implicitHeight
                radius: Theme.radiusItem
                color: Theme.surfaceAlt

                ColumnLayout {
                    id: col
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                    anchors.margins: Theme.padding / 2
                    spacing: 0
                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            text: row.modelData.appName
                            color: row.modelData.critical ? Theme.danger : Theme.accent
                            font.pixelSize: Theme.fontSize - 2
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Label {
                            text: Qt.formatDateTime(new Date(row.modelData.time), "HH:mm")
                            color: Theme.textDim
                            font.pixelSize: Theme.fontSize - 2
                        }
                    }
                    Label {
                        Layout.fillWidth: true
                        text: row.modelData.summary
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Label {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: row.modelData.body.replace(/<[^>]*>/g, "")
                        color: Theme.textDim
                        font.pixelSize: Theme.fontSize - 1
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    onClicked: Notifs.removeFromHistory(row.index)
                }
            }
        }
    }

    BarPopup {
        id: shotPopup
        anchorItem: shotBtn
        align: "center"
        ipcName: "screenshot"
        screen: root.QsWindow.window?.screen ?? null
        minWidth: 0

        RowLayout {
            Layout.fillWidth: true
            Chip { icon: ""; text: I18n.tr("shot.area"); onClicked: { shotPopup.close(); Screenshot.take("area") } }
            Chip { icon: ""; text: I18n.tr("shot.screen"); onClicked: { shotPopup.close(); Screenshot.take("screen") } }
            Chip { icon: ""; text: I18n.tr("shot.window"); onClicked: { shotPopup.close(); Screenshot.take("window") } }
        }
    }
}
