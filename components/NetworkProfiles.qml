import QtQuick
import QtQuick.Layouts
import "../theme"
import "../i18n"
import "../config"
import "../services"

// Сохранённые IP-профили (DHCP / статика), привязанные к конкретной сети.
ColumnLayout {
    id: root
    signal edit(int index)   // -1 — новый профиль
    spacing: Theme.gap

    RowLayout {
        Layout.fillWidth: true
        Label { Layout.fillWidth: true; text: I18n.tr("net.profiles"); color: Theme.accent; font.pixelSize: Theme.fontSize - 2 }
        Chip { icon: ""; text: I18n.tr("net.new"); onClicked: root.edit(-1) }
    }

    Label {
        visible: Config.network.profiles.length === 0
        text: I18n.tr("net.noprofiles")
        color: Theme.textDim
        font.pixelSize: Theme.fontSize - 2
    }

    Repeater {
        model: Config.network.profiles
        delegate: Rectangle {
            id: item
            required property var modelData
            required property int index
            readonly property bool current: NetInfo.active.some(a => a.name === modelData.network)

            Layout.fillWidth: true
            implicitHeight: 46
            radius: Theme.radiusItem
            color: "transparent"
            border.width: Theme.borderWidth
            border.color: current ? Theme.accent : Theme.border

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.padding
                anchors.rightMargin: Theme.padding / 2
                spacing: Theme.gap
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Label { Layout.fillWidth: true; text: item.modelData.name; font.bold: true; elide: Text.ElideRight }
                    Label {
                        Layout.fillWidth: true
                        text: item.modelData.network + " · " + (item.modelData.mode === "dhcp"
                              ? "DHCP" : item.modelData.ip + " / " + item.modelData.mask
                                + (item.modelData.gateway ? " → " + item.modelData.gateway : ""))
                        color: Theme.textDim
                        font.pixelSize: Theme.fontSize - 3
                        elide: Text.ElideRight
                    }
                }
                Chip { icon: ""; text: I18n.tr("net.apply"); accent: true; enabled: !NetInfo.busy
                       onClicked: NetInfo.apply(item.modelData) }
                Chip { icon: ""; onClicked: root.edit(item.index) }
                Chip { icon: ""; danger: true; onClicked: Config.deleteNetworkProfile(item.index) }
            }
        }
    }

    Label {
        Layout.fillWidth: true
        visible: NetInfo.status !== "" || NetInfo.busy
        wrapMode: Text.Wrap
        text: NetInfo.busy ? I18n.tr("net.applying") : NetInfo.status
        color: NetInfo.statusError ? Theme.danger : Theme.textDim
        font.pixelSize: Theme.fontSize - 2
    }
}
