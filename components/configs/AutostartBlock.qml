import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../theme"
import "../../i18n"
import "../../services"
import ".."

// Автозапуск: программы можно выбрать из установленных, команду — написать самому.
ColumnLayout {
    id: root
    readonly property var list: ConfigEditor.execs()

    // Приложение по команде: полное совпадение либо совпадение имени программы (первое слово без пути)
    function prog(cmd) { return String(cmd).trim().split(/\s+/)[0].split("/").pop().toLowerCase() }
    function appFor(cmd) {
        const c = HyprInfo.stripCodes(String(cmd).replace(/\s*&\s*$/, ""))
        return HyprInfo.apps.find(a => a.exec === c) ?? HyprInfo.apps.find(a => prog(a.exec) === prog(c) && prog(c) !== "") ?? null
    }

    spacing: Theme.gap * 1.5

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.gap
        Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: I18n.tr("cfged.autostart.note"); color: Theme.textDim; font.pixelSize: Theme.fontSize - 1 }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.gap
        Select {
            Layout.preferredWidth: 300
            searchable: true
            placeholder: "+ " + I18n.tr("cfged.autostart.add_app")
            items: HyprInfo.apps.map(a => ({ value: a.exec, label: a.name, hint: a.exec }))
            onPicked: v => ConfigEditor.addAutostart(v)
        }
        Chip { icon: ""; text: I18n.tr("cfged.autostart.add_cmd"); onClicked: ConfigEditor.addAutostart("") }
    }

    Repeater {
        model: ScriptModel { values: root.list; objectProp: "id" }
        delegate: Rectangle {
            id: ar
            required property var modelData
            readonly property var app: root.appFor(modelData.cmd)
            Layout.fillWidth: true
            implicitHeight: arow.implicitHeight + Theme.padding
            radius: Theme.radiusItem
            color: Theme.surfaceAlt
            RowLayout {
                id: arow
                anchors.fill: parent
                anchors.margins: Theme.padding / 2
                spacing: Theme.gap
                Label {
                    Layout.preferredWidth: 150
                    elide: Text.ElideRight
                    text: ar.app ? ar.app.name : I18n.tr("cfged.autostart.command")
                    font.bold: !!ar.app
                    color: ar.app ? Theme.text : Theme.textDim
                }
                ValueControl {
                    Layout.fillWidth: true
                    onCard: true
                    spec: ({ ctl: "command" })
                    value: ar.modelData.cmd
                    onEdited: v => ConfigEditor.setExec(ar.modelData.ref, v)
                }
                Chip { icon: ""; danger: true; onClicked: ConfigEditor.removeEntry(ar.modelData.ref) }
            }
        }
    }
    Label { visible: root.list.length === 0; text: I18n.tr("cfged.empty"); color: Theme.textDim }
}
