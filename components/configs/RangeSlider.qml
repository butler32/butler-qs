import QtQuick
import "../../theme"

// Ползунок 0..1 для форм: перетаскивание и клик. Колесо не перехватывает — страница прокручивается над ним.
Item {
    id: root
    property real value: 0
    property bool dimmed: false
    signal moved(real t)

    implicitWidth: 160
    implicitHeight: Theme.fontSize + 8

    function clamp(v) { return Math.max(0, Math.min(1, v)) }

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: Math.max(4, Theme.trackHeight)
        radius: Theme.radiusTrack
        color: Theme.surfaceAlt
        border.width: Theme.borderWidth
        border.color: Theme.border
        Rectangle {
            width: parent.width * root.clamp(root.value)
            height: parent.height
            radius: parent.radius
            color: root.dimmed ? Theme.textDim : Theme.accent
        }
    }
    Rectangle {
        readonly property real d: root.height - 6
        width: d
        height: d
        radius: Math.min(Theme.radiusTrack, d / 2)
        y: (root.height - d) / 2
        x: (root.width - d) * root.clamp(root.value)
        color: root.dimmed ? Theme.textDim : Theme.accent
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: m => root.moved(root.clamp(m.x / width))
        onPositionChanged: m => { if (pressed) root.moved(root.clamp(m.x / width)) }
    }
}
