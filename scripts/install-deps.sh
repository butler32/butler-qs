#!/bin/bash
# install-deps.sh — installs everything the bar needs on Arch Linux (all packages are
# in the official repos), links the repo into ~/.config/quickshell/butler and, on
# request, enables the system services the widgets talk to.
#
# Run as a normal user; pacman is called through sudo. Safe to re-run: packages that
# are already installed are skipped.
#
# Usage:
#   scripts/install-deps.sh                  core + feature packages, asks before installing
#   scripts/install-deps.sh --optional       also the optional ones (VPN, media keys)
#   scripts/install-deps.sh --enable-services  enable NetworkManager, bluetooth, upower, power-profiles-daemon
#   scripts/install-deps.sh --yes            don't ask (pacman --noconfirm)
#   scripts/install-deps.sh --dry-run        only show what would be done
# Options can be combined.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LINK="$HOME/.config/quickshell/butler"

# package  — what needs it
CORE=(
    quickshell              # the shell itself (qs)
    qt6-declarative         # QML runtime
    qt6-wayland             # layer-shell windows
    qt6-svg                 # tray / app icons
    hyprland                # hyprctl, workspaces, windows, focus grab
    hyprlock                # Power -> Lock
    ttf-jetbrains-mono-nerd # theme font + all glyph icons
    networkmanager          # Network widget (nmcli)
    bluez                   # Bluetooth widget
    upower                  # Battery widget
    pipewire                # Volume / OSD
    wireplumber
    libnotify               # notify-send (screenshot and backup notifications)
    python                  # Claude usage widget
    xdg-user-dirs           # Screenshots folder
)
FEATURES=(
    grim                    # screenshots
    slurp                   # screenshot area / window picker
    wl-clipboard            # wl-copy / wl-paste: clipboard, calculator, screenshots
    cliphist                # clipboard history (Menu -> Clipboard)
    hyprsunset              # night light button
    power-profiles-daemon   # power profile widget
)
OPTIONAL=(
    openvpn                 # VPN section (see scripts/vpn/install.sh)
    playerctl               # media keys bindings
)
SERVICES=(NetworkManager.service bluetooth.service upower.service power-profiles-daemon.service)

with_optional=0 enable_services=0 assume_yes=0 dry=0
for a in "$@"; do
    case "$a" in
        --optional) with_optional=1 ;;
        --enable-services) enable_services=1 ;;
        --yes|-y) assume_yes=1 ;;
        --dry-run|-n) dry=1 ;;
        -h|--help) sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown option: $a (see --help)" >&2; exit 1 ;;
    esac
done

if [ "$(id -u)" -eq 0 ]; then
    echo "run as a normal user, not root (sudo is used where needed)" >&2
    exit 1
fi
command -v pacman >/dev/null || { echo "this script supports Arch Linux (pacman) only" >&2; exit 1; }

run() { if [ "$dry" = 1 ]; then echo "+ $*"; else "$@"; fi; }


pkgs=("${CORE[@]}" "${FEATURES[@]}")
[ "$with_optional" = 1 ] && pkgs+=("${OPTIONAL[@]}")

# GPU stats: NVIDIA needs nvidia-smi (nvidia-utils); AMD is read from sysfs, Intel iGPU
# has no load/temperature counters the monitor can use, so nothing to install there.
for v in /sys/class/drm/card*/device/vendor; do
    if [ -r "$v" ] && [ "$(cat "$v")" = "0x10de" ]; then
        pkgs+=(nvidia-utils)
        echo "NVIDIA GPU detected: adding nvidia-utils (nvidia-smi) for the GPU stats"
        break
    fi
done

missing=()
for p in "${pkgs[@]}"; do
    pacman -Qq "$p" >/dev/null 2>&1 || missing+=("$p")
done

if [ "${#missing[@]}" -eq 0 ]; then
    echo "all packages are already installed"
else
    echo "to install: ${missing[*]}"
    flags=(--needed)
    [ "$assume_yes" = 1 ] && flags+=(--noconfirm)
    run sudo pacman -S "${flags[@]}" "${missing[@]}"
fi

# ~/.config/quickshell/butler -> this repo, so `qs -c butler` works from anywhere
if [ -L "$LINK" ] && [ "$(readlink -f "$LINK")" = "$REPO_DIR" ]; then
    echo "link ok: $LINK"
elif [ -e "$LINK" ] || [ -L "$LINK" ]; then
    echo "skipped: $LINK already exists and points elsewhere" >&2
else
    run mkdir -p "$(dirname "$LINK")"
    run ln -s "$REPO_DIR" "$LINK"
    echo "linked $LINK -> $REPO_DIR"
fi

if [ "$enable_services" = 1 ]; then
    for s in "${SERVICES[@]}"; do run sudo systemctl enable --now "$s"; done
else
    echo "services are not touched; to enable NetworkManager, bluetooth, upower and power-profiles-daemon re-run with --enable-services"
fi

cat <<MSG

done. Start the bar with:  qs -c butler -d
Autostart (Hyprland, ~/.config/hypr/configs/autostart.lua):  qs -c butler -d
VPN (optional): sudo $REPO_DIR/scripts/vpn/install.sh
MSG
