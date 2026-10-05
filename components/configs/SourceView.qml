import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../i18n"
import "../../services"
import ".."

// Исходник файла целиком: страховка для всего, что формы не покрывают (циклы, локальные переменные,
// нестандартные вызовы). Генерируемые темой файлы — только чтение.
ColumnLayout {
    id: root
    required property string path
    readonly property bool generated: ConfigEditor.isGenerated(path)
    readonly property var doc: ConfigEditor.doc(path)
    property bool loading: false

    spacing: Theme.gap

    function load() {
        loading = true
        editor.text = ConfigEditor.textOf(path)
        loading = false
    }
    onPathChanged: load()
    Component.onCompleted: load()
    Connections {
        target: ConfigEditor
        function onTextReplaced(p) { if (p === root.path) root.load() }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.gap
        Label { text: root.path; color: Theme.accent }
        Label {
            visible: root.generated
            text: " " + I18n.tr("cfged.generated")
            color: Theme.textDim
        }
        Label {
            visible: !!root.doc && !!root.doc.error
            text: I18n.tr("cfged.parse_error")
            color: Theme.danger
        }
        Item { Layout.fillWidth: true }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Theme.radiusItem
        color: Theme.surfaceAlt
        clip: true

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: Theme.padding / 2
            contentWidth: editor.width
            contentHeight: editor.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            TextEdit {
                id: editor
                width: Math.max(implicitWidth, flick.width)
                readOnly: root.generated
                selectByMouse: true
                color: Theme.text
                selectionColor: Theme.accent
                selectedTextColor: Theme.accentText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                tabStopDistance: 4 * fontMetrics.averageCharacterWidth
                onTextChanged: if (!root.loading) ConfigEditor.setSource(root.path, text)
                FontMetrics { id: fontMetrics; font: editor.font }

                // не даём курсору уехать за край видимой области
                onCursorRectangleChanged: {
                    const r = cursorRectangle
                    if (r.y < flick.contentY) flick.contentY = r.y
                    else if (r.y + r.height > flick.contentY + flick.height) flick.contentY = r.y + r.height - flick.height
                    if (r.x < flick.contentX) flick.contentX = r.x
                    else if (r.x + r.width > flick.contentX + flick.width) flick.contentX = r.x + r.width - flick.width
                }
            }
        }
    }
}
