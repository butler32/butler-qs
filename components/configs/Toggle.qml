import QtQuick
import "../../theme"

// Переключатель true/false для форм редактора конфигов.
Rectangle {
    id: root
    property bool checked: false
    property bool onCard: false
    property bool dimmed: false      // значение не задано в конфиге (действует умолчание)
    signal toggled(bool value)

    implicitHeight: Theme.fontSize + 6
    implicitWidth: implicitHeight * 2
    radius: Math.min(Theme.radiusTrack, height / 2)
    color: checked ? Theme.accent : onCard ? Theme.surface : Theme.surfaceAlt
    border.width: Theme.borderWidth
    border.color: Theme.border
    opacity: (dimmed ? 0.55 : 1) * (enabled ? 1 : 0.5)
    Behavior on color { ColorAnimation { duration: 100 } }

    Rectangle {
        readonly property real d: root.height - 8
        width: d
        height: d
        y: 4
        x: root.checked ? root.width - d - 4 : 4
        radius: Math.min(Theme.radiusTrack, d / 2)
        color: root.checked ? Theme.accentText : Theme.textDim
        Behavior on x { NumberAnimation { duration: 100 } }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
