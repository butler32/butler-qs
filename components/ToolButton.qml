import QtQuick
import "../theme"

// Значок-кнопка для панели инструментов у часов: глиф, подсветка «включено»,
// счётчик-бейдж. Левый и правый клик различаются по `mouse.button`.
Item {
    id: root
    property string glyph
    property bool active: false
    property int badge: 0
    readonly property bool hovered: area.containsMouse
    signal clicked(var mouse)
    signal wheeled(int delta)

    implicitWidth: Theme.barHeight * 0.7
    implicitHeight: Theme.barHeight * 0.7

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusItem
        color: area.containsMouse ? Theme.surfaceAlt : "transparent"
        Behavior on color { ColorAnimation { duration: 100 } }
    }
    Label {
        anchors.centerIn: parent
        text: root.glyph
        color: root.active ? Theme.accent : Theme.text
    }
    Rectangle {
        visible: root.badge > 0
        anchors { top: parent.top; right: parent.right; topMargin: -2; rightMargin: -2 }
        width: Math.max(height, badgeText.implicitWidth + 6)
        height: badgeText.implicitHeight
        radius: height / 2
        color: Theme.notify
        Label {
            id: badgeText
            anchors.centerIn: parent
            text: root.badge > 99 ? "99+" : root.badge
            color: Theme.accentText
            font.pixelSize: Theme.fontSize - 4
            font.bold: true
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => root.clicked(mouse)
        onWheel: wheel => root.wheeled(wheel.angleDelta.y)
    }
}
