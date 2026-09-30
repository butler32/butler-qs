import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import "../theme"
import "../i18n"

// Выбор профиля питания (нужен power-profiles-daemon): подпись + три кнопки.
ColumnLayout {
    spacing: Theme.gap

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
