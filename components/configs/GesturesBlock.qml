import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../theme"
import "../../i18n"
import "../../services"
import ".."

// Жесты тачпада: сколько пальцев, какое движение и что оно делает.
ColumnLayout {
    id: root
    readonly property var list: ConfigEditor.entries("gesture")

    spacing: Theme.gap * 1.5

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.gap
        Label { text: I18n.tr("cfged.blk.gesture"); color: Theme.accent; font.bold: true }
        Item { Layout.fillWidth: true }
        Chip { icon: ""; text: I18n.tr("cfged.add"); onClicked: ConfigEditor.addEntry("gesture") }
    }

    Repeater {
        model: ScriptModel { values: root.list; objectProp: "id" }
        delegate: Card {
            id: card
            required property var modelData
            Layout.fillWidth: true
            expanded: true
            title: I18n.tr("cfged.gesture.title").replace("%1", String(ConfigEditor.fieldValue(modelData, "fingers", "?")))
            onRemoved: ConfigEditor.removeEntry(modelData.ref)
            SpecRows { Layout.fillWidth: true; entry: card.modelData; specs: ConfigEditor.gestureSpecs }
        }
    }
    Label { visible: root.list.length === 0; text: I18n.tr("cfged.empty"); color: Theme.textDim }
}
