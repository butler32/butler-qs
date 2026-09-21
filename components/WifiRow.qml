import QtQuick
import QtQuick.Layouts
import Quickshell.Networking
import "../theme"
import "../i18n"

// Wi-Fi сеть: клик — подключить/отключить; для защищённой неизвестной сети
// раскрывается поле пароля.
Rectangle {
    id: row
    required property var modelData   // WifiNetwork
    readonly property var net: modelData
    readonly property bool open: net.security === WifiSecurityType.Open
    readonly property real signal: Math.round(net.signalStrength <= 1 ? net.signalStrength * 100 : net.signalStrength)
    property bool asking: false

    width: ListView.view ? ListView.view.width : 300
    implicitHeight: col.implicitHeight + 8
    height: implicitHeight
    radius: Theme.radiusItem
    color: area.containsMouse && !asking ? Theme.surfaceAlt : "transparent"

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Theme.padding / 2
        anchors.rightMargin: Theme.padding / 2
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.gap
            Label { text: ""; color: row.net.connected ? Theme.accent : Theme.textDim; opacity: 0.4 + row.signal / 170 }
            Label { Layout.fillWidth: true; text: row.net.name; elide: Text.ElideRight; font.bold: row.net.connected }
            Label { visible: !row.open; text: ""; color: Theme.textDim; font.pixelSize: Theme.fontSize - 2 }
            Label { text: row.signal + "%"; color: Theme.textDim; font.pixelSize: Theme.fontSize - 2 }
            Label { visible: row.net.connected; text: ""; color: Theme.accent }
        }
        RowLayout {
            Layout.fillWidth: true
            visible: row.asking
            Field {
                id: pass
                Layout.fillWidth: true
                placeholder: I18n.tr("net.password")
                echoMode: TextInput.Password
                onAccepted: connectBtn.clicked()
            }
            Chip { id: connectBtn; text: I18n.tr("net.connect"); accent: true
                onClicked: { row.net.connectWithPsk(pass.text); pass.text = ""; row.asking = false } }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.bottomMargin: row.asking ? row.height - 34 : 0   // раскрытое поле пароля не перекрываем
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (row.net.connected) row.net.disconnect()
            else if (row.net.known || row.open) row.net.connect()
            else { row.asking = !row.asking; if (row.asking) pass.input.forceActiveFocus() }
        }
    }
}
