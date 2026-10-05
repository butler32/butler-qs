import QtQuick
import QtQuick.Layouts
import Quickshell
import "../theme"
import "../i18n"
import "../services"
import "configs"

// Отдельное окно редактора конфигов (см. services/ConfigEditor). Слева — секции программы и файлы,
// справа — формы секции или исходник файла, внизу — статус и Сохранить / Откатить.
FloatingWindow {
    id: win
    signal close()

    readonly property string sec: ConfigEditor.section
    readonly property int dirtyCount: ConfigEditor.dirtyList().length

    function statusText() {
        switch (ConfigEditor.status) {
        case "saving": return I18n.tr("cfged.saving")
        case "ok": return I18n.tr("cfged.saved")
        case "error": return I18n.tr("cfged.error")
        case "rejected": return I18n.tr("cfged.rejected")
        case "backupfailed": return I18n.tr("cfged.backupfailed")
        }
        return dirtyCount > 0 ? I18n.tr("cfged.unsaved") + ": " + dirtyCount : ""
    }

    title: I18n.tr("cfged.title")
    implicitWidth: 1100
    implicitHeight: 720
    color: Theme.bg
    onVisibleChanged: if (!visible) win.close()

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: win.close()
        Keys.onPressed: event => {
            if (event.key === Qt.Key_S && (event.modifiers & Qt.ControlModifier)) {
                ConfigEditor.save()
                event.accepted = true
            }
        }

        DropdownLayer {}

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.padding
            spacing: Theme.gap

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Theme.gap

                // ── боковая панель ───────────────────────────────────────────
                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 230
                    radius: Theme.radiusPanel
                    color: Theme.surface
                    clip: true

                    Flickable {
                        id: sideFlick
                        anchors.fill: parent
                        anchors.margins: Theme.padding
                        contentWidth: width
                        contentHeight: side.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        ColumnLayout {
                            id: side
                            width: sideFlick.width
                            spacing: 2

                            Label {
                                text: ConfigEditor.current().icon + "  Hyprland"
                                color: Theme.accent
                                font.bold: true
                                Layout.bottomMargin: 4
                            }
                            Repeater {
                                model: ConfigEditor.sections
                                delegate: SideItem {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    label: ConfigEditor.tx(modelData.title)
                                    selected: win.sec === modelData.id
                                    onPicked: ConfigEditor.select(modelData.id)
                                }
                            }
                        }
                    }
                }

                // ── содержимое ───────────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.radiusPanel
                    color: Theme.surface
                    clip: true

                    Loader {
                        anchors.fill: parent
                        anchors.margins: Theme.padding / 2
                        sourceComponent: sectionC
                    }
                }
            }

            // ── ошибки hyprctl configerrors ──────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(errText.implicitHeight + Theme.padding, 110)
                visible: ConfigEditor.status === "error" && ConfigEditor.statusDetail !== ""
                radius: Theme.radiusItem
                color: Theme.surface
                border.width: 1
                border.color: Theme.danger
                clip: true
                TextEdit {
                    id: errText
                    anchors.fill: parent
                    anchors.margins: Theme.padding / 2
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    text: ConfigEditor.statusDetail
                    color: Theme.danger
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                }
            }

            // ── подвал ───────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.gap

                Label {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: win.statusText()
                    color: ConfigEditor.status === "error" || ConfigEditor.status === "rejected" || ConfigEditor.status === "backupfailed"
                           ? Theme.danger : ConfigEditor.status === "ok" ? Theme.accent : Theme.textDim
                }
                Chip {
                    visible: ConfigEditor.status === "error"
                    text: I18n.tr("cfged.undo")
                    onClicked: ConfigEditor.undoSave()
                }
                Chip {
                    text: I18n.tr("cfged.revert")
                    enabled: win.dirtyCount > 0 && !ConfigEditor.busy
                    onClicked: ConfigEditor.revert()
                }
                Chip {
                    icon: ""
                    text: I18n.tr("cfged.save")
                    accent: true
                    enabled: win.dirtyCount > 0 && !ConfigEditor.busy
                    onClicked: ConfigEditor.save()
                }
            }
        }
    }

    Component { id: sectionC; SectionPage { sectionId: win.sec } }

    // пункт боковой панели
    component SideItem: Rectangle {
        id: si
        property string label
        property string marker
        property bool selected
        property bool mono: false
        signal picked()

        implicitHeight: Theme.menuItem - 6
        radius: Theme.radiusItem
        color: selected ? Theme.accent : (area.containsMouse ? Theme.surfaceAlt : "transparent")
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 8
            Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: si.label
                color: si.selected ? Theme.accentText : Theme.text
                font.pixelSize: si.mono ? Theme.fontSize - 1 : Theme.fontSize
            }
            Label {
                visible: si.marker !== ""
                text: si.marker
                color: si.selected ? Theme.accentText : Theme.textDim
                font.pixelSize: Theme.fontSize - 2
            }
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: si.picked()
        }
    }
}
