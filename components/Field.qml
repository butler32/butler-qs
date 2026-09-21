import QtQuick
import "../theme"

// Однострочное поле ввода в стиле темы.
Rectangle {
    id: root
    property alias text: input.text
    property string placeholder
    property alias echoMode: input.echoMode
    property alias input: input
    property bool invalid: false
    signal accepted()

    implicitWidth: 160
    implicitHeight: 30
    radius: Theme.radiusItem
    color: Theme.surfaceAlt
    border.width: invalid ? 1 : 0
    border.color: Theme.danger

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.text
        selectionColor: Theme.accent
        selectedTextColor: Theme.accentText
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        clip: true
        onAccepted: root.accepted()
    }
    Label {
        visible: !input.text && !input.activeFocus
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 8
        elide: Text.ElideRight
        text: root.placeholder
        color: Theme.textDim
    }
}
