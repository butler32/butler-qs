import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import "../theme"
import "../i18n"
import "../services"

// Значок сети (Wi-Fi с уровнем сигнала или кабель). Клик — Wi-Fi сети и IP-профили.
Panel {
    id: root
    readonly property var devs: Networking.devices.values
    readonly property var wifi: devs.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wired: devs.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var wifiNet: wifi?.networks.values.find(n => n.connected) ?? null
    readonly property real wifiPct: wifiNet ? Math.round(wifiNet.signalStrength <= 1 ? wifiNet.signalStrength * 100 : wifiNet.signalStrength) : 0

    Label {
        text: root.wifiNet ? "" : root.wired ? "" : ""
        color: root.wifiNet || root.wired ? Theme.accent : Theme.textDim
    }
    Label { visible: root.wifiNet !== null; text: root.wifiPct + "%"; font.pixelSize: Theme.fontSize - 1 }

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
            if (root.wifi) root.wifi.scannerEnabled = open
            if (open) { editIndex = -2; NetInfo.refresh() }
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
                    visible: root.wifi !== null
                    icon: ""
                    text: Networking.wifiEnabled ? I18n.tr("common.on") : I18n.tr("common.off")
                    accent: Networking.wifiEnabled
                    onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
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
                visible: root.wifi !== null && Networking.wifiEnabled
                text: I18n.tr("net.wifi")
                color: Theme.accent
                font.pixelSize: Theme.fontSize - 2
            }
            ListView {
                id: wifiList
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 230)
                visible: root.wifi !== null && Networking.wifiEnabled
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                // ScriptModel сохраняет делегаты при пересортировке (важно для поля пароля)
                model: ScriptModel {
                    values: (root.wifi?.networks.values ?? []).slice().sort((a, b) =>
                        (b.connected - a.connected) || (b.signalStrength - a.signalStrength))
                }
                delegate: WifiRow {}
            }

            NetworkProfiles {
                Layout.fillWidth: true
                onEdit: i => { editor.load(i); popup.editIndex = i }
            }
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
