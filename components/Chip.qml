import QtQuick
import QtQuick.Layouts
import "../theme"

// Маленькая кнопка (глиф и/или текст) в стиле темы.
Rectangle {
    id: root
    property string text
    property string icon
    property bool accent: false     // залитая акцентным цветом
    property bool danger: false
    signal clicked()

    implicitWidth: row.implicitWidth + Theme.padding
    implicitHeight: 26
    radius: Theme.radiusItem
    color: accent ? Theme.accent : area.containsMouse ? Theme.surfaceAlt : "transparent"
    border.width: accent ? 0 : Theme.borderWidth
    border.color: Theme.border
    opacity: enabled ? 1 : 0.5
    Behavior on color { ColorAnimation { duration: 100 } }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Label {
            visible: root.icon !== ""
            text: root.icon
            color: root.accent ? Theme.accentText : root.danger ? Theme.danger : Theme.accent
        }
        Label {
            visible: root.text !== ""
            text: root.text
            font.pixelSize: Theme.fontSize - 1
            color: root.accent ? Theme.accentText : Theme.text
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
