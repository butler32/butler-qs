import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../i18n"
import "../../services"
import ".."

// Исходный текст конфигов: выбор файла из списка и правка прямо в нём.
ColumnLayout {
    id: root
    property string file: ConfigEditor.current().files[0].path

    spacing: Theme.gap

    Select {
        Layout.preferredWidth: 340
        searchable: false
        items: ConfigEditor.current().files.map(f => ({ value: f.path, label: f.path, hint: f.generated ? I18n.tr("cfged.generated") : "" }))
        value: root.file
        onPicked: v => root.file = v
    }
    SourceView {
        Layout.fillWidth: true
        Layout.preferredHeight: 520
        path: root.file
    }
}
