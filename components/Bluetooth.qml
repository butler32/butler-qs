import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import "../theme"
import "../i18n"

// Значок Bluetooth; клик — окно со списком устройств, поиском и подключением.
// Сопряжение идёт без своего agent'а: работает для устройств «Just Works» (наушники,
// геймпады, мыши); для PIN-устройств используйте bluetoothctl.
Panel {
    id: root
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var devices: adapter?.devices?.values ?? []
    readonly property int connectedCount: devices.filter(d => d.connected).length

    visible: adapter !== null
    implicitWidth: Theme.barHeight

    Label {
        Layout.alignment: Qt.AlignCenter
        text: ""
        color: !root.adapter?.enabled ? Theme.textDim : root.connectedCount > 0 ? Theme.accent : Theme.text
    }
    overlay: MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: popup.toggle()
    }

    BarPopup {
        id: popup
        anchorItem: root
        ipcName: "bluetooth"
        screen: root.QsWindow.window?.screen ?? null
        minWidth: 340
        // поиск ест батарею — не оставляем включённым при закрытии
        onOpenChanged: if (!open && root.adapter) root.adapter.discovering = false

        RowLayout {
            Layout.fillWidth: true
            Label { Layout.fillWidth: true; text: "Bluetooth"; font.bold: true }
            Chip {
                text: root.adapter?.enabled ? I18n.tr("common.on") : I18n.tr("common.off")
                accent: root.adapter?.enabled ?? false
                onClicked: root.adapter.enabled = !root.adapter.enabled
            }
        }

        Label {
            visible: root.adapter?.enabled ?? false
            text: I18n.tr("bt.devices")
            color: Theme.accent
            font.pixelSize: Theme.fontSize - 2
        }
        Repeater {
            model: root.adapter?.enabled ? root.devices : []
            delegate: BtDeviceRow { visible: modelData.paired || modelData.bonded }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.adapter?.enabled ?? false
            Label { Layout.fillWidth: true; text: I18n.tr("bt.nearby"); color: Theme.accent; font.pixelSize: Theme.fontSize - 2 }
            Chip {
                icon: ""
                text: root.adapter?.discovering ? I18n.tr("bt.stop") : I18n.tr("bt.scan")
                accent: root.adapter?.discovering ?? false
                onClicked: root.adapter.discovering = !root.adapter.discovering
            }
        }
        Repeater {
            model: root.adapter?.enabled ? root.devices : []
            // без имени (только MAC) — обычно шум эфира
            delegate: BtDeviceRow {
                visible: !(modelData.paired || modelData.bonded) && modelData.name !== "" && modelData.name !== modelData.address
            }
        }
        Label {
            visible: root.adapter?.discovering ?? false
            text: I18n.tr("bt.searching")
            color: Theme.textDim
            font.pixelSize: Theme.fontSize - 2
        }
    }
}
