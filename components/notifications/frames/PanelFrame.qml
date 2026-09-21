import QtQuick
import "../../../theme"

// Форма (фон) окна уведомления. Контракт для любой формы — файл `<Имя>Frame.qml`
// в этой папке, выбирается токеном темы `notifFrame`:
//   - Item, растягивается на всю карточку (размер задаёт NotificationCard);
//   - inset{Left,Top,Right,Bottom} — куда карточка вкладывает контент
//     (для «морды кота» это, например, увеличенный insetTop под уши);
//   - critical — срочное уведомление (форма может подсветиться).
// Форма рисует только фон/силуэт, контентом не занимается.
Item {
    property bool critical: false

    readonly property real insetLeft: Theme.padding
    readonly property real insetRight: Theme.padding
    readonly property real insetTop: Theme.padding
    readonly property real insetBottom: Theme.padding

    Rectangle {
        anchors.fill: parent
        color: Theme.surface
        radius: Theme.radiusPopup
        border.width: Theme.borderWidth
        border.color: critical ? Theme.danger : Theme.border
    }
}
