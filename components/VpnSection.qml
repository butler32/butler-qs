import QtQuick
import QtQuick.Layouts
import "../theme"
import "../i18n"
import "../config"
import "../services"

// VPN — butler-vpn.service (systemd), a plain OpenVPN connection plus an
// IPv6/LAN-scoped kill switch, installed separately (see scripts/vpn/). Toggling
// runs `sudo systemctl start/stop butler-vpn.service`, passwordless via a scoped
// sudoers rule — nothing here talks to nmcli or NetworkManager.
ColumnLayout {
    id: root
    spacing: Theme.gap

    RowLayout {
        Layout.fillWidth: true
        Label { Layout.fillWidth: true; text: I18n.tr("net.vpn"); color: Theme.accent; font.pixelSize: Theme.fontSize - 2 }
        Chip {
            id: toggle
            icon: ""
            text: NetInfo.vpnBusy ? I18n.tr("vpn.connecting")
                  : NetInfo.vpnConnected ? I18n.tr("vpn.disconnect") : I18n.tr("vpn.connect")
            accent: NetInfo.vpnConnected
            enabled: !NetInfo.vpnBusy
            onClicked: NetInfo.toggleVpn()

            property real pulse: 1
            opacity: NetInfo.vpnBusy ? pulse : 1
            SequentialAnimation {
                running: NetInfo.vpnBusy
                loops: Animation.Infinite
                NumberAnimation { target: toggle; property: "pulse"; from: 1; to: 0.4; duration: 500; easing.type: Easing.InOutQuad }
                NumberAnimation { target: toggle; property: "pulse"; from: 0.4; to: 1; duration: 500; easing.type: Easing.InOutQuad }
            }
        }
    }

    Label {
        Layout.fillWidth: true
        visible: NetInfo.vpnState === "failed" && NetInfo.vpnStatus === ""
        text: I18n.tr("vpn.unitfailed")
        color: Theme.danger
        font.pixelSize: Theme.fontSize - 2
        wrapMode: Text.Wrap
    }

    Label {
        Layout.fillWidth: true
        visible: NetInfo.vpnStatus !== ""
        wrapMode: Text.Wrap
        text: NetInfo.vpnStatus
        color: NetInfo.vpnStatusError ? Theme.danger : Theme.textDim
        font.pixelSize: Theme.fontSize - 2
    }

    // Домены, которые остаются вне туннеля — резолвятся один раз при
    // подключении (см. butler-vpn-up.sh), поэтому изменения здесь применятся
    // только со следующего подключения, не «на лету».
    Label {
        Layout.fillWidth: true
        text: I18n.tr("net.vpn.exclude")
        color: Theme.accent
        font.pixelSize: Theme.fontSize - 2
    }

    Repeater {
        model: Config.network.vpnExcludedDomains
        delegate: RowLayout {
            required property string modelData
            required property int index
            Layout.fillWidth: true
            spacing: Theme.gap
            Label { Layout.fillWidth: true; text: modelData; elide: Text.ElideRight }
            Chip { icon: ""; danger: true; onClicked: Config.removeVpnExcludedDomain(index) }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.gap
        Field {
            id: domainField
            Layout.fillWidth: true
            placeholder: I18n.tr("net.vpn.exclude.placeholder")
            onAccepted: { Config.addVpnExcludedDomain(text); text = "" }
        }
        Chip {
            icon: ""
            text: I18n.tr("net.new")
            onClicked: { Config.addVpnExcludedDomain(domainField.text); domainField.text = "" }
        }
    }
}
