#!/bin/bash
# install.sh — installs butler-vpn.service (OpenVPN + IPv6/LAN-scoped kill
# switch) system-wide. See butler-vpn-up.sh for what it actually does and why.
#
# Portable across machines: run with sudo from inside a checkout of this repo,
# on any machine that has an OpenVPN config at ~/vpn/germany/openvpn_full.ovpn
# for the invoking user. Auto-detects that user (via $SUDO_USER) and their home
# directory — nothing here is hardcoded to one username or one machine.
#
# Idempotent: safe to re-run any time (e.g. after `git pull`) to pick up script
# updates — every step overwrites in place, nothing accumulates.
#
# This script does NOT start or enable anything. It only installs files. See
# the summary it prints at the end for what to do next.
#
# Usage:
#   sudo ./install.sh              install / update
#   sudo ./install.sh --uninstall  remove everything this script installed
#                                  (stops the service first if it's running)

set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPT_DIR="/opt/butler-vpn"
UNIT_PATH="/etc/systemd/system/butler-vpn.service"
SUDOERS_PATH="/etc/sudoers.d/butler-vpn"
SYSTEMCTL="/usr/bin/systemctl"
VISUDO="/usr/sbin/visudo"

if [ "$(id -u)" -ne 0 ]; then
    echo "run this with sudo: sudo $0 ${*:-}" >&2
    exit 1
fi

# We need the *invoking* user (for the sudoers rule and their home directory),
# not root — that's only available via $SUDO_USER, i.e. only when actually
# invoked through `sudo`, not from an already-root shell.
TARGET_USER="${SUDO_USER:-}"
if [ -z "$TARGET_USER" ] || [ "$TARGET_USER" = "root" ]; then
    echo "could not determine which user to install this for — run via 'sudo $0', not from a root shell" >&2
    exit 1
fi
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
if [ -z "$TARGET_HOME" ] || [ ! -d "$TARGET_HOME" ]; then
    echo "could not resolve a home directory for user $TARGET_USER" >&2
    exit 1
fi

if [ "${1:-}" = "--uninstall" ]; then
    echo "stopping butler-vpn.service (if running)..."
    "$SYSTEMCTL" stop butler-vpn.service 2>/dev/null || true
    "$SYSTEMCTL" disable butler-vpn.service 2>/dev/null || true
    rm -f "$UNIT_PATH" "$SUDOERS_PATH"
    rm -rf "$OPT_DIR"
    "$SYSTEMCTL" daemon-reload
    echo "removed: $OPT_DIR, $UNIT_PATH, $SUDOERS_PATH"
    exit 0
fi

for f in butler-vpn-up.sh butler-vpn-down.sh butler-vpn.service sudoers-butler-vpn; do
    [ -f "$SELF_DIR/$f" ] || { echo "missing $SELF_DIR/$f — run this script from inside its own repo checkout" >&2; exit 1; }
done

echo "installing butler-vpn for user: $TARGET_USER (home: $TARGET_HOME)"

mkdir -p "$OPT_DIR"
sed "s#__HOME__#$TARGET_HOME#g" "$SELF_DIR/butler-vpn-up.sh"   > "$OPT_DIR/butler-vpn-up.sh"
sed "s#__HOME__#$TARGET_HOME#g" "$SELF_DIR/butler-vpn-down.sh" > "$OPT_DIR/butler-vpn-down.sh"
chown root:root "$OPT_DIR/butler-vpn-up.sh" "$OPT_DIR/butler-vpn-down.sh"
chmod 0755 "$OPT_DIR/butler-vpn-up.sh" "$OPT_DIR/butler-vpn-down.sh"

install -m 0644 -o root -g root "$SELF_DIR/butler-vpn.service" "$UNIT_PATH"

# Sudoers is the one file where a mistake can be serious (a broken /etc/sudoers.d
# entry can break sudo itself) — generate it into a temp file and validate with
# visudo BEFORE it ever touches /etc/sudoers.d.
TMP_SUDOERS="$(mktemp)"
trap 'rm -f "$TMP_SUDOERS"' EXIT
sed "s#__USER__#$TARGET_USER#g" "$SELF_DIR/sudoers-butler-vpn" > "$TMP_SUDOERS"
if ! "$VISUDO" -c -f "$TMP_SUDOERS"; then
    echo "generated sudoers rule failed validation — aborting, nothing sudoers-related was installed" >&2
    exit 1
fi
install -m 0440 -o root -g root "$TMP_SUDOERS" "$SUDOERS_PATH"

"$SYSTEMCTL" daemon-reload

echo
echo "installed:"
echo "  $OPT_DIR/butler-vpn-up.sh"
echo "  $OPT_DIR/butler-vpn-down.sh"
echo "  $UNIT_PATH"
echo "  $SUDOERS_PATH  (passwordless sudo for $TARGET_USER, scoped to systemctl start/stop butler-vpn.service)"
echo

OVPN_CONFIG="$TARGET_HOME/vpn/germany/openvpn_full.ovpn"
if [ -f "$OVPN_CONFIG" ]; then
    echo "OpenVPN config found: $OVPN_CONFIG"
else
    echo "WARNING: no OpenVPN config at $OVPN_CONFIG — butler-vpn.service will fail to start until it's there."
fi

echo
echo "Nothing was started or enabled. To connect: systemctl start butler-vpn.service (or the bar/menu button)."
echo "Debugging: journalctl -u butler-vpn -e   and   sudo tail -100 /var/log/butler-vpn-openvpn.log"
echo "To remove everything this installed: sudo $0 --uninstall"
