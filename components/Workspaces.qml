import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "../theme"

Panel {
    id: root
    readonly property int minCount: 5
    readonly property int count: {
        let m = minCount
        for (const w of Hyprland.workspaces.values) m = Math.max(m, w.id)
        return m
    }
    readonly property int focusedId: Hyprland.focusedWorkspace?.id ?? -1

    Repeater {
        model: root.count
        delegate: Rectangle {
            id: dot
            required property int index
            readonly property int wsId: index + 1
            readonly property bool active: root.focusedId === wsId
            readonly property bool exists: Hyprland.workspaces.values.some(w => w.id === wsId)

            Layout.preferredWidth: active ? Theme.workspaceDot * 2.4 : Theme.workspaceDot
            Layout.preferredHeight: Theme.workspaceDot
            radius: Math.min(Theme.radiusItem, height / 2)
            color: active ? Theme.accent : exists ? Theme.text : Theme.surfaceAlt
            opacity: active || exists ? 1 : 0.7
            Behavior on Layout.preferredWidth { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 150 } }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -Theme.gap / 2
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + dot.wsId + " })")
            }
        }
    }
}
