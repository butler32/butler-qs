import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../i18n"
import "../../services"
import ".."

// Строки настроек записи по списку описаний из каталога (specs): значение берётся из поля записи,
// а если поля нет — показывается значение по умолчанию (spec.def). ✕ убирает поле из конфига.
ColumnLayout {
    id: root
    required property var entry
    required property var specs
    property var path: []               // префикс ключей (вложенная таблица)
    property string context: ""
    spacing: Theme.gap * 1.5

    Repeater {
        model: root.specs
        delegate: SettingRow {
            id: sr
            required property var modelData
            readonly property var f: ConfigEditor.fieldOf(root.entry, modelData.key)
            Layout.fillWidth: true
            onCard: true
            title: ConfigEditor.tx(modelData.title)
            hint: ConfigEditor.tx(modelData.hint)
            spec: modelData
            context: root.context
            isSet: !!f
            value: f ? (f.value !== undefined ? f.value : f.text) : modelData.def
            onEdited: v => ConfigEditor.setEntryValue(root.entry.ref, root.path.concat([modelData.key]), v)
            onReset: ConfigEditor.removeEntryField(root.entry.ref, root.path.concat([modelData.key]))
        }
    }
}
