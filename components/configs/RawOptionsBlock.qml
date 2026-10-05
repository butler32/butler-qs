import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../i18n"
import "../../services"
import ".."

// «Все параметры»: полный список настроек Hyprland под их оригинальными названиями, для опытных пользователей.
// Список пересобирается только при смене поиска, а не при каждой правке, чтобы не терять фокус полей.
ColumnLayout {
    id: root
    property string query: ""
    property bool onlySet: false
    property var items: []

    spacing: Theme.gap

    function headerOf(path) { return path.split(".").slice(0, -1).join(".") }
    function refilter() {
        const q = query.trim().toLowerCase()
        const opts = ConfigEditor.optionsOf(["animations", "binds", "cursor", "debug", "decoration", "dwindle", "ecosystem", "experimental", "general", "gestures", "group", "input", "input_capture", "layout", "master", "misc", "opengl", "quirks", "render", "scrolling", "xwayland"])
            .sort((a, b) => { const ha = headerOf(a.path), hb = headerOf(b.path); return ha !== hb ? (ha < hb ? -1 : 1) : (a.path < b.path ? -1 : 1) })
        const out = []
        let last = null
        for (const o of opts) {
            if (q && o.path.toLowerCase().indexOf(q) < 0) continue
            if (onlySet && !ConfigEditor.getOption(o.path).set) continue
            const h = headerOf(o.path)
            if (h !== last) { out.push({ header: h }); last = h }
            out.push({ path: o.path, type: o.type, label: o.path.slice(h.length + 1) })
        }
        items = out
    }
    onQueryChanged: refilter()
    onOnlySetChanged: refilter()
    Component.onCompleted: refilter()

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.gap
        Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: I18n.tr("cfged.all.note"); color: Theme.textDim; font.pixelSize: Theme.fontSize - 1 }
        Field { Layout.preferredWidth: 200; placeholder: I18n.tr("cfged.search"); onTextChanged: root.query = text }
        Chip { text: I18n.tr("cfged.only_set"); accent: root.onlySet; onClicked: root.onlySet = !root.onlySet }
    }

    Repeater {
        model: root.items
        delegate: Loader {
            id: ld
            required property var modelData
            Layout.fillWidth: true
            Layout.topMargin: modelData.header !== undefined ? Theme.gap : 0
            sourceComponent: modelData.header !== undefined ? headerC : rowC
            onLoaded: item.width = Qt.binding(() => ld.width)
            Component {
                id: headerC
                Label { text: ld.modelData.header; color: Theme.accent; font.bold: true }
            }
            Component {
                id: rowC
                SettingRow {
                    readonly property var opt: ConfigEditor.getOption(ld.modelData.path)
                    readonly property string t: ld.modelData.type
                    title: ld.modelData.label
                    spec: ({ ctl: t === "bool" ? "toggle" : t === "int" ? "int" : t === "num" ? "num" : t === "color" ? "color" : "text" })
                    isSet: opt.set
                    readOnly: opt.set && opt.generated
                    value: opt.set ? (opt.kind === "expr" ? opt.text : opt.value) : HyprInfo.defaultOf(ld.modelData.path)
                    onEdited: v => ConfigEditor.setOption(ld.modelData.path, t === "bool" ? "bool" : (t === "int" || t === "num") ? "num" : "str", v)
                    onReset: ConfigEditor.unsetOption(ld.modelData.path)
                }
            }
        }
    }
    Label { visible: root.items.length === 0; text: I18n.tr("cfged.empty"); color: Theme.textDim }
}
