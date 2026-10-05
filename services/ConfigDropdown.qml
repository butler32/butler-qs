pragma Singleton
import QtQuick
import Quickshell

// Состояние единственного выпадающего списка окна редактора конфигов. Select.qml вызывает show(),
// components/configs/DropdownLayer.qml рисует его поверх окна (QtQuick.Controls.Popup в окне Quickshell
// не имеет Overlay, поэтому список — обычный Item). Элементы: { value, label, hint?, color?, group? }.
Singleton {
    id: root

    property bool open: false
    property Item anchor: null
    property var items: []
    property var current: undefined
    property bool searchable: false
    property var callback: null

    function show(anchorItem, list, cur, search, cb) {
        anchor = anchorItem
        items = list
        current = cur
        searchable = search
        callback = cb
        open = true
    }
    function pick(value) {
        const cb = callback
        hide()
        if (cb) cb(value)
    }
    function hide() {
        open = false
        callback = null
        anchor = null
    }
}
