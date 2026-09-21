//@ pragma ShellId butler
import Quickshell
import Quickshell.Io
import "components"
import "components/notifications"
import "theme"
import "i18n"
import "services"

ShellRoot {
    id: shell
    property string menuPage: "root"

    Variants {
        model: Quickshell.screens
        Bar {
            required property var modelData
            screen: modelData
            onMenuRequested: { shell.menuPage = "root"; menuLoader.active = true }
        }
    }

    NotificationPopups {}
    OsdPopup {}

    LazyLoader {
        id: menuLoader
        Menu { initialPage: shell.menuPage; onClose: menuLoader.active = false }
    }

    // qs -p . ipc call theme set sharp | cycle | get
    IpcHandler {
        target: "theme"
        function set(name: string): void { Theme.set(name) }
        function cycle(): void { Theme.cycle() }
        function get(): string { return Theme.name }
    }

    // qs -c butler ipc call menu toggle | open | close
    IpcHandler {
        target: "menu"
        function toggle(): void { shell.menuPage = "root"; menuLoader.active = !menuLoader.active }
        function open(): void { shell.menuPage = "root"; menuLoader.active = true }
        function page(id: string): void { menuLoader.active = false; shell.menuPage = id; menuLoader.active = true }
        function close(): void { menuLoader.active = false }
    }

    // qs -c butler ipc call osd event <brightness|capslock|volume|mic> <значение>
    IpcHandler {
        target: "osd"
        function event(kind: string, value: string): void { Osd.show(kind, value) }
    }

    // qs -c butler ipc call i18n set ru|en | toggle | get
    IpcHandler {
        target: "i18n"
        function set(lang: string): void { I18n.set(lang) }
        function toggle(): void { I18n.toggle() }
        function get(): string { return I18n.lang }
    }
}
