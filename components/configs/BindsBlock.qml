import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../theme"
import "../../i18n"
import "../../services"
import ".."

// Горячие клавиши: строка = сочетание → действие. Бинды, созданные циклом (воркспейсы 1–10), формой не правятся.
ColumnLayout {
    id: root
    property string query: ""

    readonly property var list: {
        const q = query.trim().toLowerCase()
        return ConfigEditor.binds().filter(b => {
            if (!q) return true
            const act = b.act ? ConfigEditor.tx(ConfigEditor.actions.find(a => a.id === b.act.id).title) : ""
            return (b.mods.join(" ") + " " + b.key + " " + act + " " + b.dispatcher).toLowerCase().indexOf(q) >= 0
        })
    }

    spacing: Theme.gap * 1.5

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.gap
        Label { text: "(" + root.list.length + ")"; color: Theme.textDim }
        Item { Layout.fillWidth: true }
        Field {
            Layout.preferredWidth: 220
            placeholder: I18n.tr("cfged.search")
            onTextChanged: root.query = text
        }
        Chip { icon: ""; text: I18n.tr("cfged.add"); onClicked: ConfigEditor.addBind() }
    }
    Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: I18n.tr("cfged.binds.note")
        color: Theme.textDim
        font.pixelSize: Theme.fontSize - 1
    }

    Repeater {
        model: ScriptModel { values: root.list; objectProp: "id" }
        delegate: BindRow {}
    }
}
