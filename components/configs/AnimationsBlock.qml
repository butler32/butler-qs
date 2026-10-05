import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../theme"
import "../../i18n"
import "../../services"
import ".."

// Анимации по событиям: что анимируется, как долго, по какой кривой и каким стилем.
// Кривые и стили выбираются из списков, названия событий — человеческие.
ColumnLayout {
    id: root
    readonly property var list: ConfigEditor.animations()

    spacing: Theme.gap * 1.5

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.gap
        Label { text: I18n.tr("cfged.blk.animation"); color: Theme.accent; font.bold: true }
        Label { text: "(" + root.list.length + ")"; color: Theme.textDim }
        Item { Layout.fillWidth: true }
        Select {
            Layout.preferredWidth: 300
            placeholder: "+ " + I18n.tr("cfged.anim.add")
            searchable: true
            items: ConfigEditor.unusedLeaves()
            onPicked: v => ConfigEditor.addAnimation(v)
        }
    }
    Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: I18n.tr("cfged.anim.note")
        color: Theme.textDim
        font.pixelSize: Theme.fontSize - 1
    }

    Repeater {
        model: ScriptModel { values: root.list; objectProp: "id" }
        delegate: Card {
            id: card
            required property var modelData
            Layout.fillWidth: true
            expandable: false
            title: modelData.name
            dimTitle: !modelData.enabled
            onRemoved: ConfigEditor.removeEntry(modelData.ref)
            headerExtra: Toggle {
                onCard: true
                checked: card.modelData.enabled
                onToggled: v => ConfigEditor.setEntryValue(card.modelData.ref, "enabled", v)
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.gap * 2
                enabled: card.modelData.enabled
                opacity: enabled ? 1 : 0.5

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 300
                    spacing: 2
                    Label { text: I18n.tr("cfged.anim.duration"); color: Theme.textDim; font.pixelSize: Theme.fontSize - 2 }
                    RowLayout {
                        spacing: Theme.gap
                        ValueControl {
                            Layout.fillWidth: true
                            onCard: true
                            spec: ({ ctl: "num", min: 0.5, max: 20, step: 0.1 })
                            value: card.modelData.speed
                            onEdited: v => ConfigEditor.setEntryValue(card.modelData.ref, "speed", v)
                        }
                        Label { text: (card.modelData.speed / 10).toFixed(2) + " " + I18n.tr("cfged.anim.sec"); color: Theme.textDim }
                    }
                }
                ColumnLayout {
                    Layout.preferredWidth: 200
                    spacing: 2
                    Label { text: I18n.tr("cfged.anim.curve"); color: Theme.textDim; font.pixelSize: Theme.fontSize - 2 }
                    Select {
                        Layout.fillWidth: true
                        onCard: true
                        items: ConfigEditor.curveOptions()
                        value: card.modelData.curve
                        onPicked: v => ConfigEditor.setAnimCurve(card.modelData.ref, v)
                    }
                }
                ColumnLayout {
                    Layout.preferredWidth: 230
                    visible: ConfigEditor.styleOptions(card.modelData.leaf).length > 1
                    spacing: 2
                    Label { text: I18n.tr("cfged.anim.style"); color: Theme.textDim; font.pixelSize: Theme.fontSize - 2 }
                    RowLayout {
                        spacing: Theme.gap
                        Select {
                            Layout.fillWidth: true
                            onCard: true
                            items: ConfigEditor.styleOptions(card.modelData.leaf)
                            value: card.modelData.style
                            onPicked: v => ConfigEditor.setAnimStyle(card.modelData.ref, v, card.modelData.pct)
                        }
                        ValueField {
                            visible: !!ConfigEditor.stylePct[card.modelData.style]
                            Layout.preferredWidth: 56
                            onCard: true
                            kind: "int"
                            value: String(card.modelData.pct || "")
                            placeholder: "%"
                            onCommitted: t => ConfigEditor.setAnimStyle(card.modelData.ref, card.modelData.style, Number(t))
                        }
                    }
                }
            }
        }
    }
    Label { visible: root.list.length === 0; text: I18n.tr("cfged.empty"); color: Theme.textDim }
}
