import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../theme"
import "../../i18n"
import "../../services"
import ".."

// Правила для окон: «если окно такое — сделать так». Условия и действия выбираются из списков с понятными
// названиями, класс программы можно взять из открытых окон.
ColumnLayout {
    id: root
    readonly property var list: ConfigEditor.entries("window_rule")
    property int expandIndex: -1

    spacing: Theme.gap * 1.5

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.gap
        Label { text: I18n.tr("cfged.blk.window_rule"); color: Theme.accent; font.bold: true }
        Label { text: "(" + root.list.length + ")"; color: Theme.textDim }
        Item { Layout.fillWidth: true }
        Chip {
            icon: ""
            text: I18n.tr("cfged.add")
            onClicked: { root.expandIndex = root.list.length; ConfigEditor.addEntry("window_rule") }
        }
    }
    Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: I18n.tr("cfged.rules.note")
        color: Theme.textDim
        font.pixelSize: Theme.fontSize - 1
    }

    Repeater {
        model: ScriptModel { values: root.list; objectProp: "id" }
        delegate: Card {
            id: card
            required property var modelData
            required property int index

            readonly property var conds: ConfigEditor.matchOf(modelData)
            readonly property var acts: modelData.fields.filter(f => f.key !== "name" && f.key !== "match" && f.key !== "enabled")
            readonly property bool enabled: ConfigEditor.fieldValue(modelData, "enabled", true) !== false

            function def(list, key) { return list.find(d => d.key === key) ?? null }
            function phrase(list, f) {
                const d = def(list, f.key)
                const t = d ? ConfigEditor.tx(d.title) : f.key
                if (list === ConfigEditor.matchFields && (f.key === "class" || f.key === "title") && f.kind === "str")
                    return ConfigEditor.tx(f.key === "class" ? { ru: "Программа", en: "Program" } : { ru: "Заголовок", en: "Title" })
                           + " " + String(f.value).replace(/^\^\(?/, "").replace(/\)?\$$/, "")
                if (f.kind === "bool") return f.value ? t : "✕ " + t
                const opt = d && d.options ? d.options.find(o => String(o.value) === String(f.value)) : null
                return t + ": " + (opt ? ConfigEditor.tx(opt) : (f.value !== undefined ? f.value : f.text))
            }

            Layout.fillWidth: true
            expanded: index === root.expandIndex
            title: String(ConfigEditor.fieldValue(modelData, "name", "") || I18n.tr("cfged.rule.unnamed"))
            dimTitle: !enabled
            summary: conds.map(f => phrase(ConfigEditor.matchFields, f)).join(", ") + (acts.length ? "  →  " + acts.map(f => phrase(ConfigEditor.effects, f)).join(", ") : "")
            onRemoved: ConfigEditor.removeEntry(modelData.ref)

            SettingRow {
                Layout.fillWidth: true
                onCard: true
                resettable: false
                title: I18n.tr("cfged.rule.name")
                hint: I18n.tr("cfged.rule.name.hint")
                spec: ({ ctl: "text" })
                value: ConfigEditor.fieldValue(card.modelData, "name", "")
                onEdited: v => ConfigEditor.setEntryValue(card.modelData.ref, "name", v)
            }
            SettingRow {
                Layout.fillWidth: true
                onCard: true
                title: I18n.tr("cfged.rule.enabled")
                spec: ({ ctl: "toggle" })
                isSet: !!ConfigEditor.fieldOf(card.modelData, "enabled")
                value: ConfigEditor.fieldValue(card.modelData, "enabled", true)
                onEdited: v => ConfigEditor.setEntryValue(card.modelData.ref, "enabled", v)
                onReset: ConfigEditor.removeEntryField(card.modelData.ref, ["enabled"])
            }

            // ── когда ──
            Label { text: I18n.tr("cfged.rule.when"); color: Theme.accent; font.bold: true; Layout.topMargin: Theme.gap }
            Repeater {
                model: ScriptModel { values: card.conds; objectProp: "key" }
                delegate: ColumnLayout {
                    id: cr
                    required property var modelData
                    readonly property var d: card.def(ConfigEditor.matchFields, modelData.key)
                    Layout.fillWidth: true
                    spacing: 4
                    SettingRow {
                        Layout.fillWidth: true
                        onCard: true
                        title: cr.d ? ConfigEditor.tx(cr.d.title) : cr.modelData.key
                        hint: cr.d ? ConfigEditor.tx(cr.d.hint) : I18n.tr("cfged.no_description")
                        spec: cr.d ?? ({ ctl: cr.modelData.kind === "bool" ? "toggle" : "text" })
                        value: cr.modelData.value !== undefined ? cr.modelData.value : cr.modelData.text
                        onEdited: v => ConfigEditor.setEntryValue(card.modelData.ref, ["match", cr.modelData.key], v)
                        onReset: ConfigEditor.removeEntryField(card.modelData.ref, ["match", cr.modelData.key])
                    }
                    RowLayout {
                        visible: cr.modelData.key === "class"
                        Layout.fillWidth: true
                        spacing: Theme.gap * 1.5
                        Item { Layout.preferredWidth: 320 }
                        Select {
                            Layout.fillWidth: true
                            onCard: true
                            searchable: true
                            placeholder: I18n.tr("cfged.rule.pick_window")
                            items: ConfigEditor.classOptions()
                            onPicked: v => ConfigEditor.setEntryValue(card.modelData.ref, ["match", "class"], v)
                        }
                    }
                }
            }
            Select {
                Layout.preferredWidth: 340
                onCard: true
                searchable: true
                placeholder: "+ " + I18n.tr("cfged.rule.add_cond")
                items: ConfigEditor.matchFields.filter(d => !card.conds.some(f => f.key === d.key)).map(d => ({ value: d.key, label: ConfigEditor.tx(d.title) }))
                onPicked: v => {
                    const d = card.def(ConfigEditor.matchFields, v)
                    ConfigEditor.setEntryValue(card.modelData.ref, ["match", v], d.ctl === "toggle" ? true : "")
                }
            }

            // ── что делать ──
            Label { text: I18n.tr("cfged.rule.then"); color: Theme.accent; font.bold: true; Layout.topMargin: Theme.gap }
            Repeater {
                model: ScriptModel { values: card.acts; objectProp: "key" }
                delegate: SettingRow {
                    id: er
                    required property var modelData
                    readonly property var d: card.def(ConfigEditor.effects, modelData.key)
                    Layout.fillWidth: true
                    onCard: true
                    title: d ? ConfigEditor.tx(d.title) : modelData.key
                    hint: d ? ConfigEditor.tx(d.hint) : I18n.tr("cfged.no_description")
                    spec: d ?? ({ ctl: modelData.kind === "bool" ? "toggle" : modelData.kind === "num" ? "num" : "text" })
                    value: modelData.value !== undefined ? modelData.value : modelData.text
                    onEdited: v => ConfigEditor.setEntryValue(card.modelData.ref, modelData.key, v)
                    onReset: ConfigEditor.removeEntryField(card.modelData.ref, [modelData.key])
                }
            }
            Select {
                Layout.preferredWidth: 340
                onCard: true
                searchable: true
                placeholder: "+ " + I18n.tr("cfged.rule.add_effect")
                items: ConfigEditor.effects.filter(d => !card.acts.some(f => f.key === d.key)).map(d => ({ value: d.key, label: ConfigEditor.tx(d.title) }))
                onPicked: v => {
                    const d = card.def(ConfigEditor.effects, v)
                    const init = d.ctl === "toggle" ? true
                               : d.ctl === "select" ? ConfigEditor.optionsFor(d)[0].value
                               : (d.ctl === "int" || d.ctl === "num") ? (d.min !== undefined ? d.max : 0) : ""
                    ConfigEditor.setEntryValue(card.modelData.ref, v, d.asString ? String(init) : init)
                }
            }
        }
    }
    Label { visible: root.list.length === 0; text: I18n.tr("cfged.empty"); color: Theme.textDim }
}
