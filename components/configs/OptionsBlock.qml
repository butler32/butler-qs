import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../i18n"
import "../../services"
import ".."

// Блок настроек hl.config из каталога: заголовок, при необходимости пояснение и строки с понятными названиями.
ColumnLayout {
    id: root
    required property var block         // { title, note, items:[{path, ctl, title, hint, …}] }

    spacing: Theme.gap * 1.5

    Label {
        text: ConfigEditor.tx(root.block.title)
        color: Theme.accent
        font.bold: true
    }
    Label {
        Layout.fillWidth: true
        visible: !!root.block.note
        wrapMode: Text.WordWrap
        text: ConfigEditor.tx(root.block.note)
        color: Theme.textDim
        font.pixelSize: Theme.fontSize - 1
    }

    Repeater {
        model: root.block.items
        delegate: SettingRow {
            id: sr
            required property var modelData
            readonly property var opt: ConfigEditor.getOption(modelData.path)
            Layout.fillWidth: true
            title: ConfigEditor.tx(modelData.title)
            hint: ConfigEditor.tx(modelData.hint)
            spec: modelData
            isSet: opt.set
            readOnly: opt.set && opt.generated
            value: opt.set ? (opt.kind === "expr" ? opt.text : opt.value) : HyprInfo.defaultOf(modelData.path)
            onEdited: v => {
                const k = modelData.ctl === "toggle" ? "bool"
                        : (modelData.ctl === "int" || modelData.ctl === "num") ? "num"
                        : typeof v === "number" ? "num" : typeof v === "boolean" ? "bool" : "str"
                ConfigEditor.setOption(modelData.path, k, v)
            }
            onReset: ConfigEditor.unsetOption(modelData.path)
        }
    }
}
