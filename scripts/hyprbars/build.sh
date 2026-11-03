#!/bin/sh
# Собирает плагин hyprbars (заголовки окон в оконном режиме) под установленный Hyprland
# с патчем butler-buttons.patch (плоские кнопки с подсветкой для стиля Windows) и ставит
# libhyprbars.so в ~/.local/share/butler/hyprbars/. Плагин привязан к версии Hyprland:
# после обновления Hyprland запустите скрипт снова.
#
#   BUTLER_HYPRBARS_DEST=<dir>   куда положить .so (для проверки на копии)
#   BUTLER_HYPRBARS_TAG=<tag>    тег hyprland-plugins (по умолчанию v<major.minor>.0 от Hyprland)
set -e

REPO=$(cd "$(dirname "$0")/../.." && pwd)
DEST=${BUTLER_HYPRBARS_DEST:-$HOME/.local/share/butler/hyprbars}
VER=$(pkg-config --modversion hyprland)
TAG=${BUTLER_HYPRBARS_TAG:-v${VER%.*}.0}
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

for tool in git meson ninja pkg-config; do
    command -v "$tool" >/dev/null || { echo "нужен $tool (pacman -S meson ninja git)"; exit 1; }
done

echo "Hyprland $VER -> hyprland-plugins $TAG"
git clone --quiet --depth 1 --branch "$TAG" https://github.com/hyprwm/hyprland-plugins "$WORK/src"
git -C "$WORK/src" apply "$REPO/scripts/hyprbars/butler-buttons.patch"
# сборочный каталог — вне исходников (meson.build ищет *.cpp через find .)
meson setup "$WORK/build" "$WORK/src/hyprbars" >/dev/null
ninja -C "$WORK/build" >/dev/null
install -D "$WORK/build/libhyprbars.so" "$DEST/libhyprbars.so"
echo "готово: $DEST/libhyprbars.so"
