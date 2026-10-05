import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../i18n"
import "../../services"
import ".."

// Контрол значения по описанию из каталога (spec.ctl): переключатель, ползунок + число, список, цвет,
// раскладки, режим/положение монитора… Он ничего не знает про конфиг: показывает `value`, а изменение отдаёт
// сигналом edited(v) — куда его записать, решает хозяин (строка опции hl.config или поле записи).
Item {
    id: root
    property var spec: ({})
    property var value                  // текущее значение (число/строка/bool) или undefined
    property bool isSet: true           // false → значение «по умолчанию», показываем приглушённо
    property bool onCard: false
    property string context: ""         // для режима монитора — имя монитора
    signal edited(var v)

    readonly property string ctl: spec.ctl ?? "text"
    readonly property var kinds: ({
        toggle: toggleC, toggleInverse: toggleInvC, int: numC, num: numC, select: selectC, color: colorC,
        text: textC, expr: textC, layouts: layoutsC, kbswitch: kbswitchC, mode: modeC, position: positionC, command: commandC
    })

    implicitHeight: loader.item ? loader.item.implicitHeight : 30
    implicitWidth: loader.item ? loader.item.implicitWidth : 200
    opacity: isSet ? 1 : 0.65

    Loader {
        id: loader
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        sourceComponent: root.kinds[root.ctl] ?? textC
    }

    // ── переключатель ────────────────────────────────────────────────────────
    Component {
        id: toggleC
        Item {
            implicitHeight: sw.height
            Toggle {
                id: sw
                onCard: root.onCard
                checked: root.value === true || root.value === 1
                dimmed: !root.isSet
                onToggled: v => root.edited(v)
            }
        }
    }
    Component {
        id: toggleInvC
        Item {
            implicitHeight: sw2.height
            Toggle {
                id: sw2
                onCard: root.onCard
                checked: !(root.value === true || root.value === 1)
                onToggled: v => root.edited(!v)
            }
        }
    }

    // ── число: ползунок (если задан диапазон) + поле ─────────────────────────
    Component {
        id: numC
        RowLayout {
            id: nr
            readonly property bool ranged: root.spec.min !== undefined && root.spec.max !== undefined
            readonly property real step: root.spec.step ?? (root.ctl === "int" ? 1 : 0.1)
            readonly property int decimals: step >= 1 ? 0 : Math.max(0, Math.ceil(-Math.log(step) / Math.LN10 - 1e-9))
            property var live: undefined
            readonly property real shown: live !== undefined ? live : Number(root.value ?? 0)
            function fmt(v) { return root.value === undefined && live === undefined ? "" : String(Number(Number(v).toFixed(decimals))) }
            function snap(t) {
                const raw = root.spec.min + t * (root.spec.max - root.spec.min)
                return Math.max(root.spec.min, Math.min(root.spec.max, Number((Math.round(raw / step) * step).toFixed(decimals))))
            }
            spacing: Theme.gap

            RangeSlider {
                visible: nr.ranged
                Layout.fillWidth: true
                Layout.minimumWidth: 120
                value: nr.ranged ? (nr.shown - root.spec.min) / (root.spec.max - root.spec.min) : 0
                dimmed: !root.isSet
                onMoved: t => { nr.live = nr.snap(t); debounce.restart() }
            }
            ValueField {
                Layout.preferredWidth: 84
                Layout.fillWidth: !nr.ranged
                onCard: root.onCard
                kind: root.ctl === "int" ? "int" : "num"
                value: nr.fmt(nr.shown)
                onCommitted: t => root.edited(Number(t))
            }
            Label {
                visible: !!root.spec.unit
                text: root.spec.unit ?? ""
                color: Theme.textDim
            }
            Timer {
                id: debounce
                interval: 250
                onTriggered: { if (nr.live !== undefined) { const v = nr.live; nr.live = undefined; root.edited(v) } }
            }
        }
    }

    // ── список ───────────────────────────────────────────────────────────────
    Component {
        id: selectC
        Select {
            onCard: root.onCard
            dimmed: !root.isSet
            placeholder: root.spec.placeholder ?? I18n.tr("cfged.default")
            items: ConfigEditor.optionsFor(root.spec)
            value: root.spec.asString && root.value !== undefined ? String(root.value) : root.value
            onPicked: v => root.edited(root.spec.asString ? String(v) : v)
        }
    }

    // ── текст ────────────────────────────────────────────────────────────────
    Component {
        id: textC
        ValueField {
            onCard: root.onCard
            allowEmpty: true
            kind: root.ctl === "expr" ? "expr" : "str"
            value: root.value === undefined ? "" : String(root.value)
            placeholder: root.spec.placeholder ?? ""
            onCommitted: t => root.edited(t)
        }
    }

    // ── команда: текст + выбор приложения из установленных ────────────────────
    Component {
        id: commandC
        RowLayout {
            spacing: Theme.gap
            ValueField {
                Layout.fillWidth: true
                onCard: root.onCard
                value: root.value === undefined ? "" : String(root.value)
                placeholder: I18n.tr("cfged.command.ph")
                onCommitted: t => root.edited(t)
            }
            Select {
                id: appSel
                Layout.preferredWidth: 190
                onCard: root.onCard
                searchable: true
                placeholder: I18n.tr("cfged.pick_app")
                items: HyprInfo.apps.map(a => ({ value: a.exec, label: a.name, hint: a.exec }))
                onPicked: v => root.edited(v)
            }
        }
    }

    // ── цвет: образец + hex + палитра ─────────────────────────────────────────
    Component {
        id: colorC
        RowLayout {
            id: cr
            readonly property bool plain: root.value === undefined || (typeof root.value === "string" && root.value.charAt(0) !== "{") || typeof root.value === "number"
            spacing: Theme.gap
            readonly property var palette: [
                ["#ffffff", "Белый", "White"], ["#c0c0c0", "Светло-серый", "Light grey"], ["#808080", "Серый", "Grey"], ["#202020", "Тёмно-серый", "Dark grey"], ["#000000", "Чёрный", "Black"],
                ["#f38ba8", "Красный", "Red"], ["#fab387", "Оранжевый", "Orange"], ["#f9e2af", "Жёлтый", "Yellow"], ["#a6e3a1", "Зелёный", "Green"],
                ["#94e2d5", "Бирюзовый", "Teal"], ["#89b4fa", "Синий", "Blue"], ["#cba6f7", "Фиолетовый", "Purple"], ["#f5c2e7", "Розовый", "Pink"]
            ]
            Select {
                visible: cr.plain
                Layout.preferredWidth: 150
                onCard: root.onCard
                searchable: false
                placeholder: I18n.tr("cfged.palette")
                items: cr.palette.map(p => ({ value: p[0], label: I18n.lang === "ru" ? p[1] : p[2], color: p[0] }))
                onPicked: v => root.edited(ConfigEditor.hexToColor(v))
            }
            Rectangle {
                visible: cr.plain
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                radius: Theme.radiusItem
                color: ConfigEditor.swatch(String(root.value ?? ""))
                border.width: Theme.borderWidth
                border.color: Theme.border
            }
            ValueField {
                visible: cr.plain
                Layout.fillWidth: true
                onCard: root.onCard
                kind: "color"
                allowEmpty: true
                value: ConfigEditor.colorToHex(String(root.value ?? ""))
                placeholder: "#rrggbb"
                onCommitted: t => { const c = ConfigEditor.hexToColor(t); if (c) root.edited(c) }
            }
            Label {
                visible: !cr.plain
                Layout.fillWidth: true
                text: I18n.tr("cfged.gradient")
                color: Theme.textDim
            }
        }
    }

    // ── раскладки клавиатуры: выбранные + добавление из списка xkb ────────────
    Component {
        id: layoutsC
        Flow {
            id: lf
            readonly property var list: ConfigEditor.splitList(root.value)
            spacing: 4
            Repeater {
                model: lf.list
                Chip {
                    required property string modelData
                    required property int index
                    text: modelData
                    icon: ""
                    onClicked: {
                        const l = lf.list.slice()
                        l.splice(index, 1)
                        root.edited(l.join(","))
                    }
                }
            }
            Select {
                width: 220
                searchable: true
                onCard: root.onCard
                placeholder: "+ " + I18n.tr("cfged.add_layout")
                items: ConfigEditor.layoutOptions().filter(o => lf.list.indexOf(o.value) < 0)
                onPicked: v => root.edited(lf.list.concat([v]).join(","))
            }
        }
    }
    Component {
        id: kbswitchC
        Select {
            onCard: root.onCard
            searchable: true
            items: ConfigEditor.switchOptions()
            value: ConfigEditor.switchOf(root.value)
            onPicked: v => root.edited(ConfigEditor.withSwitch(root.value, v))
        }
    }

    // ── монитор: режим (по доступным режимам самого монитора) ─────────────────
    Component {
        id: modeC
        Select {
            onCard: root.onCard
            searchable: true
            items: ConfigEditor.modeOptions(root.context)
            value: root.value === undefined ? undefined : HyprInfo.modeKey(String(root.value))
            onPicked: v => root.edited(v)
        }
    }

    // ── монитор: положение — пресет или точные координаты ─────────────────────
    Component {
        id: positionC
        RowLayout {
            id: pr
            readonly property bool xy: /^-?\d+x-?\d+$/.test(String(root.value ?? ""))
            readonly property var parts: xy ? String(root.value).split("x").map(Number) : [0, 0]
            spacing: Theme.gap
            Select {
                Layout.preferredWidth: 240
                onCard: root.onCard
                items: ConfigEditor.positionOptions()
                value: pr.xy ? "__xy" : root.value
                onPicked: v => root.edited(v === "__xy" ? (pr.xy ? String(root.value) : "0x0") : v)
            }
            Label { visible: pr.xy; text: "X"; color: Theme.textDim }
            ValueField {
                visible: pr.xy
                Layout.preferredWidth: 80
                onCard: root.onCard
                kind: "int"
                value: String(pr.parts[0])
                onCommitted: t => root.edited(t + "x" + pr.parts[1])
            }
            Label { visible: pr.xy; text: "Y"; color: Theme.textDim }
            ValueField {
                visible: pr.xy
                Layout.preferredWidth: 80
                onCard: root.onCard
                kind: "int"
                value: String(pr.parts[1])
                onCommitted: t => root.edited(pr.parts[0] + "x" + t)
            }
        }
    }
}
