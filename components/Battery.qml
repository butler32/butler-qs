import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import "../theme"
import "../i18n"

// Заряд батареи (виджет скрыт, если батареи нет). Клик — подробности и профиль питания
// (нужен power-profiles-daemon).
Panel {
    id: root
    readonly property var dev: UPower.displayDevice
    readonly property bool present: dev.ready && dev.isPresent
    // Quickshell отдаёт долю 0..1; на случай процентов 0..100 нормализуем
    readonly property real pct: Math.round(dev.percentage <= 1.0 ? dev.percentage * 100 : dev.percentage)
    readonly property bool charging: dev.state === UPowerDeviceState.Charging
    readonly property bool full: dev.state === UPowerDeviceState.FullyCharged
    readonly property color tint: charging || full ? Theme.accent : pct <= 15 ? Theme.danger : pct <= 30 ? Theme.warn : Theme.text

    visible: present

    function glyph() { return pct > 87 ? "" : pct > 62 ? "" : pct > 37 ? "" : pct > 12 ? "" : "" }
    function hm(sec) {
        if (!sec || sec <= 0) return ""
        const h = Math.floor(sec / 3600), m = Math.round(sec % 3600 / 60)
        return h > 0 ? h + I18n.tr("unit.h") + " " + m + I18n.tr("unit.min") : m + I18n.tr("unit.min")
    }
    function stateText() {
        if (charging) return I18n.tr("bat.charging")
        if (full) return I18n.tr("bat.full")
        if (dev.state === UPowerDeviceState.Discharging) return I18n.tr("bat.discharging")
        return I18n.tr("bat.idle")
    }

    Label { text: root.charging ? "" : ""; visible: root.charging; color: root.tint }
    Label { text: root.glyph(); color: root.tint }
    Label { text: root.pct + "%"; color: root.tint }

    overlay: MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: popup.toggle()
    }

    BarPopup {
        id: popup
        anchorItem: root
        ipcName: "battery"
        screen: root.QsWindow.window?.screen ?? null
        minWidth: 280

        RowLayout {
            Layout.fillWidth: true
            Label { text: root.pct + "%"; font.pixelSize: Theme.fontSize + 9; font.bold: true; color: root.tint }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Label { text: root.stateText(); font.bold: true }
                Label {
                    readonly property string t: root.hm(root.charging ? root.dev.timeToFull : root.dev.timeToEmpty)
                    visible: t !== ""
                    text: (root.charging ? I18n.tr("bat.tofull") : I18n.tr("bat.toempty")) + " " + t
                    color: Theme.textDim
                    font.pixelSize: Theme.fontSize - 1
                }
            }
        }
        // шкала заряда
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.trackHeight
            radius: Theme.radiusTrack
            color: Theme.surfaceAlt
            Rectangle {
                width: parent.width * root.pct / 100
                height: parent.height
                radius: parent.radius
                color: root.tint
            }
        }
        Label {
            visible: root.dev.changeRate !== 0
            text: I18n.tr("bat.rate") + ": " + Math.abs(root.dev.changeRate).toFixed(1) + " " + I18n.tr("unit.w")
            color: Theme.textDim
            font.pixelSize: Theme.fontSize - 1
        }
        Label {
            visible: root.dev.healthSupported
            text: I18n.tr("bat.health") + ": " + Math.round(root.dev.healthPercentage) + "%"
            color: Theme.textDim
            font.pixelSize: Theme.fontSize - 1
        }

        Label { text: I18n.tr("bat.profile"); color: Theme.accent; font.pixelSize: Theme.fontSize - 2 }
        RowLayout {
            Layout.fillWidth: true
            Chip {
                Layout.fillWidth: true
                icon: ""; text: I18n.tr("bat.saver")
                accent: PowerProfiles.profile === PowerProfile.PowerSaver
                onClicked: PowerProfiles.profile = PowerProfile.PowerSaver
            }
            Chip {
                Layout.fillWidth: true
                icon: ""; text: I18n.tr("bat.balanced")
                accent: PowerProfiles.profile === PowerProfile.Balanced
                onClicked: PowerProfiles.profile = PowerProfile.Balanced
            }
            Chip {
                Layout.fillWidth: true
                visible: PowerProfiles.hasPerformanceProfile
                icon: ""; text: I18n.tr("bat.performance")
                accent: PowerProfiles.profile === PowerProfile.Performance
                onClicked: PowerProfiles.profile = PowerProfile.Performance
            }
        }
    }
}
