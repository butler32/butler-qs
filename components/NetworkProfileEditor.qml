import QtQuick
import QtQuick.Layouts
import "../theme"
import "../i18n"
import "../config"
import "../services"

// Форма создания/редактирования IP-профиля.
ColumnLayout {
    id: root
    property int index: -1
    signal done()
    spacing: Theme.gap

    property string mode: "static"
    property bool tried: false

    function load(i) {
        index = i
        tried = false
        const p = i >= 0 ? Config.network.profiles[i] : null
        nameF.text = p?.name ?? ""
        netF.text = p?.network ?? (NetInfo.active[0]?.name ?? "")
        mode = p?.mode ?? "static"
        ipF.text = p?.ip ?? ""
        maskF.text = p?.mask ?? "255.255.255.0"
        gwF.text = p?.gateway ?? ""
        dnsF.text = p?.dns ?? ""
    }

    readonly property bool isStatic: mode === "static"
    readonly property bool valid: nameF.text.trim() !== "" && netF.text.trim() !== ""
        && (!isStatic || (NetInfo.validIp(ipF.text) && NetInfo.toPrefix(maskF.text) >= 0
                          && (gwF.text.trim() === "" || NetInfo.validIp(gwF.text))))

    function save() {
        tried = true
        if (!valid) return
        Config.saveNetworkProfile(index, {
            name: nameF.text.trim(),
            network: netF.text.trim(),
            mode: mode,
            ip: isStatic ? ipF.text.trim() : "",
            mask: isStatic ? maskF.text.trim() : "",
            gateway: isStatic ? gwF.text.trim() : "",
            dns: isStatic ? dnsF.text.trim() : ""
        })
        done()
    }

    Label { text: index >= 0 ? I18n.tr("net.editprofile") : I18n.tr("net.newprofile"); font.bold: true }

    Field { id: nameF; Layout.fillWidth: true; placeholder: I18n.tr("net.f.name"); invalid: root.tried && text.trim() === ""
            input.KeyNavigation.tab: netF.input; onAccepted: root.save() }
    Field { id: netF; Layout.fillWidth: true; placeholder: I18n.tr("net.f.network"); invalid: root.tried && text.trim() === ""
            input.KeyNavigation.tab: ipF.input; onAccepted: root.save() }
    // подсказки: активные сейчас подключения
    Flow {
        Layout.fillWidth: true
        spacing: 6
        Repeater {
            model: NetInfo.active
            delegate: Chip { required property var modelData; text: modelData.name; onClicked: netF.text = modelData.name }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Chip { Layout.fillWidth: true; text: "DHCP"; accent: !root.isStatic; onClicked: root.mode = "dhcp" }
        Chip { Layout.fillWidth: true; text: I18n.tr("net.static"); accent: root.isStatic; onClicked: root.mode = "static" }
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.isStatic
        spacing: Theme.gap
        Field { id: ipF; Layout.fillWidth: true; placeholder: I18n.tr("net.f.ip") + " 192.168.1.10"
                invalid: root.tried && !NetInfo.validIp(text); input.KeyNavigation.tab: maskF.input; onAccepted: root.save() }
        Field { id: maskF; Layout.fillWidth: true; placeholder: I18n.tr("net.f.mask") + " 255.255.255.0 / 24"
                invalid: root.tried && NetInfo.toPrefix(text) < 0; input.KeyNavigation.tab: gwF.input; onAccepted: root.save() }
        Field { id: gwF; Layout.fillWidth: true; placeholder: I18n.tr("net.f.gateway")
                invalid: root.tried && text.trim() !== "" && !NetInfo.validIp(text); input.KeyNavigation.tab: dnsF.input; onAccepted: root.save() }
        Field { id: dnsF; Layout.fillWidth: true; placeholder: I18n.tr("net.f.dns"); onAccepted: root.save() }
    }

    RowLayout {
        Layout.fillWidth: true
        Item { Layout.fillWidth: true }
        Chip { text: I18n.tr("common.cancel"); onClicked: root.done() }
        Chip { text: I18n.tr("common.save"); accent: true; onClicked: root.save() }
    }
}
