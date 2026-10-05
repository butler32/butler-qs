import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../theme"
import "../../i18n"
import "../../services"
import ".."

// Кривые скорости анимаций: плавная кривая Безье (с графиком и шаблонами) или пружина.
ColumnLayout {
    id: root
    readonly property var list: ConfigEditor.entries("curve")

    spacing: Theme.gap * 1.5

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.gap
        Label { text: I18n.tr("cfged.blk.curve"); color: Theme.accent; font.bold: true }
        Label { text: "(" + root.list.length + ")"; color: Theme.textDim }
        Item { Layout.fillWidth: true }
        Chip { icon: ""; text: I18n.tr("cfged.add"); onClicked: ConfigEditor.addCurve() }
    }
    Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: I18n.tr("cfged.curve.note")
        color: Theme.textDim
        font.pixelSize: Theme.fontSize - 1
    }

    Repeater {
        model: ScriptModel { values: root.list; objectProp: "id" }
        delegate: Card {
            id: card
            required property var modelData
            readonly property string type: String(ConfigEditor.fieldValue(modelData, "type", "bezier"))
            readonly property var pts: ConfigEditor.curvePoints(modelData)
            readonly property int used: ConfigEditor.curveUsage(modelData.head)
            Layout.fillWidth: true
            title: modelData.head
            summary: type === "spring" ? I18n.tr("cfged.curve.spring") : I18n.tr("cfged.curve.bezier")
            badge: used > 0 ? I18n.tr("cfged.curve.used").replace("%1", used) : ""
            deletable: used === 0
            onRemoved: ConfigEditor.removeEntry(modelData.ref)

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.gap * 2

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.gap * 1.5

                    SettingRow {
                        Layout.fillWidth: true
                        onCard: true
                        resettable: false
                        title: I18n.tr("cfged.name")
                        hint: I18n.tr("cfged.curve.name.hint")
                        spec: ({ ctl: "text" })
                        value: card.modelData.head
                        onEdited: v => ConfigEditor.renameCurve(card.modelData.ref, card.modelData.head, v)
                    }
                    SettingRow {
                        Layout.fillWidth: true
                        onCard: true
                        resettable: false
                        title: I18n.tr("cfged.curve.type")
                        spec: ({ ctl: "select", options: [
                            { value: "bezier", ru: "Плавная кривая (Безье)", en: "Smooth curve (Bézier)" },
                            { value: "spring", ru: "Пружина", en: "Spring" }] })
                        value: card.type
                        onEdited: v => { if (v !== card.type) ConfigEditor.setCurveType(card.modelData.ref, v) }
                    }
                    SettingRow {
                        Layout.fillWidth: true
                        visible: card.type === "bezier"
                        onCard: true
                        resettable: false
                        title: I18n.tr("cfged.curve.preset")
                        hint: I18n.tr("cfged.curve.preset.hint")
                        spec: ({ ctl: "select", placeholder: I18n.tr("cfged.choose"), options: ConfigEditor.curvePresets.map(p => ({ value: p.id, ru: p.title.ru, en: p.title.en })) })
                        onEdited: v => ConfigEditor.setCurvePoints(card.modelData.ref, ConfigEditor.curvePresets.find(p => p.id === v).points)
                    }
                    RowLayout {
                        visible: card.type === "bezier"
                        spacing: Theme.gap
                        Repeater {
                            model: [I18n.tr("cfged.curve.x1"), I18n.tr("cfged.curve.y1"), I18n.tr("cfged.curve.x2"), I18n.tr("cfged.curve.y2")]
                            ColumnLayout {
                                required property string modelData
                                required property int index
                                spacing: 2
                                Label { text: modelData; color: Theme.textDim; font.pixelSize: Theme.fontSize - 2 }
                                ValueField {
                                    Layout.preferredWidth: 86
                                    onCard: true
                                    kind: "num"
                                    value: String(card.pts[index])
                                    onCommitted: t => { const p = card.pts.slice(); p[index] = Number(t); ConfigEditor.setCurvePoints(card.modelData.ref, p) }
                                }
                            }
                        }
                    }
                    SpecRows {
                        Layout.fillWidth: true
                        visible: card.type === "spring"
                        entry: card.modelData
                        specs: ConfigEditor.springSpecs
                    }
                }
                CurvePreview {
                    visible: card.type === "bezier"
                    Layout.alignment: Qt.AlignTop
                    pts: card.pts
                }
            }
        }
    }
    Label { visible: root.list.length === 0; text: I18n.tr("cfged.empty"); color: Theme.textDim }
}
