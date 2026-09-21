import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"
import "../config"
import "../services"

// OSD: значок + шкала + значение, появляется и гаснет (opacity) по событиям из services/Osd.
// Прозрачен для мыши. Настройки — Меню → Конфигурация → OSD.
PanelWindow {
    id: win
    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    color: "transparent"
    anchors { bottom: Config.osd.position === "bottom"; top: Config.osd.position === "top" }
    margins {
        bottom: 40
        top: (Hyprland.monitorFor(screen)?.lastIpcObject?.reserved?.[1] ?? 0) + Theme.gap
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "qs-osd"
    mask: Region {}      // пустая область ввода: клики проходят насквозь

    implicitWidth: Theme.osdWidth
    implicitHeight: box.implicitHeight
    visible: box.opacity > 0

    readonly property var e: Osd.current

    Rectangle {
        id: box
        anchors.fill: parent
        opacity: 0
        implicitHeight: row.implicitHeight + Theme.padding * 2
        color: Theme.surface
        radius: Theme.radiusPopup
        border.width: Theme.borderWidth
        border.color: win.e?.muted ? Theme.danger : Theme.border

        Behavior on opacity { NumberAnimation { id: fade; duration: 180 } }

        RowLayout {
            id: row
            anchors.fill: parent
            anchors.margins: Theme.padding
            spacing: Theme.gap + 2
            Label {
                text: win.e?.glyph ?? ""
                font.pixelSize: Theme.fontSize + 6
                color: win.e?.muted ? Theme.danger : Theme.accent
                Layout.preferredWidth: Theme.fontSize + 8
                horizontalAlignment: Text.AlignHCenter
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.trackHeight + 2
                radius: Theme.radiusTrack
                color: Theme.surfaceAlt
                Rectangle {
                    width: parent.width * (win.e?.fraction ?? 0)
                    height: parent.height
                    radius: parent.radius
                    color: win.e?.muted ? Theme.textDim : Theme.accent
                    Behavior on width { NumberAnimation { duration: 80 } }
                }
            }
            Label {
                text: win.e?.label ?? ""
                Layout.minimumWidth: Theme.fontSize * 3
                horizontalAlignment: Text.AlignRight
            }
        }
    }

    // каждое событие: показать и перезапустить таймер скрытия
    Connections {
        target: Osd
        function onSerialChanged() { box.opacity = 1; hide.restart() }
    }
    Timer { id: hide; interval: Config.osd.timeoutMs; onTriggered: box.opacity = 0 }
}
