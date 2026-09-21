import QtQuick
import "../theme"

// Горизонтальный ползунок 0..1: перетаскивание, клик, колесо (шаг 5%).
Item {
    id: root
    property real value: 0
    property bool dimmed: false      // например, для заглушённого звука
    signal moved(real v)

    implicitWidth: 140
    implicitHeight: 24

    function clamp(v) { return Math.max(0, Math.min(1, v)) }

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: Theme.trackHeight
        radius: Theme.radiusTrack
        color: Theme.surfaceAlt
        Rectangle {
            width: parent.width * root.clamp(root.value)
            height: parent.height
            radius: parent.radius
            color: root.dimmed ? Theme.textDim : Theme.accent
            Behavior on width { NumberAnimation { duration: 60 } }
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: m => root.moved(root.clamp(m.x / width))
        onPositionChanged: m => { if (pressed) root.moved(root.clamp(m.x / width)) }
        onWheel: w => root.moved(root.clamp(root.value + (w.angleDelta.y > 0 ? 0.05 : -0.05)))
    }
}
