//@ pragma ShellId butler
//@ pragma UseQApplication
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

    // Нижняя панель окон — только в оконном режиме
    Variants {
        model: WinMode.windowed ? Quickshell.screens : []
        WindowDock {
            required property var modelData
            screen: modelData
        }
    }

    NotificationPopups {}
    OsdPopup {}

    LazyLoader {
        id: menuLoader
        Menu { initialPage: shell.menuPage; onClose: menuLoader.active = false }
    }

    LazyLoader {
        active: ConfigEditor.open
        ConfigEditorWindow { onClose: ConfigEditor.closeWindow() }
    }

    // qs -c butler ipc call configs open | close | toggle | section <id>
    IpcHandler {
        target: "configs"
        function open(): void { ConfigEditor.openWindow() }
        function close(): void { ConfigEditor.closeWindow() }
        function section(id: string): void { ConfigEditor.select(id); ConfigEditor.openWindow() }
        function toggle(): void { ConfigEditor.open ? ConfigEditor.closeWindow() : ConfigEditor.openWindow() }
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

    // qs -c butler ipc call winmode toggle | tiling | windowed | get | raise <addr> | minimize <addr> | unminimize <addr>
    IpcHandler {
        target: "winmode"
        function toggle(): void { WinMode.toggle() }
        function tiling(): void { WinMode.set("tiling") }
        function windowed(): void { WinMode.set("windowed") }
        function get(): string { return WinMode.mode }
        function raise(address: string): void { WinMode.raise(address) }
        function minimize(address: string): void { WinMode.minimize(address) }
        function unminimize(address: string): void { WinMode.unminimize(address) }
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
