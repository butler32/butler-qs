import QtQuick
import QtQuick.Layouts
import Quickshell
import "../theme"

PanelWindow {
    id: bar
    signal menuRequested()
    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.barHeight + Theme.barMargin * 2
    color: Theme.bg

    Item {
        anchors.fill: parent
        anchors.margins: Theme.barMargin

        RowLayout {
            anchors.left: parent.left
            spacing: Theme.gap
            Workspaces {}
            AppDock {}
            Media {}
        }

        Clock { anchors.centerIn: parent }

        RowLayout {
            anchors.right: parent.right
            spacing: Theme.gap
            SysMon {}
            Network {}
            Bluetooth {}
            Battery {}
            Language {}
            Mixer {}
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
