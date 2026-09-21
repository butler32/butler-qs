import QtQuick
import QtQuick.Layouts
import "../theme"
import "../i18n"

// Выбор устройства: строка с текущим, по клику раскрывается список.
ColumnLayout {
    id: root
    property var nodes: []          // PwNode[]
    property var current            // PwNode
    signal picked(var node)
    property bool expanded: false

    function label(n) { return n ? (n.nickname || n.description || n.name) : I18n.tr("mixer.nodevice") }

    Layout.fillWidth: true
    spacing: 2

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 30
        radius: Theme.radiusItem
        color: head.containsMouse ? Theme.surfaceAlt : "transparent"
        border.width: Theme.borderWidth
        border.color: Theme.border
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.padding
            anchors.rightMargin: Theme.padding
            Label { Layout.fillWidth: true; text: root.label(root.current); elide: Text.ElideRight }
            Label { text: root.expanded ? "" : ""; color: Theme.textDim; font.pixelSize: Theme.fontSize - 3 }
        }
        MouseArea {
            id: head
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }

    Repeater {
        model: root.expanded ? root.nodes : []
        delegate: Rectangle {
            id: item
            required property var modelData
            readonly property bool isCurrent: modelData === root.current
            Layout.fillWidth: true
            implicitHeight: 28
            radius: Theme.radiusItem
            color: area.containsMouse ? Theme.surfaceAlt : "transparent"
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.padding
                anchors.rightMargin: Theme.padding
                Label { Layout.fillWidth: true; text: root.label(item.modelData); elide: Text.ElideRight
                        color: item.isCurrent ? Theme.accent : Theme.text }
                Label { visible: item.isCurrent; text: ""; color: Theme.accent }
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.picked(item.modelData); root.expanded = false }
            }
        }
    }
}
