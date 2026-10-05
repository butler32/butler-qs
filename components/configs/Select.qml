import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../i18n"
import "../../services"
import ".."

// Поле-список: показывает выбранное значение словами, по клику раскрывает список (DropdownLayer.qml).
// items — [{ value, label, hint?, color? }]; значения сравниваются как строки, чтобы 1 и "1" считались равными.
// Если текущего значения нет в списке (своё значение из конфига), оно добавляется сверху как есть.
Rectangle {
    id: root
    property var items: []
    property var value
    property string placeholder: ""
    property bool searchable: items.length > 8
    property bool onCard: false
    property bool dimmed: false
    signal picked(var value)

    readonly property bool hasValue: value !== undefined && value !== null && String(value) !== ""
    readonly property string key: value === undefined || value === null ? "" : String(value)
    readonly property var allItems: {
        if (!hasValue || items.some(i => String(i.value) === String(value))) return items
        return [{ value: value, label: String(value) }].concat(items)
    }
    readonly property var current: allItems.find(i => String(i.value) === key) ?? null

    implicitWidth: 220
    implicitHeight: 30
    radius: Theme.radiusItem
    color: onCard ? Theme.surface : Theme.surfaceAlt
    border.width: ConfigDropdown.open && ConfigDropdown.anchor === root ? 1 : 0
    border.color: Theme.accent

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 6
        Rectangle {
            visible: !!root.current && root.current.color !== undefined
            Layout.preferredWidth: 14
            Layout.preferredHeight: 14
            radius: 3
            color: root.current && root.current.color !== undefined ? root.current.color : "transparent"
            border.width: 1
            border.color: Theme.border
        }
        Label {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: root.current ? root.current.label : root.hasValue ? String(root.value) : root.placeholder
            color: root.dimmed || !root.hasValue ? Theme.textDim : Theme.text
        }
        Label { text: ""; color: Theme.textDim; font.pixelSize: Theme.fontSize - 3 }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: ConfigDropdown.show(root, root.allItems, root.value, root.searchable, v => root.picked(v))
    }
}
