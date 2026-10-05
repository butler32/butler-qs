import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../theme"
import "../../i18n"
import "../../services"
import ".."

// Отдельные настройки для конкретных устройств (мышь, тачпад, клавиатура): перекрывают общие.
ColumnLayout {
    id: root
    readonly property var list: ConfigEditor.entries("device")
    readonly property var configured: list.map(e => String(ConfigEditor.fieldValue(e, "name", "")))

    spacing: Theme.gap * 1.5

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.gap
        Label { text: I18n.tr("cfged.blk.device"); color: Theme.accent; font.bold: true }
        Item { Layout.fillWidth: true }
        Select {
            Layout.preferredWidth: 300
            placeholder: "+ " + I18n.tr("cfged.device.add")
            searchable: true
            items: ConfigEditor.deviceOptions().filter(d => root.configured.indexOf(d.value) < 0)
            onPicked: v => ConfigEditor.addDevice(v)
        }
    }
    Label { Layout.fillWidth: true; text: I18n.tr("cfged.device.note"); wrapMode: Text.WordWrap; color: Theme.textDim; font.pixelSize: Theme.fontSize - 1 }

    Repeater {
        model: ScriptModel { values: root.list; objectProp: "id" }
        delegate: Card {
            id: card
            required property var modelData
            Layout.fillWidth: true
            title: String(ConfigEditor.fieldValue(modelData, "name", "?"))
            onRemoved: ConfigEditor.removeEntry(modelData.ref)
            SpecRows { Layout.fillWidth: true; entry: card.modelData; specs: ConfigEditor.deviceSpecs }
        }
    }
    Label { visible: root.list.length === 0; text: I18n.tr("cfged.empty"); color: Theme.textDim }
}
