import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../i18n"
import "../../services"
import ".."

// Одна горячая клавиша: модификаторы, клавиша (из списка), действие (из списка) и его параметры.
// Действие распознаётся из вызова Hyprland; если оно нестандартное — доступна правка выражения Lua.
Rectangle {
    id: row
    required property var modelData        // из ConfigEditor.binds()
    property bool expanded: false

    readonly property var act: modelData.act
    readonly property var actDef: act ? ConfigEditor.actions.find(a => a.id === act.id) : null

    function setMods(list) { ConfigEditor.setBindKey(modelData.ref, list, modelData.key) }
    function toggleMod(m) {
        const has = modelData.mods.indexOf(m) >= 0
        const list = has ? modelData.mods.filter(x => x !== m) : modelData.mods.concat([m])
        const order = x => { const i = ConfigEditor.bindMods.findIndex(d => d[0] === x); return i < 0 ? 99 : i }
        list.sort((a, b) => order(a) - order(b))
        setMods(list)
    }
    function chooseAction(id) {
        if (id === "__raw") return
        ConfigEditor.setBindAction(modelData.ref, id, {}, modelData.wrap)
    }
    function setParam(key, v) {
        const values = Object.assign({}, act ? act.values : {})
        values[key] = v
        ConfigEditor.setBindAction(modelData.ref, act.id, values, modelData.wrap)
    }
    function flagOn(k) {
        const o = modelData.opts.find(x => x.key === k)
        return !!o && o.value === true
    }

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + Theme.padding
    radius: Theme.radiusItem
    color: Theme.surfaceAlt

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.padding / 2
        spacing: Theme.gap

        // создаётся циклом — формой не правится
        RowLayout {
            Layout.fillWidth: true
            visible: !row.modelData.editable
            spacing: Theme.gap
            Label { text: ""; color: Theme.textDim }
            Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: I18n.tr("cfged.bind.locked")
                color: Theme.textDim
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: row.modelData.editable
            spacing: 4

            Repeater {
                model: ConfigEditor.bindMods
                Chip {
                    required property var modelData
                    text: ConfigEditor.tx(modelData[1])
                    accent: row.modelData.mods.indexOf(modelData[0]) >= 0
                    onClicked: row.toggleMod(modelData[0])
                }
            }
            Label { text: "+"; color: Theme.textDim }
            Select {
                Layout.preferredWidth: 190
                onCard: true
                searchable: true
                items: ConfigEditor.keyItems()
                value: row.modelData.key
                placeholder: I18n.tr("cfged.key")
                onPicked: v => ConfigEditor.setBindKey(row.modelData.ref, row.modelData.mods, v)
            }
            Label { text: "→"; color: Theme.textDim }
            Select {
                Layout.fillWidth: true
                onCard: true
                searchable: true
                items: ConfigEditor.actionItems()
                value: row.act ? row.act.id : "__raw"
                onPicked: v => row.chooseAction(v)
            }
            Chip { icon: ""; accent: row.expanded; onClicked: row.expanded = !row.expanded }
            Chip { icon: ""; danger: true; onClicked: ConfigEditor.removeEntry(row.modelData.ref) }
        }

        // параметры действия
        Repeater {
            model: row.actDef && row.modelData.editable ? row.actDef.params : []
            delegate: SettingRow {
                required property var modelData
                Layout.fillWidth: true
                onCard: true
                resettable: false
                labelWidth: 110
                title: ConfigEditor.tx(modelData.title)
                spec: modelData
                value: row.act.values[modelData.key] !== undefined ? row.act.values[modelData.key] : ConfigEditor.defaultParam(modelData)
                onEdited: v => row.setParam(modelData.key, v)
            }
        }
        SettingRow {
            Layout.fillWidth: true
            visible: !row.act && row.modelData.editable
            onCard: true
            resettable: false
            title: I18n.tr("cfged.bind.lua")
            hint: I18n.tr("cfged.bind.lua.hint")
            spec: ({ ctl: "expr" })
            value: row.modelData.dispatcher
            onEdited: v => ConfigEditor.setBindDispatcher(row.modelData.ref, v, row.modelData.wrap)
        }

        // доп. опции
        ColumnLayout {
            Layout.fillWidth: true
            visible: row.modelData.editable && row.expanded
            spacing: Theme.gap
            SettingRow {
                Layout.fillWidth: true
                visible: ConfigEditor.dotaAvailable()
                onCard: true
                resettable: false
                title: I18n.tr("cfged.bind.nodota")
                hint: I18n.tr("cfged.bind.nodota.hint")
                spec: ({ ctl: "toggle" })
                value: row.modelData.wrap
                onEdited: v => ConfigEditor.setBindDispatcher(row.modelData.ref, row.modelData.dispatcher, v)
            }
            Repeater {
                model: ConfigEditor.bindFlags
                delegate: SettingRow {
                    required property var modelData
                    Layout.fillWidth: true
                    onCard: true
                    resettable: false
                    title: ConfigEditor.tx(modelData[1])
                    spec: ({ ctl: "toggle" })
                    value: row.flagOn(modelData[0])
                    onEdited: v => v ? ConfigEditor.setBindOpt(row.modelData.ref, modelData[0], "bool", true)
                                     : ConfigEditor.removeBindOpt(row.modelData.ref, modelData[0])
                }
            }
        }
    }
}
