import QtQuick
import "../../theme"
import "../../services"
import ".."

// Поле значения: показывает `value`, а `committed(text)` отдаёт только по Enter / потере фокуса
// и только если текст корректен для `kind` (str | int | num | expr). После правки текст
// возвращается к `value`, так что отклонённая правка не оставляет в поле мусор.
Field {
    id: root
    property string value: ""
    property string kind: "str"
    property bool onCard: false            // лежит на карточке (surfaceAlt) — поле светлее/темнее фона
    property bool allowEmpty: false        // пустой текст допустим (и отдаётся как "") — «убрать значение»
    signal committed(string text)

    readonly property bool valid: {
        const t = text.trim()
        if (t === "" && allowEmpty) return true
        if (kind === "int") return /^-?\d+$/.test(t)
        if (kind === "num") return t !== "" && isFinite(Number(t))
        if (kind === "expr") return ConfigEditor.isExpr(t)
        if (kind === "color") return ConfigEditor.hexToColor(t) !== null
        return true
    }
    color: onCard ? Theme.surface : Theme.surfaceAlt
    invalid: text.trim() !== "" && !valid

    function resync() { text = value }
    onValueChanged: if (!input.activeFocus) resync()
    Component.onCompleted: resync()

    Connections {
        target: root.input
        function onEditingFinished() {
            if (root.valid && root.text !== root.value) root.committed(root.text)
            Qt.callLater(root.resync)
        }
    }
}
