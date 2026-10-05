import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../theme"
import "../../i18n"
import "../../services"
import ".."

// Правила рабочих столов: «стол N живёт на мониторе M»; дополнительные настройки — в раскрывающейся части.
ColumnLayout {
    id: root
    readonly property var list: ConfigEditor.entries("workspace_rule")

    spacing: Theme.gap * 1.5

    RowLayout {
        Layout.fillWidth: true
        Label { Layout.fillWidth: true; text: I18n.tr("cfged.ws.note"); wrapMode: Text.WordWrap; color: Theme.textDim; font.pixelSize: Theme.fontSize - 1 }
        Chip { icon: ""; text: I18n.tr("cfged.add"); onClicked: ConfigEditor.addWorkspaceRule() }
    }

    Repeater {
        model: ScriptModel { values: root.list; objectProp: "id" }
        delegate: Card {
            id: card
            required property var modelData
            Layout.fillWidth: true
            title: I18n.tr("cfged.ws.label")
            onRemoved: ConfigEditor.removeEntry(modelData.ref)

            headerExtra: RowLayout {
                spacing: Theme.gap
                Select {
                    Layout.preferredWidth: 130
                    onCard: true
                    items: ConfigEditor.wsList()
                    value: String(ConfigEditor.fieldValue(card.modelData, "workspace", ""))
                    onPicked: v => ConfigEditor.setEntryValue(card.modelData.ref, "workspace", String(v))
                }
                Label { text: I18n.tr("cfged.ws.on"); color: Theme.textDim }
                Select {
                    Layout.preferredWidth: 260
                    onCard: true
                    items: ConfigEditor.optionsFor({ from: "monitorsNone" })
                    value: ConfigEditor.fieldValue(card.modelData, "monitor", "")
                    onPicked: v => v === "" ? ConfigEditor.removeEntryField(card.modelData.ref, ["monitor"]) : ConfigEditor.setEntryValue(card.modelData.ref, "monitor", v)
                }
            }

            SpecRows {
                Layout.fillWidth: true
                entry: card.modelData
                specs: ConfigEditor.wsExtras
            }
        }
    }
    Label { visible: root.list.length === 0; text: I18n.tr("cfged.empty"); color: Theme.textDim }
}
