import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../i18n"
import "../../services"
import ".."

// Слой выпадающих списков поверх всего окна редактора (кладётся последним ребёнком окна).
// Состояние — в services/ConfigDropdown. Клик мимо и Esc закрывают список; в списках длиннее 8 пунктов есть поиск.
Item {
    id: layer
    anchors.fill: parent
    visible: ConfigDropdown.open
    z: 1000

    property string query: ""
    readonly property var shown: {
        const q = query.trim().toLowerCase()
        return q ? ConfigDropdown.items.filter(i => (i.label + " " + (i.hint ?? "")).toLowerCase().indexOf(q) >= 0) : ConfigDropdown.items
    }
    property real px: 0
    property real py: 0

    function place() {
        const a = ConfigDropdown.anchor
        if (!a) return
        const pt = a.mapToItem(layer, 0, 0)
        panel.width = Math.max(a.width, 280)
        px = Math.max(8, Math.min(pt.x, layer.width - panel.width - 8))
        py = pt.y + a.height + 4
        if (py + panel.height > layer.height - 8) py = Math.max(8, pt.y - panel.height - 4)
    }

    Connections {
        target: ConfigDropdown
        function onOpenChanged() {
            if (!ConfigDropdown.open) return
            layer.query = ""
            search.text = ""
            layer.place()
            if (ConfigDropdown.searchable) search.input.forceActiveFocus()
            else layer.forceActiveFocus()
            list.positionViewAtIndex(Math.max(0, ConfigDropdown.items.findIndex(i => String(i.value) === String(ConfigDropdown.current))), ListView.Center)
        }
    }

    Keys.onEscapePressed: ConfigDropdown.hide()

    MouseArea {
        anchors.fill: parent
        onClicked: ConfigDropdown.hide()
        onWheel: w => w.accepted = true
    }

    Rectangle {
        id: panel
        x: layer.px
        y: layer.py
        height: col.implicitHeight + Theme.padding
        radius: Theme.radiusPopup
        color: Theme.surface
        border.width: Theme.borderWidth
        border.color: Theme.border

        ColumnLayout {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.padding / 2
            spacing: 4

            Field {
                id: search
                Layout.fillWidth: true
                visible: ConfigDropdown.searchable
                placeholder: I18n.tr("cfged.search")
                onTextChanged: layer.query = text
                onAccepted: if (layer.shown.length) ConfigDropdown.pick(layer.shown[0].value)
            }
            ListView {
                id: list
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 300)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: layer.shown
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    readonly property bool selected: String(modelData.value) === String(ConfigDropdown.current)
                    width: ListView.view.width
                    height: Math.max(30, rowCol.implicitHeight + 8)
                    radius: Theme.radiusItem
                    color: selected ? Theme.accent : (area.containsMouse ? Theme.surfaceAlt : "transparent")
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8
                        Rectangle {
                            visible: row.modelData.color !== undefined
                            Layout.preferredWidth: 16
                            Layout.preferredHeight: 16
                            radius: 3
                            color: row.modelData.color !== undefined ? row.modelData.color : "transparent"
                            border.width: 1
                            border.color: Theme.border
                        }
                        ColumnLayout {
                            id: rowCol
                            Layout.fillWidth: true
                            spacing: 0
                            Label {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                text: row.modelData.label
                                color: row.selected ? Theme.accentText : Theme.text
                            }
                            Label {
                                Layout.fillWidth: true
                                visible: !!row.modelData.hint
                                elide: Text.ElideRight
                                text: row.modelData.hint ?? ""
                                color: row.selected ? Theme.accentText : Theme.textDim
                                font.pixelSize: Theme.fontSize - 2
                            }
                        }
                    }
                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ConfigDropdown.pick(row.modelData.value)
                    }
                }
            }
            Label {
                visible: layer.shown.length === 0
                text: I18n.tr("cfged.empty")
                color: Theme.textDim
            }
        }
    }
}
