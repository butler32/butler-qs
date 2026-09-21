# CLAUDE.md

Personal Quickshell (QML) config for Hyprland: a bar plus a page-based main menu.
No build step or tests — it is declarative QML loaded by Quickshell.

## Running

The repo is symlinked as `~/.config/quickshell/butler`, so run it by name from anywhere
(`-p .` only works from this directory):

```
qs -c butler -d                            # start in background
qs -c butler kill                          # stop (restart after edits if hot reload misses)
qs -c butler log | grep -E "WARN|ERROR"    # check for errors after every change
qs -c butler ipc call menu toggle          # open | close  (bound to SUPER+space in ~/.config/hypr)
qs -c butler ipc call menu page cfg.ws     # open straight on a page (handy for screenshots)
qs -c butler ipc call theme set sharp      # soft | sharp | paper | cycle | get
qs -c butler ipc call i18n set en          # ru | en | toggle | get
```

Settings and language live in `~/.local/state/quickshell/by-shell/butler/` — the shell ID is pinned by `//@ pragma ShellId butler` in `shell.qml`, so state is shared no matter how it is launched (`-c butler`, `-p <path>`). Never remove that pragma: without it every launch path gets its own state dir and settings appear to reset.

Process names are `qs` (daemon launcher) and `quickshell`; to kill everything use `pkill -x qs; pkill -x quickshell` (`qs kill` only stops one instance, and a hot-reload crash auto-restarts another copy — check `pgrep -a qs` before restarting, or you get stacked bars).

To test interactions: `ydotoold --socket-path=/tmp/ydotool.sock &` then `YDOTOOL_SOCKET=/tmp/ydotool.sock ydotool click 0xC0` (left click at the current cursor; move it with `hyprctl dispatch 'hl.dsp.cursor.move({ x = .., y = .. })'`, Esc is `ydotool key 1:1 1:0`). This clicks on the real desktop — restore workspace/focus afterwards.

To check visuals: `grim -g "X,Y WxH" file.png` and read the image.

## Layout

- `shell.qml` — entry point: a `Bar` per screen, `LazyLoader` for the menu, IPC handlers.
- `theme/` — `Theme` singleton (all style tokens) + `ThemeDef` (one theme's values). Themes are `ThemeDef` blocks inside `Theme.qml`.
- `i18n/` — `I18n` singleton with the `ru` / `en` dictionaries. Language is persisted via `Quickshell.statePath("lang")`.
- `config/` — `Config` singleton: persisted bar settings (JSON in the shell state dir). Edited only through the menu.
- `services/` — `Notifs`: the notification daemon (`NotificationServer`) + on-screen queue (`shown` / `waiting`) + workspace notification marks. State only; drawing is in `components/notifications/`.
- `components/` also holds the bar widgets: `Workspaces`, `AppDock` (pinned app icons), `Media` (MPRIS), `Clock` (+`CalendarPopup`), `SysMon` (data: `services/SysStats` + `scripts/sysstat.sh`), `Network` (+`WifiRow`, `NetworkProfiles`, `NetworkProfileEditor`; nmcli logic in `services/NetInfo`), `Bluetooth` (+`BtDeviceRow`), `Battery`, `Language`, `Mixer`. Reusable UI blocks: `BarPopup`, `Chip`, `Field`.
- `components/notifications/` — popup window, `NotificationCard`, and `frames/<Name>Frame.qml` (window shapes).
- `components/` — `Panel` (base "window" of the bar), `Label`, `Bar`, widgets (`Workspaces`, `Clock`, `Language`, `Mixer`), `Menu` (window + navigation), `MenuPages` (menu content).

Directories with a `qmldir` (`theme/`, `i18n/`) only expose the types listed there — register new types/singletons in it.

## Rules

### Theming (must stay reactive)
- Never hardcode colors, radii, sizes, borders or spacing in components. Read them from `Theme.*`.
- A theme changes both colors and **shapes** (radii, border width, gaps, heights). New visual tokens go into `ThemeDef.qml`, are forwarded in `Theme.qml` with a `Behavior` animation, and given values in every theme.
- Build bar "windows" on `Panel`, so shape changes stay in one place.
- Every theme needs a `theme.<name>` key in both languages (shown in the menu).

### Localization (ru + en)
- Every user-visible string goes through `I18n.tr("key")`; add the key to **both** `ru` and `en` in `i18n/I18n.qml`. No hardcoded text in components.
- Use `tr()` inside bindings/functions called from bindings so it updates on language change. Dates use `Qt.locale(I18n.locale)`.
- Text that comes from the system (keyboard layout names, .desktop entries) is not translated.

### Configuration (all bar settings go through the menu)
- **Every configurable option must be reachable and editable in Menu → Configuration → <section>**, and persisted in `Config` (`config/Config.qml`). No settings hardcoded as constants in widgets, no separate config files or ad-hoc IPC-only toggles.
- Adding an option = field in `Config.qml` + item in `MenuPages.qml` (`cfg*` pages; `toggleItem` / `numberItem` helpers, or a page for choices) + `cfg.*` keys in both languages + the widget reading `Config.<section>`.
- Widgets must react to `Config` changes live (bind to it, don't copy values once).
- Theme and language are separate top-level menu entries.

### Notification shapes (extensibility)
- The popup's shape is a **frame**: `components/notifications/frames/<Name>Frame.qml`, selected by the theme token `notifFrame` (`"panel"` → `PanelFrame.qml`). Contract is documented in `PanelFrame.qml` (fills the card, exposes `inset*` for content, `critical`). To add a new silhouette (e.g. a cat face), add a frame file and set `notifFrame` in a theme — don't special-case shapes in `NotificationCard`.
- Notification behaviour (queue size, timeout, fade) lives in `Config.notifications` and Menu → Configuration → Notifications. Critical notifications never auto-hide.

### Bar popups
- Widget popups are `BarPopup { anchorItem: root; screen: root.QsWindow.window?.screen ?? null; ipcName: "..." }` with content placed inside; open with `popup.toggle()` (not `open = !open`: it guards against the click that closes the popup re-opening it). Only one popup is open at a time (`services/Popups`).
- Click-outside-to-close is done by a full-screen transparent "catcher" window on the `Top` layer under the popup (`Overlay`), plus `HyprlandFocusGrab`. The popup uses `keyboardFocus: OnDemand`, **not** `Exclusive` — with Exclusive, Hyprland doesn't deliver pointer clicks to other surfaces and outside-click closing silently stops working. The catcher starts below the reserved top area so all panels (ours and the other bar) stay clickable; the popup's top offset also comes from the monitor's `reserved` area, since Overlay ignores exclusive zones.
- Don't use `Shortcut` in windows (segfaults on hot reload); Esc is handled via `Keys.onEscapePressed`.
- Popups are addressable over IPC for testing: `qs -c butler ipc call popup.<clock|network|bluetooth|battery> toggle`.
- Don't use `Quickshell.Networking` (0.3.0): it segfaulted the whole shell right after NetworkManager's "Access point removed" while our Wi-Fi list held its objects. Wi-Fi/IP data comes from `nmcli` via `services/NetInfo` as plain JS objects. In general, prefer plain snapshots over QObject lists from Quickshell services in `ScriptModel`/`Repeater` delegates. Also note: V4 JS has no regex lookbehind.
- Network profiles are applied with `nmcli` (`services/NetInfo`); never test-apply against the live connection — use a throwaway `nmcli connection add ... autoconnect no` profile.

### Menu
- Content lives in `MenuPages.qml`: a page is a function returning items (`name`, `comment`, `icon`/`iconSource`, `page`, `run`, `keepOpen`, `active`, `danger`, `keywords`, plus `value`/`adjust` for ←/→ settings and `backAfter`). Page ids may carry an argument: `cfg.ws.icon:5`. Add a section with a `page: "id"` item in `root()`, a `case` in `build()` and a `menu.title.<id>` key.

### QML gotchas
- Don't put anchored children (e.g. a full-size `MouseArea`) directly into a `Panel`: its content goes into a `RowLayout`. Use `overlay: MouseArea { ... }` instead.
- Icons are Nerd Font glyphs written as `\uXXXX` (4 hex digits only — stay within the BMP, e.g. FontAwesome `\uf0xx`).
- Wrap `Text` in the project's `Label` to inherit theme font and color.

### Hyprland
- Hyprland ≥ 0.55 uses a Lua config. `Hyprland.dispatch()` takes a Lua expression: `Hyprland.dispatch("hl.dsp.focus({ workspace = 3 })")`, not the old `"workspace 3"` syntax.
- The Hyprland config lives in `~/.config/hypr` (binds in `configs/keybindings.lua`, use the `unless_dota(...)` wrapper like the other binds).

## Git

- Commit messages in English, Conventional Commits (`feat`, `fix`, `refactor`, `docs`, `chore`, …) with an optional scope (`feat(menu): …`).
- Split changes into separate commits by meaning (theme / i18n / bar / menu / shell), not one big commit.
- Commits are signed through the 1Password SSH agent; if it is locked, ask the user to unlock it instead of disabling signing.
