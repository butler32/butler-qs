import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"

// Главное меню (в духе wofi, но с деревом страниц: приложения, тема, питание…).
// Создаётся через LazyLoader, поэтому состояние сбрасывается при каждом открытии.
// Содержимое страниц — в MenuPages.qml.
PanelWindow {
    id: win
    signal close()

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    // OnDemand + grab, а не Exclusive: при Exclusive Hyprland не отдаёт клики другим поверхностям
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "qs-menu"

    implicitWidth: Theme.menuWidth
    implicitHeight: Theme.barHeight + Theme.padding * 3 + Math.max(1, Math.min(results.length, Theme.menuRows)) * Theme.menuItem

    HyprlandFocusGrab {
        windows: [win]
        active: true
        onCleared: win.close()
    }

    // Прозрачный слой на весь экран под меню: клик в любой точке вне меню закрывает его.
    // Область панелей (наша и чужие) не перекрываем — как в BarPopup.
    PanelWindow {
        screen: win.screen
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        margins.top: Hyprland.monitorFor(win.screen)?.lastIpcObject?.reserved?.[1] ?? 0
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "qs-menu-catcher"

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: win.close()
        }
    }

    MenuPages { id: pages }

    property string initialPage: "root"   // для `ipc call menu page <id>`
    property var pageStack: initialPage === "root" ? ["root"] : ["root", initialPage]
    readonly property string pageId: pageStack[pageStack.length - 1]
    readonly property string breadcrumb: pageStack.map(id => pages.title(id)).join("  ›  ")
    property string query: ""

    function score(it, q) {
        const name = it.name.toLowerCase()
        if (name.startsWith(q)) return 4
        if (name.includes(" " + q)) return 3
        if (name.includes(q)) return 2
        const extra = ((it.comment ?? "") + " " + (it.keywords ?? []).join(" ")).toLowerCase()
        return extra.includes(q) ? 1 : 0
    }

    readonly property var results: {
        const items = pages.build(pageId, query)
        const q = query.trim().toLowerCase()
        if (q === "") return items
        return items.map(it => ({ it: it, s: score(it, q) }))
            .filter(x => x.s > 0)
            .sort((a, b) => b.s - a.s)
            .map(x => x.it)
    }

    function goto(id) { pageStack = [...pageStack, id]; input.text = "" }
    function back() {
        if (pageStack.length > 1) { pageStack = pageStack.slice(0, -1); input.text = "" }
        else win.close()
    }
    // Смена настроек пересобирает модель и сбрасывает выбор — возвращаем его на место
    // fn может вернуть число — на сколько строк сдвинулся выбранный пункт (сдвиг порядка)
    function keepSelection(fn) {
        const i = list.currentIndex
        const shift = fn()
        const target = i + (typeof shift === "number" ? shift : 0)
        Qt.callLater(() => list.currentIndex = Math.max(0, Math.min(target, list.count - 1)))
    }
    function activate(it) {
        if (!it) return
        if (it.page) goto(it.page)
        else if (it.backAfter) {
            if (it.run) it.run()
            pageStack = pageStack.slice(0, Math.max(1, pageStack.length - it.backAfter))
            input.text = ""
        } else if (it.keepOpen) {
            keepSelection(() => { if (it.run) it.run() })
        } else {
            if (it.run) it.run()
            win.close()
        }
    }
    function adjust(d) {
        const it = list.model[list.currentIndex]
        if (it?.adjust) { keepSelection(() => it.adjust(d)); return true }
        return false
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.surface
        radius: Theme.radiusPopup
        border.width: Theme.borderWidth
        border.color: Theme.border

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.padding
            spacing: Theme.padding

            // Поле поиска
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.barHeight
                radius: Theme.radiusItem
                color: Theme.surfaceAlt

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.padding
                    anchors.rightMargin: Theme.padding
                    spacing: Math.max(Theme.gap, 8)
                    Label { text: ""; color: Theme.accent }
                    TextInput {
                        id: input
                        Layout.fillWidth: true
                        focus: true
                        color: Theme.text
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.accentText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        clip: true
                        onTextChanged: { win.query = text; list.currentIndex = 0 }

                        Label {
                            visible: !input.text
                            text: win.breadcrumb
                            color: Theme.textDim
                        }

                        Keys.onPressed: e => {
                            const ctrl = e.modifiers & Qt.ControlModifier
                            if (e.key === Qt.Key_Escape) win.close()
                            else if (e.key === Qt.Key_Backspace && input.text === "" && !e.isAutoRepeat) win.back()
                            else if (e.key === Qt.Key_Left && (e.modifiers & Qt.AltModifier)) win.back()
                            else if (e.key === Qt.Key_Left && win.adjust(-1)) {}
                            else if (e.key === Qt.Key_Right && win.adjust(1)) {}
                            else if (e.key === Qt.Key_Down || (ctrl && (e.key === Qt.Key_N || e.key === Qt.Key_J))) list.incrementCurrentIndex()
                            else if (e.key === Qt.Key_Up || (ctrl && (e.key === Qt.Key_P || e.key === Qt.Key_K))) list.decrementCurrentIndex()
                            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) win.activate(list.model[list.currentIndex])
                            else return
                            e.accepted = true
                        }
                    }
                }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: win.results
                currentIndex: 0
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 0

                delegate: Rectangle {
                    id: item
                    required property var modelData
                    required property int index
                    readonly property bool selected: ListView.isCurrentItem

                    width: ListView.view.width
                    height: Theme.menuItem
                    radius: Theme.radiusItem
                    color: selected ? Theme.accent : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.padding
                        anchors.rightMargin: Theme.padding
                        spacing: Math.max(Theme.gap, 8)

                        Item {
                            Layout.preferredWidth: Theme.menuItem * 0.6
                            Layout.preferredHeight: Theme.menuItem * 0.6
                            Image {
                                anchors.fill: parent
                                visible: !!item.modelData.iconSource
                                sourceSize: Qt.size(64, 64)
                                source: item.modelData.iconSource ?? ""
                                asynchronous: true
                            }
                            Label {
                                anchors.centerIn: parent
                                visible: !item.modelData.iconSource
                                text: item.modelData.icon ?? ""
                                font.pixelSize: Theme.fontSize + 3
                                color: item.selected ? Theme.accentText : item.modelData.danger ? Theme.danger : Theme.accent
                            }
                        }
                        Label {
                            text: item.modelData.name
                            color: item.selected ? Theme.accentText : Theme.text
                            elide: Text.ElideRight
                            Layout.maximumWidth: parent.width * 0.6
                        }
                        Label {
                            Layout.fillWidth: true
                            text: item.modelData.comment ?? ""
                            color: item.selected ? Theme.accentText : Theme.textDim
                            opacity: 0.8
                            elide: Text.ElideRight
                            font.pixelSize: Theme.fontSize - 2
                        }
                        Label {
                            visible: !!item.modelData.value
                            text: (item.modelData.adjust ? "‹ " : "") + (item.modelData.value ?? "") + (item.modelData.adjust ? " ›" : "")
                            color: item.selected ? Theme.accentText : Theme.accent
                        }
                        Label {
                            visible: !!item.modelData.page || !!item.modelData.active
                            text: item.modelData.page ? "\uf054" : "\uf00c"
                            color: item.selected ? Theme.accentText : Theme.textDim
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onPositionChanged: list.currentIndex = item.index
                        onClicked: { list.currentIndex = item.index; win.activate(item.modelData) }
                    }
                }
            }
        }
    }
}
