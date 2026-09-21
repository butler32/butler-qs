import QtQuick
import QtQuick.Layouts
import "../theme"
import "../i18n"

// Строка устройства: клик — подключить/отключить (для несопряжённых — сопрячь и подключить).
Rectangle {
    id: row
    required property var modelData   // BluetoothDevice
    readonly property var d: modelData
    readonly property bool known: d.paired || d.bonded

    Layout.fillWidth: true
    implicitHeight: 38
    radius: Theme.radiusItem
    color: area.containsMouse ? Theme.surfaceAlt : "transparent"

    // после сопряжения сразу подключаемся
    Connections {
        target: row.d
        function onPairedChanged() { if (row.d.paired && !row.d.connected) row.d.connect() }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.padding / 2
        anchors.rightMargin: Theme.padding / 2
        spacing: Theme.gap
        Label { text: row.d.connected ? "" : ""; color: row.d.connected ? Theme.accent : Theme.textDim }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Label { Layout.fillWidth: true; text: row.d.name; elide: Text.ElideRight }
            Label {
                text: row.d.pairing ? I18n.tr("bt.pairing")
                    : row.d.connected ? I18n.tr("bt.connected") + (row.d.batteryAvailable ? " · " + Math.round(row.d.battery * 100) + "%" : "")
                    : row.known ? I18n.tr("bt.paired") : I18n.tr("bt.pair")
                color: Theme.textDim
                font.pixelSize: Theme.fontSize - 3
            }
        }
        Chip {
            visible: row.known
            icon: ""
            danger: true
            onClicked: row.d.forget()
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        anchors.rightMargin: row.known ? 44 : 0     // не перекрывать кнопку «забыть»
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (row.known) row.d.connected ? row.d.disconnect() : row.d.connect()
            else { row.d.trusted = true; row.d.pair() }
        }
    }
}
