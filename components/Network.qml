import QtQuick
import QtQuick.Layouts
import Quickshell
import "../theme"
import "../i18n"
import "../services"

// Значок сети (Wi-Fi с уровнем сигнала или кабель). Клик — Wi-Fi сети и IP-профили.
// Данные — только из services/NetInfo (nmcli), без Quickshell.Networking (см. там).
Panel {
    id: root
    readonly property var wifiNet: NetInfo.wifi.find(n => n.connected) ?? null
    readonly property bool wired: NetInfo.active.some(d => d.type === "ethernet")

    Label {
        text: root.wifiNet || !root.wired ? "" : ""
        color: root.wifiNet || root.wired ? Theme.accent : Theme.textDim
    }
    Label { visible: root.wifiNet !== null; text: (root.wifiNet?.signal ?? 0) + "%"; font.pixelSize: Theme.fontSize - 1 }

    Label {
        id: vpnIcon
        visible: NetInfo.vpnState !== "disconnected"
        text: ""
        color: NetInfo.vpnConnected ? Theme.accent : NetInfo.vpnState === "failed" ? Theme.danger : Theme.textDim
        property real pulse: 1
        opacity: NetInfo.vpnBusy ? pulse : 1
        SequentialAnimation {
            running: NetInfo.vpnBusy
            loops: Animation.Infinite
            NumberAnimation { target: vpnIcon; property: "pulse"; from: 1; to: 0.3; duration: 500; easing.type: Easing.InOutQuad }
            NumberAnimation { target: vpnIcon; property: "pulse"; from: 0.3; to: 1; duration: 500; easing.type: Easing.InOutQuad }
        }
    }

    overlay: MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: popup.toggle()
    }

    BarPopup {
        id: popup
        anchorItem: root
        ipcName: "network"
        screen: root.QsWindow.window?.screen ?? null
        minWidth: 380
        property int editIndex: -2      // -2: обычный вид, -1: новый профиль, >=0: правка

        onOpenChanged: {
            NetInfo.fast = open
            if (open) { editIndex = -2; NetInfo.rescan(); NetInfo.refresh() }
        }

        // ---------- обычный вид ----------
        ColumnLayout {
            Layout.fillWidth: true
            visible: popup.editIndex === -2
            spacing: Theme.gap

            RowLayout {
                Layout.fillWidth: true
                Label { Layout.fillWidth: true; text: I18n.tr("net.title"); font.bold: true }
                Chip {
                    visible: NetInfo.hasWifi
                    icon: ""
                    text: NetInfo.wifiEnabled ? I18n.tr("common.on") : I18n.tr("common.off")
                    accent: NetInfo.wifiEnabled
                    enabled: !NetInfo.busy
                    onClicked: NetInfo.setWifiEnabled(!NetInfo.wifiEnabled)
                }
            }

            // активные подключения с адресами
            Repeater {
                model: NetInfo.active
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    Label { text: modelData.type === "wifi" ? "" : ""; color: Theme.accent }
                    Label { Layout.fillWidth: true; text: modelData.name; elide: Text.ElideRight }
                    Label { text: modelData.ip + (modelData.gateway ? " → " + modelData.gateway : ""); color: Theme.textDim; font.pixelSize: Theme.fontSize - 2 }
                }
            }

            Label {
                visible: NetInfo.hasWifi && NetInfo.wifiEnabled
                text: I18n.tr("net.wifi")
                color: Theme.accent
                font.pixelSize: Theme.fontSize - 2
            }
            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 230)
                visible: NetInfo.hasWifi && NetInfo.wifiEnabled
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                // objectProp: делегаты (и введённый пароль) переживают обновление списка
                model: ScriptModel { values: NetInfo.wifi; objectProp: "name" }
                delegate: WifiRow {}
            }

            NetworkProfiles {
                Layout.fillWidth: true
                onEdit: i => { editor.load(i); popup.editIndex = i }
            }

            VpnSection { Layout.fillWidth: true }
        }

        // ---------- редактор профиля ----------
        NetworkProfileEditor {
            id: editor
            Layout.fillWidth: true
            visible: popup.editIndex !== -2
            onDone: popup.editIndex = -2
        }
    }
}
