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

        Workspaces { anchors.left: parent.left }
        Clock { anchors.centerIn: parent }

        RowLayout {
            anchors.right: parent.right
            spacing: Theme.gap
            Language {}
            Mixer {}
            Panel {
                implicitWidth: Theme.barHeight
                Label { text: "\uf0c9"; Layout.alignment: Qt.AlignCenter }
                overlay: MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: bar.menuRequested()
                }
            }
        }
    }
}
