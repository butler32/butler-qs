#!/bin/bash
# install.sh — подключает оконный режим к конфигу Hyprland (docs/window-mode.md).
# Работает от обычного пользователя (без sudo), идемпотентен, всё меняемое сначала копируется
# в <state>/winmode-backups/.
#
#   1. ~/.config/hypr/configs/winmode.lua -> scripts/hypr/winmode.lua (симлинк)
#   2. require("configs.winmode") в конец ~/.config/hypr/hyprland.lua (после правил окон)
#   3. привязки смены воркспейсов в keybindings.lua оборачиваются в WM_GUARD(...)
#   4. --bars: собирает плагин hyprbars (заголовки окон macOS / Windows), см. scripts/hyprbars/build.sh
#
# Использование:
#   scripts/winmode/install.sh [--bars] [--dry-run]
#   scripts/winmode/install.sh --uninstall      убрать пункты 1–3 (плагин и состояние не трогает)
#   BUTLER_HYPR_DIR=<каталог>                   другой каталог конфига Hyprland (по умолчанию ~/.config/hypr)
set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
HYPR=${BUTLER_HYPR_DIR:-$HOME/.config/hypr}
STATE=${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/by-shell/butler
BACKUPS=$STATE/winmode-backups
LINK=$HYPR/configs/winmode.lua
MAIN=$HYPR/hyprland.lua
KEYS=$HYPR/configs/keybindings.lua
REQ='require("configs.winmode")'

bars=0 dry=0 uninstall=0
for a in "$@"; do
    case "$a" in
        --bars) bars=1 ;;
        --dry-run|-n) dry=1 ;;
        --uninstall) uninstall=1 ;;
        -h|--help) sed -n 2,15p "$0"; exit 0 ;;
        *) echo "unknown option: $a" >&2; exit 2 ;;
    esac
done

run() { if [ "$dry" = 1 ]; then echo "+ $*"; else "$@"; fi; }
backup() { run mkdir -p "$BACKUPS"; run cp -a "$1" "$BACKUPS/$(basename "$1").$(date +%Y%m%d-%H%M%S)"; }

[ -f "$MAIN" ] || { echo "нет $MAIN — Hyprland ≥ 0.55 с Lua-конфигом (hyprland.lua) обязателен" >&2; exit 1; }
[ -f "$KEYS" ] || { echo "нет $KEYS — сначала разнесите конфиг по файлам (Меню → Конфиги → Исходные файлы)" >&2; exit 1; }
command -v node >/dev/null || { echo "нужен node (pacman -S nodejs)" >&2; exit 1; }

if [ "$uninstall" = 1 ]; then
    [ -L "$LINK" ] && run rm "$LINK"
    if grep -qF "$REQ" "$MAIN"; then backup "$MAIN"; run sed -i "\#^$REQ\$#d" "$MAIN"; fi
    backup "$KEYS"; run node "$REPO/scripts/winmode/patch-keybindings.js" "$KEYS" --undo
    echo "убрано. Режим окон сам по себе (winmode.mode) остаётся: перед удалением переключитесь в тайлинг."
    echo "Применить: hyprctl reload"
    exit 0
fi

# 1. симлинк на Lua-часть
if [ -L "$LINK" ] && [ "$(readlink -f "$LINK")" = "$REPO/scripts/hypr/winmode.lua" ]; then
    echo "link ok: $LINK"
elif [ -e "$LINK" ] || [ -L "$LINK" ]; then
    echo "пропущено: $LINK уже существует и указывает не сюда" >&2
else
    run ln -s "$REPO/scripts/hypr/winmode.lua" "$LINK"
    echo "linked $LINK"
fi

# 2. require — последним: правило winmode-float должно идти после остальных правил окон
if grep -qF "$REQ" "$MAIN"; then
    echo "require ok: $MAIN"
else
    backup "$MAIN"
    if [ "$dry" = 1 ]; then echo "+ append $REQ to $MAIN"; else printf '%s\n' "$REQ" >> "$MAIN"; fi
    echo "added $REQ to $MAIN (должен оставаться последним require)"
fi

# 3. блокировка воркспейсов в оконном режиме
backup "$KEYS"
if [ "$dry" = 1 ]; then cp "$KEYS" "${TMPDIR:-/tmp}/kb-dry.lua"; node "$REPO/scripts/winmode/patch-keybindings.js" "${TMPDIR:-/tmp}/kb-dry.lua"; rm -f "${TMPDIR:-/tmp}/kb-dry.lua"
else node "$REPO/scripts/winmode/patch-keybindings.js" "$KEYS"; fi

# 4. заголовки окон
if [ "$bars" = 1 ]; then
    run "$REPO/scripts/hyprbars/build.sh"
else
    echo "заголовки окон (необязательно): $0 --bars"
fi

cat <<MSG

готово. Дальше:
  hyprctl reload                         # подхватить конфиг
  qs -c butler ipc call winmode toggle   # или кнопка в баре (Меню → Конфигурация → Виджеты бара → «Оконный режим»)
Заголовки: Меню → Конфигурация → Оконный режим → «Заголовки окон» (нужен --bars; после обновления Hyprland запустите --bars снова).
Убрать: $0 --uninstall
MSG
