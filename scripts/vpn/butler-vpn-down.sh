#!/bin/bash
# butler-vpn-down.sh — unconditional failsafe cleanup.
#
# Wired as `ExecStopPost` on butler-vpn.service, so it runs after the service
# stops for ANY reason (clean stop, crash, SIGKILL) — including cases where
# butler-vpn-up.sh's own cleanup trap never got to run. Safe to run at any time,
# by hand or otherwise: every step is idempotent and no-ops if there's nothing to
# remove. This file only ever tears things down, never sets anything up.
#
# Manual override: `sudo /opt/butler-vpn/butler-vpn-down.sh` unconditionally clears
# the kill switch and kills our openvpn process, regardless of what systemd thinks
# the service state is.

set -uo pipefail   # no -e: every step below must still run if an earlier one fails

CHAIN="bvpn"
OVPN_CONFIG="__HOME__/vpn/germany/openvpn_full.ovpn"   # placeholder filled in by install.sh
IPTABLES="/usr/bin/iptables"
IP6TABLES="/usr/bin/ip6tables"
PKILL="/usr/bin/pkill"
SYSTEMD_CAT="/usr/bin/systemd-cat"

echo "failsafe cleanup running" | "$SYSTEMD_CAT" -t butler-vpn -p info 2>/dev/null || true

# In case butler-vpn-up.sh's own trap never ran (e.g. it was SIGKILLed): kill any
# leftover openvpn process for OUR config specifically. The exact --config path
# match means this can never touch Amnezia's or any other openvpn invocation.
"$PKILL" -TERM -f "openvpn --config $OVPN_CONFIG" 2>/dev/null || true

"$IPTABLES"  -D OUTPUT -j "$CHAIN" 2>/dev/null || true
"$IP6TABLES" -D OUTPUT -j "$CHAIN" 2>/dev/null || true
"$IPTABLES"  -F "$CHAIN" 2>/dev/null || true
"$IPTABLES"  -X "$CHAIN" 2>/dev/null || true
"$IP6TABLES" -F "$CHAIN" 2>/dev/null || true
"$IP6TABLES" -X "$CHAIN" 2>/dev/null || true

echo "failsafe cleanup done" | "$SYSTEMD_CAT" -t butler-vpn -p info 2>/dev/null || true
exit 0
