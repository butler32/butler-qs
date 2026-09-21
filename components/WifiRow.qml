import QtQuick
import QtQuick.Layouts
import "../theme"
import "../i18n"
import "../services"

// Wi-Fi сеть (plain-данные из NetInfo.wifi): клик — подключить/отключить;
// для защищённой неизвестной сети раскрывается поле пароля.
Rectangle {
    id: row
    required property var modelData   // { name, signal, secure, connected, known }
    readonly property var net: modelData
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
            Label { text: ""; color: row.net.connected ? Theme.accent : Theme.textDim; opacity: 0.4 + row.net.signal / 170 }
            Label { Layout.fillWidth: true; text: row.net.name; elide: Text.ElideRight; font.bold: row.net.connected }
            Label { visible: row.net.secure; text: ""; color: Theme.textDim; font.pixelSize: Theme.fontSize - 2 }
            Label { text: row.net.signal + "%"; color: Theme.textDim; font.pixelSize: Theme.fontSize - 2 }
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
                onClicked: { NetInfo.connectWifi(row.net, pass.text); pass.text = ""; row.asking = false } }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.bottomMargin: row.asking ? row.height - 34 : 0   // раскрытое поле пароля не перекрываем
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (row.net.connected) NetInfo.disconnectWifi(row.net)
            else if (row.net.known || !row.net.secure) NetInfo.connectWifi(row.net, "")
            else { row.asking = !row.asking; if (row.asking) pass.input.forceActiveFocus() }
        }
    }
}
