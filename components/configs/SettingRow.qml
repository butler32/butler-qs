import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../i18n"
import "../../services"
import ".."

// Одна настройка: слева понятное название и пояснение, справа контрол, ✕ — вернуть значение по умолчанию.
RowLayout {
    id: row
    property string title: ""
    property string hint: ""
    property var spec: ({})
    property var value
    property bool isSet: true
    property bool readOnly: false       // значение задаёт тема оформления
    property bool resettable: true
    property bool onCard: false
    property string context: ""
    property real labelWidth: 320
    signal edited(var v)
    signal reset()

    spacing: Theme.gap * 1.5

    ColumnLayout {
        Layout.preferredWidth: row.labelWidth
        Layout.maximumWidth: row.labelWidth
        Layout.alignment: Qt.AlignTop
        spacing: 1
        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: row.title
            color: row.isSet ? Theme.text : Theme.text
            font.bold: row.isSet
        }
        Label {
            Layout.fillWidth: true
            visible: row.hint !== "" || row.readOnly
            wrapMode: Text.WordWrap
            text: row.readOnly ? I18n.tr("cfged.theme_managed") : row.hint
            color: Theme.textDim
            font.pixelSize: Theme.fontSize - 2
        }
    }

    ValueControl {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        enabled: !row.readOnly
        opacity: row.readOnly ? 0.6 : 1
        spec: row.spec
        value: row.value
        isSet: row.isSet
        onCard: row.onCard
        context: row.context
        onEdited: v => row.edited(v)
    }

    Chip {
        Layout.alignment: Qt.AlignTop
        icon: ""
        visible: row.resettable
        enabled: row.isSet && !row.readOnly
        opacity: row.isSet && !row.readOnly ? 1 : 0
        onClicked: row.reset()
    }
}
