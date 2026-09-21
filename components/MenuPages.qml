import QtQuick
import Quickshell
import "../theme"
import "../i18n"

// Содержимое меню. Страница = массив пунктов; `build(id)` вызывается из Menu.qml
// внутри биндинга, так что страницы реактивны (список приложений, активная тема).
//
// Пункт:
//   name, comment   — текст
//   icon            — nerd-font глиф;  iconSource — url картинки (приоритетнее)
//   page            — id вложенной страницы (переход внутрь)
//   run()           — действие;  keepOpen — не закрывать меню после него
//   active          — показать галочку;  danger — красный глиф
//   keywords        — доп. слова для поиска
// Все тексты — через I18n.tr(key), ключи в обоих языках лежат в i18n/I18n.qml.
// Чтобы добавить раздел: пункт с `page: "foo"` в root() и `case "foo"` в build().
QtObject {
    function title(id) { return I18n.tr("menu.title." + id) }

    function build(id) {
        switch (id) {
        case "apps": return apps()
        case "themes": return themes()
        case "power": return power()
        case "lang": return langs()
        default: return root()
        }
    }

    function root() {
        return [
            { name: I18n.tr("menu.apps"), comment: I18n.tr("menu.apps.hint"), icon: "", page: "apps" },
            { name: I18n.tr("menu.themes"), comment: I18n.tr("menu.themes.hint"), icon: "", page: "themes" },
            { name: I18n.tr("menu.lang"), comment: I18n.tr("menu.lang.hint"), icon: "\uf0ac", page: "lang" },
            { name: I18n.tr("menu.power"), comment: I18n.tr("menu.power.hint"), icon: "", page: "power" }
        ]
    }

    function apps() {
        return DesktopEntries.applications.values
            .filter(e => !e.noDisplay)
            .sort((a, b) => a.name.localeCompare(b.name))
            .map(e => ({
                name: e.name,
                comment: e.comment ?? "",
                iconSource: Quickshell.iconPath(e.icon, "application-x-executable"),
                keywords: [e.genericName ?? "", ...(e.keywords ?? [])],
                run: () => e.execute()
            }))
    }

    function themes() {
        return Theme.names.map(n => ({
            name: I18n.tr("theme." + n),
            icon: "",
            active: Theme.name === n,
            keepOpen: true,   // применяется сразу, меню остаётся — удобно листать
            run: () => Theme.set(n)
        }))
    }

    function power() {
        return [
            { name: I18n.tr("power.off"), icon: "", danger: true, run: () => Quickshell.execDetached(["systemctl", "poweroff"]) },
            { name: I18n.tr("power.reboot"), icon: "", danger: true, run: () => Quickshell.execDetached(["systemctl", "reboot"]) },
            { name: I18n.tr("power.suspend"), icon: "", run: () => Quickshell.execDetached(["systemctl", "suspend"]) },
            { name: I18n.tr("power.lock"), icon: "", run: () => Quickshell.execDetached(["hyprlock"]) }
        ]
    }

    function langs() {
        return I18n.langs.map(l => ({
            name: I18n.tr("lang." + l),
            icon: "\uf0ac",
            active: I18n.lang === l,
            keepOpen: true,
            run: () => I18n.set(l)
        }))
    }
}
