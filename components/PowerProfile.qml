import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "../theme"
import "../i18n"

// Профиль питания в баре (нужен power-profiles-daemon): значок текущего профиля,
// клик открывает выбор. Без демона виджет скрыт. Работает и на ПК без батареи —
// в отличие от выбора профиля в попапе Battery.
Panel {
    id: root
    property bool available: false
    wanted: available

    readonly property int profile: PowerProfiles.profile
    readonly property var glyphs: ({
        [PowerProfile.PowerSaver]: "",
        [PowerProfile.Balanced]: "",
        [PowerProfile.Performance]: ""
    })
    readonly property color tint: profile === PowerProfile.Performance ? Theme.warn
                                : profile === PowerProfile.PowerSaver ? Theme.accent : Theme.text

    Process {
        command: ["sh", "-c", "command -v powerprofilesctl"]
        running: true
        onExited: code => root.available = code === 0
    }

    Label { text: root.glyphs[root.profile] ?? ""; color: root.tint }

    overlay: MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: popup.toggle()
    }

    BarPopup {
        id: popup
        anchorItem: root
        ipcName: "power"
        screen: root.QsWindow.window?.screen ?? null
        minWidth: 280

        PowerProfileChooser { Layout.fillWidth: true }
    }
}
