import QtQuick
import QtQuick.Layouts
import "../theme"

// Базовое «окно» бара: вся форма (скругление, рамка, размеры) берётся из Theme.
Rectangle {
    id: root
    default property alias content: row.data
    property alias spacing: row.spacing
    // Для элементов поверх всей панели (MouseArea и т.п.) — вне Layout
    property alias overlay: overlayItem.data
    // Собственное условие показа виджета (а не `visible`): Bar читает его, чтобы
    // не оставлять в ряду пустое место, и сам управляет видимостью через Loader.
    property bool wanted: true
    visible: wanted

    implicitWidth: row.implicitWidth + Theme.padding * 2
    implicitHeight: Theme.barHeight
    color: Theme.surface
    radius: Theme.radiusPanel
    border.width: Theme.borderWidth
    border.color: Theme.border

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Theme.gap
    }
    Item { id: overlayItem; anchors.fill: parent }
}
