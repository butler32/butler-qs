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

To check visuals: `grim -g "X,Y WxH" file.png` and read the image.

## Layout

- `shell.qml` — entry point: a `Bar` per screen, `LazyLoader` for the menu, IPC handlers.
- `theme/` — `Theme` singleton (all style tokens) + `ThemeDef` (one theme's values). Themes are `ThemeDef` blocks inside `Theme.qml`.
- `i18n/` — `I18n` singleton with the `ru` / `en` dictionaries. Language is persisted via `Quickshell.statePath("lang")`.
- `config/` — `Config` singleton: persisted bar settings (JSON in the shell state dir). Edited only through the menu.
- `services/` — background services (`Notifs`: marks workspaces whose apps sent notifications, via passive `dbus-monitor`, so it never competes with a notification daemon).
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
