import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../theme"
import "../../i18n"
import "../../services"
import ".."

// Переменные окружения: частые — из списка с пояснением, любые другие — вручную.
ColumnLayout {
    id: root
    readonly property var list: ConfigEditor.envs()

    function presetOf(name) { return ConfigEditor.envPresets.find(p => p[0] === name) ?? null }

    spacing: Theme.gap * 1.5

    Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: I18n.tr("cfged.env.note"); color: Theme.textDim; font.pixelSize: Theme.fontSize - 1 }
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.gap
        Select {
            Layout.preferredWidth: 340
            searchable: true
            placeholder: "+ " + I18n.tr("cfged.env.add_known")
            items: ConfigEditor.envPresets.filter(p => !root.list.some(e => e.name === p[0])).map(p => ({ value: p[0], label: ConfigEditor.tx(p[1]), hint: p[0] }))
            onPicked: v => ConfigEditor.addEnv(v, root.presetOf(v)[2])
        }
        Chip { icon: ""; text: I18n.tr("cfged.env.add_custom"); onClicked: ConfigEditor.addEnv("NAME", "") }
    }

    Repeater {
        model: ScriptModel { values: root.list; objectProp: "id" }
        delegate: Rectangle {
            id: er
            required property var modelData
            readonly property var preset: root.presetOf(modelData.name)
            Layout.fillWidth: true
            implicitHeight: ecol.implicitHeight + Theme.padding
            radius: Theme.radiusItem
            color: Theme.surfaceAlt
            ColumnLayout {
                id: ecol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.padding / 2
                spacing: 2
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.gap
                    ValueField {
                        Layout.preferredWidth: 260
                        onCard: true
                        value: er.modelData.name
                        placeholder: I18n.tr("cfged.env.name")
                        onCommitted: t => ConfigEditor.setEnv(er.modelData.ref, t, er.modelData.value)
                    }
                    Label { text: "="; color: Theme.textDim }
                    ValueField {
                        Layout.fillWidth: true
                        onCard: true
                        allowEmpty: true
                        value: er.modelData.value
                        placeholder: I18n.tr("cfged.value")
                        onCommitted: t => ConfigEditor.setEnv(er.modelData.ref, er.modelData.name, t)
                    }
                    Chip { icon: ""; danger: true; onClicked: ConfigEditor.removeEntry(er.modelData.ref) }
                }
                Label {
                    visible: !!er.preset
                    text: er.preset ? ConfigEditor.tx(er.preset[1]) : ""
                    color: Theme.textDim
                    font.pixelSize: Theme.fontSize - 2
                }
            }
        }
    }
    Label { visible: root.list.length === 0; text: I18n.tr("cfged.empty"); color: Theme.textDim }
}
