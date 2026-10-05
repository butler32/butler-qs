import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../theme"
import "../../i18n"
import "../../services"
import ".."

// Мониторы: карточка на каждый, режимы и имена берутся у самих мониторов (hyprctl), не вводятся руками.
ColumnLayout {
    id: root
    readonly property var list: ConfigEditor.entries("monitor")
    readonly property var configured: list.map(e => String(ConfigEditor.fieldValue(e, "output", "")))
    readonly property var addable: HyprInfo.monitors
        .filter(m => configured.indexOf(m.name) < 0)
        .map(m => ({ value: m.name, label: m.name + " — " + m.description }))

    spacing: Theme.gap * 1.5

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.gap
        Label { text: I18n.tr("cfged.monitors.found").replace("%1", HyprInfo.monitors.length); color: Theme.textDim; Layout.fillWidth: true }
        Select {
            visible: root.addable.length > 0
            Layout.preferredWidth: 300
            placeholder: "+ " + I18n.tr("cfged.monitors.add")
            items: root.addable
            onPicked: v => ConfigEditor.addMonitor(v)
        }
    }
    Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: I18n.tr("cfged.monitors.note")
        color: Theme.textDim
        font.pixelSize: Theme.fontSize - 1
    }

    Repeater {
        model: ScriptModel { values: root.list; objectProp: "id" }
        delegate: Card {
            id: card
            required property var modelData
            readonly property string output: String(ConfigEditor.fieldValue(modelData, "output", ""))
            readonly property var live: HyprInfo.monitorByName(output)
            Layout.fillWidth: true
            expanded: true
            title: output
            summary: live ? live.description : ""
            badge: live ? "" : I18n.tr("cfged.monitors.offline")
            onRemoved: ConfigEditor.removeEntry(modelData.ref)

            SpecRows {
                Layout.fillWidth: true
                entry: card.modelData
                context: card.output
                specs: ConfigEditor.monitorSpecs
            }
        }
    }
    Label {
        visible: root.list.length === 0
        text: I18n.tr("cfged.monitors.none")
        color: Theme.textDim
    }
}
