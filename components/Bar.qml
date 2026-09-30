import QtQuick
import QtQuick.Layouts
import Quickshell
import "../theme"
import "../config"

// Виджеты и их порядок задаются в Config.bar (Меню → Конфигурация → Виджеты бара);
// часы по центру и кнопка меню справа — всегда на месте.
PanelWindow {
    id: bar
    signal menuRequested()
    readonly property string screenName: screen?.name ?? ""
    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.barHeight + Theme.barMargin * 2
    color: Theme.bg

    readonly property var widgets: ({
        workspaces: workspaces, apps: apps, media: media, sysmon: sysmon, claude: claude,
        tray: tray, network: network, bluetooth: bluetooth, battery: battery,
        power: power, language: language, mixer: mixer
    })
    Component { id: workspaces; Workspaces {} }
    Component { id: apps; AppDock {} }
    Component { id: media; Media {} }
    Component { id: sysmon; SysMon {} }
    Component { id: claude; ClaudeUsage {} }
    Component { id: tray; Tray {} }
    Component { id: network; Network {} }
    Component { id: bluetooth; Bluetooth {} }
    Component { id: battery; Battery {} }
    Component { id: power; PowerProfile {} }
    Component { id: language; Language {} }
    Component { id: mixer; Mixer {} }

    // Loader не занимает места, пока виджет сам себя скрывает (`wanted`)
    component Slot: Loader {
        required property string modelData
        sourceComponent: bar.widgets[modelData]
        visible: item?.wanted ?? false
    }

    Item {
        anchors.fill: parent
        anchors.margins: Theme.barMargin

        RowLayout {
            anchors.left: parent.left
            spacing: Theme.gap
            Repeater {
                model: Config.barWidgets("left", bar.screenName)
                delegate: Slot {}
            }
        }

        Clock { anchors.centerIn: parent }

        RowLayout {
            anchors.right: parent.right
            spacing: Theme.gap
            Repeater {
                model: Config.barWidgets("right", bar.screenName)
                delegate: Slot {}
            }
            Panel {
                implicitWidth: Theme.barHeight
                Label { text: ""; Layout.alignment: Qt.AlignCenter }
                overlay: MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: bar.menuRequested()
                }
            }
        }
    }
}
