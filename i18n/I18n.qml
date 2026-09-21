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

            "lang.ru": "Русский",
            "lang.en": "English"
        }
    })
}
