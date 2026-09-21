pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Локализация. `tr(key)` читает `lang`, поэтому любой биндинг с tr() сам
// перевычисляется при смене языка. ВСЕ пользовательские строки — только здесь:
// новый текст = ключ в обоих словарях (ru и en). Нет перевода — берётся en, затем сам ключ.
// Выбранный язык сохраняется в state-директории шелла.
Singleton {
    id: root

    property string lang: "ru"
    readonly property var langs: ["ru", "en"]
    readonly property string locale: lang === "ru" ? "ru_RU" : "en_US"

    function tr(key) { return dict[lang]?.[key] ?? dict.en[key] ?? key }
    function set(l) {
        if (!dict[l] || l === lang) return
        lang = l
        store.setText(l)
    }
    function toggle() { set(lang === "ru" ? "en" : "ru") }

    FileView {
        id: store
        path: Quickshell.statePath("lang")
        onLoaded: { const l = text().trim(); if (root.dict[l]) root.lang = l }
        onLoadFailed: {}
    }

    readonly property var dict: ({
        ru: {
            "menu.title.root": "Меню",
            "menu.title.apps": "Приложения",
            "menu.title.themes": "Тема",
            "menu.title.power": "Питание",
            "menu.title.lang": "Язык",

            "menu.apps": "Приложения",
            "menu.apps.hint": "Запустить программу",
            "menu.themes": "Тема",
            "menu.themes.hint": "Цвета и формы интерфейса",
            "menu.power": "Питание",
            "menu.power.hint": "Выключение, перезагрузка, блокировка",
            "menu.lang": "Язык",
            "menu.lang.hint": "Язык бара и окон",

            "theme.soft": "Мягкая",
            "theme.sharp": "Резкая",
            "theme.paper": "Бумага",

            "power.off": "Выключить",
            "power.reboot": "Перезагрузить",
            "power.suspend": "Спящий режим",
            "power.lock": "Заблокировать",

            "menu.config": "Конфигурация",
            "menu.config.hint": "Настройка бара",
            "menu.title.config": "Конфигурация",
            "menu.title.cfg.ws": "Воркспейсы",
            "menu.title.cfg.ws.icons": "Иконки",
            "menu.title.cfg.ws.icon": "Воркспейс",
            "menu.title.cfg.ws.app": "Приложение для",

            "cfg.ws": "Воркспейсы",
            "cfg.ws.hint": "Отображение, сворачивание, уведомления",
            "cfg.ws.style": "Стиль по умолчанию",
            "cfg.ws.style.hint": "Для воркспейсов без своей иконки",
            "cfg.ws.icons": "Иконки воркспейсов",
            "cfg.ws.icons.hint": "Свой значок для каждого воркспейса",
            "cfg.ws.collapsible": "Сворачивание",
            "cfg.ws.collapsible.hint": "Кнопка развернуть/свернуть",
            "cfg.ws.visible": "Видимых воркспейсов",
            "cfg.ws.visible.hint": "Сколько показывать в свёрнутом виде (←/→)",
            "cfg.ws.total": "Всего воркспейсов",
            "cfg.ws.total.hint": "Длина полного списка (←/→)",
            "cfg.ws.occupied": "Показывать занятые",
            "cfg.ws.occupied.hint": "Воркспейсы с окнами видны и в свёрнутом виде",
            "cfg.ws.notify": "Подсветка уведомлений",
            "cfg.ws.notify.hint": "Менять цвет, если окно на нём прислало уведомление",

            "style.dot": "Кружок",
            "style.number": "Цифра",
            "style.default": "По умолчанию",
            "style.app": "Иконка приложения…",
            "ws.n": "Воркспейс %1",

            "menu.title.cfg.notif": "Уведомления",
            "cfg.notif": "Уведомления",
            "cfg.notif.hint": "Очередь, время показа, анимация",
            "cfg.notif.max": "Одновременно на экране",
            "cfg.notif.max.hint": "Остальные ждут в очереди (←/→)",
            "cfg.notif.timeout": "Автоисчезание",
            "cfg.notif.timeout.hint": "Секунд до скрытия, 0 — никогда (←/→)",
            "cfg.notif.fade": "Анимация исчезновения",
            "cfg.notif.fade.hint": "Длительность затухания (←/→)",
            "cfg.notif.pauseall": "Пауза всех при наведении",
            "cfg.notif.pauseall.hint": "Пока курсор на любом уведомлении, таймеры всех стоят",
            "cfg.notif.test": "Тестовое уведомление",
            "cfg.notif.test.hint": "Показать пример",
            "cfg.notif.test.title": "Тестовое уведомление",
            "cfg.notif.test.body": "Так будет выглядеть уведомление в текущей теме",
            "unit.s": "с",
            "unit.ms": "мс",
            "value.never": "никогда",
            "lang.ru": "Русский",
            "lang.en": "English"
        },
        en: {
            "menu.title.root": "Menu",
            "menu.title.apps": "Applications",
            "menu.title.themes": "Theme",
            "menu.title.power": "Power",
            "menu.title.lang": "Language",

            "menu.apps": "Applications",
            "menu.apps.hint": "Launch a program",
            "menu.themes": "Theme",
            "menu.themes.hint": "Interface colors and shapes",
            "menu.power": "Power",
            "menu.power.hint": "Shutdown, reboot, lock",
            "menu.lang": "Language",
            "menu.lang.hint": "Bar and windows language",

            "theme.soft": "Soft",
            "theme.sharp": "Sharp",
            "theme.paper": "Paper",

            "power.off": "Shut down",
            "power.reboot": "Reboot",
            "power.suspend": "Suspend",
            "power.lock": "Lock",

            "menu.config": "Configuration",
            "menu.config.hint": "Bar settings",
            "menu.title.config": "Configuration",
            "menu.title.cfg.ws": "Workspaces",
            "menu.title.cfg.ws.icons": "Icons",
            "menu.title.cfg.ws.icon": "Workspace",
            "menu.title.cfg.ws.app": "App for",

            "cfg.ws": "Workspaces",
            "cfg.ws.hint": "Display, collapsing, notifications",
            "cfg.ws.style": "Default style",
            "cfg.ws.style.hint": "For workspaces without a custom icon",
            "cfg.ws.icons": "Workspace icons",
            "cfg.ws.icons.hint": "Custom icon per workspace",
            "cfg.ws.collapsible": "Collapsing",
            "cfg.ws.collapsible.hint": "Expand/collapse button",
            "cfg.ws.visible": "Visible workspaces",
            "cfg.ws.visible.hint": "Shown when collapsed (←/→)",
            "cfg.ws.total": "Total workspaces",
            "cfg.ws.total.hint": "Length of the full list (←/→)",
            "cfg.ws.occupied": "Show occupied",
            "cfg.ws.occupied.hint": "Workspaces with windows stay visible when collapsed",
            "cfg.ws.notify": "Notification highlight",
            "cfg.ws.notify.hint": "Recolor when a window there sends a notification",

            "style.dot": "Dot",
            "style.number": "Number",
            "style.default": "Default",
            "style.app": "Application icon…",
            "ws.n": "Workspace %1",

            "menu.title.cfg.notif": "Notifications",
            "cfg.notif": "Notifications",
            "cfg.notif.hint": "Queue, display time, animation",
            "cfg.notif.max": "On screen at once",
            "cfg.notif.max.hint": "The rest wait in a queue (←/→)",
            "cfg.notif.timeout": "Auto-hide",
            "cfg.notif.timeout.hint": "Seconds until hidden, 0 — never (←/→)",
            "cfg.notif.fade": "Fade-out animation",
            "cfg.notif.fade.hint": "Fade duration (←/→)",
            "cfg.notif.pauseall": "Pause all on hover",
            "cfg.notif.pauseall.hint": "Timers of all stop while the cursor is on any notification",
            "cfg.notif.test": "Test notification",
            "cfg.notif.test.hint": "Show a sample",
            "cfg.notif.test.title": "Test notification",
            "cfg.notif.test.body": "This is how notifications look in the current theme",
            "unit.s": "s",
            "unit.ms": "ms",
            "value.never": "never",
            "lang.ru": "Русский",
            "lang.en": "English"
        }
    })
}
