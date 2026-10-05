# CLAUDE.md

Personal Quickshell (QML) config for Hyprland: a bar plus a page-based main menu.
No build step or tests — it is declarative QML loaded by Quickshell.

## Running

On a fresh Arch machine run `scripts/install-deps.sh` first (`--optional` for VPN / media keys / NVIDIA stats, `--enable-services` to enable NetworkManager, bluetooth, upower and power-profiles-daemon, `--dry-run` to preview). It installs the packages, links the repo to `~/.config/quickshell/butler` and does not touch anything else. Keep its package lists in sync when a feature starts using a new external tool.

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
qs -c butler ipc call configs section binds   # open | close | toggle | section <id> — config editor window
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
- `services/` — `Calc` (calculator/unit converter for the menu search), `Clipboard` (cliphist history; the shell itself runs the `wl-paste --watch` pair), `NightLight` (hyprsunset process), `Screenshot` (+ `scripts/screenshot.sh`), `Windows`, `Notifs`: the notification daemon (`NotificationServer`) + on-screen queue (`shown` / `waiting`) + workspace notification marks + DND (`Config.notifications.dnd`, critical still shown) and `history` of plain snapshots. State only; drawing is in `components/notifications/`.
- `components/` also holds the bar widgets: `Workspaces`, `AppDock` (pinned app icons), `Media` (MPRIS), `Clock` (+`CalendarPopup`), `SysMon` (data: `services/SysStats` + `scripts/sysstat.sh`), `Network` (+`WifiRow`, `NetworkProfiles`, `NetworkProfileEditor`, `VpnSection`; nmcli logic in `services/NetInfo` for everything except VPN — the VPN button drives `butler-vpn.service`, a systemd unit installed separately (see `scripts/vpn/`) that runs OpenVPN plus an IPv6/LAN-scoped kill switch adapted from amnezia-client's Linux firewall; toggled via passwordless `sudo systemctl start/stop butler-vpn.service`, scoped by `scripts/vpn/sudoers-butler-vpn`; domains in `Config.network.vpnExcludedDomains`, edited in `VpnSection`, are resolved once at connect time and routed around the tunnel via a `/32` bypass route + kill-switch pinhole per IP), `Bluetooth` (+`BtDeviceRow`), `Battery`, `Language`, `Mixer` (icon + popup; `VolumeRow`, `DevicePicker`). Reusable UI blocks: `BarPopup`, `Chip`, `Field`, `Slider`.
- OSD: `services/Osd` (state; volume/mic follow PipeWire by themselves, brightness/Caps Lock arrive via `qs -c butler ipc call osd event <brightness|capslock> <value>` from `~/.config/hypr-theme/bin/osd-*`) + `components/OsdPopup`. Don't name an IPC function `show` — it collides with the `qs ipc show` subcommand.
- `services/ConfigEditor` — the config editor (Menu → Configs, a separate `FloatingWindow`, `components/ConfigEditorWindow.qml` + `components/configs/`). Currently only Hyprland (`~/.config/hypr`, Lua). It is organised **by meaning, not by file** (Windows, Appearance, Animations, Monitors, Workspaces, Keyboard and mouse, Shortcuts, Window rules, Autostart, Environment, System; "All options" and "Source files" are the expert escape hatches). Pieces: `LuaConf.js` (parses the Lua subset the configs use and edits the **source in place** by offsets, so comments/loops/unknown code are never lost), `ConfigCatalog.js` (**what the user sees**: section/page structure, human titles + hints in ru/en, control types, select lists, bind actions, animation leaves/styles, window-rule effects), `ConfigKinds.js` (record kinds + templates), `ConfigOptions.js` (**generated** from `/usr/share/hypr/stubs/hl.meta.lua` by `scripts/gen-config-schema.js`; re-run after a Hyprland update), `HyprInfo` (live `hyprctl` data for lists: monitors and their modes, open window classes, devices, xkb layouts, installed apps, current option defaults) and `ConfigDropdown` (state of the single dropdown that `DropdownLayer.qml` draws over the window). `ConfigSplit.js` splits a single-file config (stock `hyprland.lua`) into `configs/<role>.lua` + `require`s (banner shown in the window; locals with literal values become globals in `configs/programs.lua`, handle-locals travel with their users); new entries for a role file that does not exist go next to similar ones or create the file (`ensureFile`/`placeFile`). Keep `node scripts/split-test.js` green.
- `components/notifications/` — popup window, `NotificationCard`, and `frames/<Name>Frame.qml` (window shapes).
- `components/` — `Panel` (base "window" of the bar), `Label`, `Bar`, widgets (`Workspaces`, `Clock`, `Language`, `Mixer`), `Menu` (window + navigation), `MenuPages` (menu content).

Directories with a `qmldir` (`theme/`, `i18n/`) only expose the types listed there — register new types/singletons in it.

## Bar layout

- `Bar.qml` builds the widgets from `Config.bar.order` (ids + one `"|"` separator: left of it = left side) through `Loader` slots, so order/visibility/per-monitor hiding are config-driven (Menu → Configuration → Bar widgets). A new bar widget = `Panel` + a `Component` and id in `Bar.qml`'s `widgets` map + id in `Config.barWidgetIds` + `bar.w.<id>` key + icon in `MenuPages.barIcons`.
- Widgets hide themselves with `Panel.wanted` (never `visible:` on the root): the slot reads `wanted` so a hidden widget takes no space.
- `ClockGroup` = clock + tool buttons (DND / night light / screenshot) that appear on hover. Hover is tracked via the buttons' `MouseArea.containsMouse` and the group reserves width on both sides, because Qt Quick doesn't deliver hover to children outside the parent's bounds.
- Optional backends are detected once at startup (`command -v ...`): hyprsunset (night light), cliphist + wl-clipboard (clipboard), powerprofilesctl (power profile widget). Missing = the feature hides itself.

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
- Theme is a separate top-level menu entry; language lives in Configuration.

### Notification shapes (extensibility)
- The popup's shape is a **frame**: `components/notifications/frames/<Name>Frame.qml`, selected by the theme token `notifFrame` (`"panel"` → `PanelFrame.qml`). Contract is documented in `PanelFrame.qml` (fills the card, exposes `inset*` for content, `critical`). To add a new silhouette (e.g. a cat face), add a frame file and set `notifFrame` in a theme — don't special-case shapes in `NotificationCard`.
- Notification behaviour (queue size, timeout, fade) lives in `Config.notifications` and Menu → Configuration → Notifications. Critical notifications never auto-hide.

### Bar popups
- Widget popups are `BarPopup { anchorItem: root; screen: root.QsWindow.window?.screen ?? null; ipcName: "..." }` with content placed inside; open with `popup.toggle()` (not `open = !open`: it guards against the click that closes the popup re-opening it). Only one popup is open at a time (`services/Popups`).
- The main menu (`Menu.qml`) uses the same mechanism (own catcher, `OnDemand` + grab); any new overlay window that must close on outside click must too.
- Click-outside-to-close is done by a full-screen transparent "catcher" window on the `Top` layer under the popup (`Overlay`), plus `HyprlandFocusGrab`. The popup uses `keyboardFocus: OnDemand`, **not** `Exclusive` — with Exclusive, Hyprland doesn't deliver pointer clicks to other surfaces and outside-click closing silently stops working. The catcher starts below the reserved top area so all panels (ours and the other bar) stay clickable; the popup's top offset also comes from the monitor's `reserved` area, since Overlay ignores exclusive zones.
- Don't use `Shortcut` in windows (segfaults on hot reload); Esc is handled via `Keys.onEscapePressed`.
- Popups are addressable over IPC for testing: `qs -c butler ipc call popup.<clock|network|bluetooth|battery|mixer> toggle`.
- Don't use `Quickshell.Networking` (0.3.0): it segfaulted the whole shell right after NetworkManager's "Access point removed" while our Wi-Fi list held its objects. Wi-Fi/IP data comes from `nmcli` via `services/NetInfo` as plain JS objects. In general, prefer plain snapshots over QObject lists from Quickshell services in `ScriptModel`/`Repeater` delegates. Also note: V4 JS has no regex lookbehind.
- Network profiles are applied with `nmcli` (`services/NetInfo`); never test-apply against the live connection — use a throwaway `nmcli connection add ... autoconnect no` profile.

### Config editor (Menu → Configs)
- **The UI must be usable without knowing Hyprland's field names.** Never show a raw option name as the label: every setting gets a human title and a hint in `ConfigCatalog.js`, and anything that is a choice (monitor, mode, curve, style, key, action, workspace, window class, app, layout…) is a **select from a list**, not a text field; free text only where unavoidable (a command, a regex). Options without a catalog entry exist only on the "All options" page.
- Catalog texts are `{ru, en}` pairs resolved by `ConfigEditor.tx()` (reads `I18n.lang`, so it is reactive) — the one exception to "every string in `I18n.qml`"; chrome/labels of the editor itself still use `I18n.tr("cfged.*")`. Add both languages for every catalog entry.
- Forms never rewrite a file from a model: they patch literal nodes via `LuaConf.js` and every form edit must still parse (`ConfigEditor.commit` rejects it otherwise). Keep `node scripts/luaconf-test.js` (round-trips insert/remove/identity edits over `~/.config/hypr/**/*.lua`, checked with `luajit -bl`) and `node scripts/catalog-check.js` (every catalog option exists in the Hyprland schema, has ru+en text) green.
- Save = backup into `<state>/config-backups/` → write → `hyprctl reload` → `hyprctl configerrors`; non-empty output = error with an "Undo save" button. Files regenerated by the theme (`theme_colors.lua`, `hyprlock.conf`) are `generated: true` = read only.
- To test on a copy instead of the live config: `BUTLER_HYPR_DIR=<copy> qs -c butler -d` (reload/configerrors still talk to the real Hyprland). **Never drive the UI with ydotool without checking the editor window exists first** — a hot reload closes it, and typed text/clicks then land on the real desktop (the helper must abort if the window is missing). The ydotool socket path must be short (`/tmp/ydotool.sock`; sun_path is limited to 108 bytes). Dropdowns with search take typed text + Enter (first match).
- QML forbids a component instantiating itself statically: lazily built blocks/rows go through `Loader.setSource`. Don't write QML properties from functions called by bindings (binding loop) — use fields of a plain object. `QtQuick.Controls.Popup` has no Overlay in a Quickshell window, hence `DropdownLayer`.
- New program = a provider entry in `ConfigEditor.providers` (+ its parser/catalog); the section/page machinery is per provider.

### Menu
- Content lives in `MenuPages.qml`: a page is a function returning items (`name`, `comment`, `icon`/`iconSource`, `page`, `run`, `keepOpen`, `active`, `danger`, `keywords`, plus `value`/`adjust` for ←/→ settings and `backAfter`). Page ids may carry an argument: `cfg.ws.icon:5`. Add a section with a `page: "id"` item in `root()`, a `case` in `build()` and a `menu.title.<id>` key.

### QML gotchas
- Don't put anchored children (e.g. a full-size `MouseArea`) directly into a `Panel`: its content goes into a `RowLayout`. Use `overlay: MouseArea { ... }` instead.
- Icons are Nerd Font glyphs written as `\uXXXX` (4 hex digits only — stay within the BMP, e.g. FontAwesome `\uf0xx`).
- Wrap `Text` in the project's `Label` to inherit theme font and color.

### Hyprland
- Hyprland ≥ 0.55 uses a Lua config. `Hyprland.dispatch()` takes a Lua expression: `Hyprland.dispatch("hl.dsp.focus({ workspace = 3 })")`, not the old `"workspace 3"` syntax.
- Autostart: `qs -c butler -d` in `~/.config/hypr/configs/autostart.lua` (replaced ags `mybar` and `notifd`; the ags launcher is still used by `SUPER+R` and is not replaced; the ags OSD was replaced by the qs OSD).
- The Hyprland config lives in `~/.config/hypr` (binds in `configs/keybindings.lua`, use the `unless_dota(...)` wrapper like the other binds).

## Git

- Commit messages in English, Conventional Commits (`feat`, `fix`, `refactor`, `docs`, `chore`, …) with an optional scope (`feat(menu): …`).
- Split changes into separate commits by meaning (theme / i18n / bar / menu / shell), not one big commit.
- Commits are signed through the 1Password SSH agent; if it is locked, ask the user to unlock it instead of disabling signing.
