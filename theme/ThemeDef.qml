import QtQuick

// Описание одной темы: цвета + токены формы. Добавляя новый токен сюда,
// не забудь пробросить его в Theme.qml.
QtObject {
    // --- цвета ---
    property color bg: "transparent"      // фон самого окна бара (обычно прозрачный)
    property color surface: "#1e1e2e"     // фон панелей
    property color surfaceAlt: "#313244"  // hover / треки / неактивные элементы
    property color border: "#45475a"
    property color text: "#cdd6f4"
    property color textDim: "#7f849c"
    property color accent: "#89b4fa"
    property color accentText: "#11111b"
    property color danger: "#f38ba8"
    property color warn: "#f9e2af"        // жёлтый порог (нагрузка, батарея)
    property color notify: "#fab387"      // воркспейс с уведомлением

    // --- формы ---
    property real radiusPanel: 14   // скругление «окон» бара
    property real radiusItem: 10    // кнопки/точки внутри панелей
    property real radiusTrack: 3    // слайдер микшера
    property real radiusPopup: 16   // всплывающие окна
    property real borderWidth: 1
    property real barHeight: 34     // высота панелей
    property real barMargin: 6      // отступ панелей от края экрана
    property real padding: 10       // внутренний отступ панелей
    property real gap: 8            // расстояние между панелями/элементами
    property real trackHeight: 6
    property real workspaceDot: 10  // размер неактивного воркспейса
    property real notifWidth: 360   // ширина уведомления
    property string notifFrame: "panel"  // форма окна уведомления: components/notifications/frames/<Имя>Frame.qml
    property real menuWidth: 520
    property real menuRows: 8   // видимых строк в лаунчере
    property real menuItem: 44  // высота строки лаунчера

    property string fontFamily: "JetBrainsMono Nerd Font"
    property real fontSize: 13
}
