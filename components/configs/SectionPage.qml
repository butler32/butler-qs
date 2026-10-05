import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../i18n"
import "../../services"
import ".."

// Страница раздела: заголовок, пояснение и блоки из каталога (настройки или особые блоки).
Item {
    id: root
    required property string sectionId

    readonly property var sec: ConfigEditor.sections.find(s => s.id === sectionId) ?? ({ blocks: [] })
    readonly property var files: ({
        options: "OptionsBlock.qml", animations: "AnimationsBlock.qml", curves: "CurvesBlock.qml", monitors: "MonitorsBlock.qml",
        workspaces: "WorkspacesBlock.qml", devices: "DevicesBlock.qml", gestures: "GesturesBlock.qml", binds: "BindsBlock.qml",
        windowRules: "WindowRulesBlock.qml", autostart: "AutostartBlock.qml", env: "EnvBlock.qml", rawOptions: "RawOptionsBlock.qml",
        source: "SourceBlock.qml"
    })

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: col.implicitHeight + Theme.padding * 2
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        onContentHeightChanged: if (contentY > contentHeight - height) contentY = Math.max(0, contentHeight - height)

        ColumnLayout {
            id: col
            x: Theme.padding
            y: Theme.padding
            width: flick.width - Theme.padding * 2 - 8
            spacing: Theme.gap * 3

            ColumnLayout {
                spacing: 2
                Label { text: ConfigEditor.tx(root.sec.title); font.pixelSize: Theme.fontSize + 5; font.bold: true }
                Label { text: ConfigEditor.tx(root.sec.hint); color: Theme.textDim }
            }

            Repeater {
                model: root.sec.blocks
                delegate: Loader {
                    id: bl
                    required property var modelData
                    Layout.fillWidth: true
                    Component.onCompleted: setSource(root.files[modelData.type], modelData.type === "options" ? { block: modelData } : {})
                    onLoaded: item.width = Qt.binding(() => bl.width)
                }
            }
        }
    }

    Rectangle {
        visible: flick.contentHeight > flick.height
        x: parent.width - 5
        y: flick.visibleArea.yPosition * flick.height
        width: 3
        height: Math.max(20, flick.visibleArea.heightRatio * flick.height)
        radius: 2
        color: Theme.border
    }
}
