import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../i18n"
import ".."

// Карточка записи: заголовок (клик сворачивает), краткое описание, кнопка удаления и содержимое.
Rectangle {
    id: card
    property string title: ""
    property string summary: ""
    property string badge: ""
    property bool expanded: false
    property bool expandable: true
    property bool deletable: true
    property bool dimTitle: false
    signal removed()
    default property alias content: body.data
    property alias headerExtra: extra.data

    implicitHeight: col.implicitHeight + Theme.padding
    radius: Theme.radiusItem
    color: Theme.surfaceAlt

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.padding / 2
        spacing: Theme.gap

        RowLayout {
            Layout.fillWidth: true
            Layout.minimumHeight: 28
            spacing: Theme.gap
            Label {
                visible: card.expandable
                text: card.expanded ? "" : ""
                color: Theme.textDim
                font.pixelSize: Theme.fontSize - 2
            }
            Label {
                text: card.title
                font.bold: true
                color: card.dimTitle ? Theme.textDim : Theme.text
            }
            Label {
                visible: card.badge !== ""
                text: card.badge
                color: Theme.textDim
                font.pixelSize: Theme.fontSize - 2
            }
            Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: card.summary
                color: Theme.textDim
                font.pixelSize: Theme.fontSize - 1
            }
            RowLayout { id: extra; spacing: Theme.gap }
            Chip {
                visible: card.deletable
                icon: ""
                danger: true
                onClicked: card.removed()
            }
            TapHandler { enabled: card.expandable; onTapped: card.expanded = !card.expanded }
        }

        ColumnLayout {
            id: body
            Layout.fillWidth: true
            visible: card.expanded || !card.expandable
            spacing: Theme.gap * 1.5
        }
    }
}
