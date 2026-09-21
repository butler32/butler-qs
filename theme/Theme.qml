pragma Singleton
import QtQuick
import Quickshell

// Синглтон, через который компоненты читают стили. Все токены — обычные
// property, привязанные к `current`, поэтому смена `name` мгновенно
// перестраивает весь UI, а Behavior'ы плавно анимируют переход
// (и цвета, и формы).
Singleton {
    id: root

    property string name: "soft"
    readonly property var names: Object.keys(registry)
    readonly property var registry: ({ soft: soft, sharp: sharp, paper: paper })
    readonly property ThemeDef current: registry[name] ?? soft

    function set(n) { if (registry[n]) name = n }
    function cycle() {
        const i = names.indexOf(name)
        name = names[(i + 1) % names.length]
    }

    // ---- цвета ----
    readonly property int _ms: 250
    property color bg: current.bg
    property color surface: current.surface
    property color surfaceAlt: current.surfaceAlt
    property color border: current.border
    property color text: current.text
    property color textDim: current.textDim
    property color accent: current.accent
    property color accentText: current.accentText
    property color danger: current.danger
    property color notify: current.notify
    Behavior on surface { ColorAnimation { duration: root._ms } }
    Behavior on surfaceAlt { ColorAnimation { duration: root._ms } }
    Behavior on border { ColorAnimation { duration: root._ms } }
    Behavior on text { ColorAnimation { duration: root._ms } }
    Behavior on textDim { ColorAnimation { duration: root._ms } }
    Behavior on accent { ColorAnimation { duration: root._ms } }
    Behavior on accentText { ColorAnimation { duration: root._ms } }
    Behavior on danger { ColorAnimation { duration: root._ms } }
    Behavior on notify { ColorAnimation { duration: root._ms } }

    // ---- формы ----
    property real radiusPanel: current.radiusPanel
    property real radiusItem: current.radiusItem
    property real radiusTrack: current.radiusTrack
    property real radiusPopup: current.radiusPopup
    property real borderWidth: current.borderWidth
    property real barHeight: current.barHeight
    property real barMargin: current.barMargin
    property real padding: current.padding
    property real gap: current.gap
    property real trackHeight: current.trackHeight
    property real workspaceDot: current.workspaceDot
    property real menuWidth: current.menuWidth
    property real menuRows: current.menuRows
    property real menuItem: current.menuItem
    property real fontSize: current.fontSize
    property string fontFamily: current.fontFamily
    Behavior on radiusPanel { NumberAnimation { duration: root._ms; easing.type: Easing.OutCubic } }
    Behavior on radiusItem { NumberAnimation { duration: root._ms; easing.type: Easing.OutCubic } }
    Behavior on radiusTrack { NumberAnimation { duration: root._ms; easing.type: Easing.OutCubic } }
    Behavior on radiusPopup { NumberAnimation { duration: root._ms; easing.type: Easing.OutCubic } }
    Behavior on borderWidth { NumberAnimation { duration: root._ms } }
    Behavior on barHeight { NumberAnimation { duration: root._ms } }
    Behavior on barMargin { NumberAnimation { duration: root._ms } }
    Behavior on padding { NumberAnimation { duration: root._ms } }
    Behavior on gap { NumberAnimation { duration: root._ms } }
    Behavior on trackHeight { NumberAnimation { duration: root._ms } }
    Behavior on menuWidth { NumberAnimation { duration: root._ms } }
    Behavior on menuItem { NumberAnimation { duration: root._ms } }
    Behavior on workspaceDot { NumberAnimation { duration: root._ms } }

    // ---- темы ----
    ThemeDef { id: soft }   // значения по умолчанию из ThemeDef

    ThemeDef {
        id: sharp
        surface: "#0d0d0d"; surfaceAlt: "#1f1f1f"; border: "#e6e6e6"
        text: "#f2f2f2"; textDim: "#808080"
        accent: "#ffd60a"; accentText: "#000000"; danger: "#ff453a"; notify: "#ff6b00"
        radiusPanel: 0; radiusItem: 0; radiusTrack: 0; radiusPopup: 0
        borderWidth: 2; barHeight: 30; barMargin: 0; padding: 12; gap: 0
        trackHeight: 4; workspaceDot: 12
        menuWidth: 600; menuRows: 10; menuItem: 34
    }

    ThemeDef {
        id: paper
        surface: "#f5efe6"; surfaceAlt: "#e3d9c8"; border: "#b9a98c"
        text: "#3b3226"; textDim: "#9a8b73"
        accent: "#c0562f"; accentText: "#fffaf2"; danger: "#a4262c"; notify: "#2e7d6b"
        radiusPanel: 20; radiusItem: 20; radiusTrack: 8; radiusPopup: 24
        borderWidth: 0; barHeight: 38; barMargin: 8; padding: 14; gap: 10
        trackHeight: 10; workspaceDot: 8
        menuWidth: 480; menuRows: 7; menuItem: 48
    }
}
