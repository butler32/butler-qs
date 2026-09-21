import Quickshell
import Quickshell.Io
import "components"
import "theme"
import "i18n"

ShellRoot {
    Variants {
        model: Quickshell.screens
        Bar {
            required property var modelData
            screen: modelData
            onMenuRequested: menuLoader.active = true
        }
    }

    LazyLoader {
        id: menuLoader
        Menu { onClose: menuLoader.active = false }
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
        function toggle(): void { menuLoader.active = !menuLoader.active }
        function open(): void { menuLoader.active = true }
        function close(): void { menuLoader.active = false }
    }

    // qs -c butler ipc call i18n set ru|en | toggle | get
    IpcHandler {
        target: "i18n"
        function set(lang: string): void { I18n.set(lang) }
        function toggle(): void { I18n.toggle() }
        function get(): string { return I18n.lang }
    }
}
