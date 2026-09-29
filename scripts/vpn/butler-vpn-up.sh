#!/bin/bash
# butler-vpn-up.sh — connect via OpenVPN with an IPv6/LAN-scoped kill switch.
#
# Installed as root at /opt/butler-vpn/butler-vpn-up.sh (0755, root:root), run
# ONLY via `systemctl start butler-vpn.service` (Type=notify — see butler-vpn.service).
# Don't run it by hand as root outside systemd: it blocks non-tunnel IPv4 and all
# non-LAN IPv6 traffic until it exits cleanly, and relies on systemd for supervision
# and on butler-vpn-down.sh (ExecStopPost) as a failsafe if it's ever killed hard.
#
# Why this exists: amnezia-client (github.com/amnezia-vpn/amnezia-client) runs
# plain `openvpn --config <file>` and, once connected, activates a kill switch
# adapted from Private Internet Access's GPL3 desktop client
# (client/platforms/linux/daemon/linuxfirewall.cpp, itself credited there to PIA)
# that blocks IPv6 outright and restricts everything else to loopback/LAN/DHCP/the
# tunnel interface (plus the VPN server's own IP — see below). That's almost
# certainly why plain openvpn/NetworkManager "works in half the places" while
# Amnezia doesn't: this LAN hands out IPv6 (see `ip -6 addr`), and
# `redirect-gateway def1` in the .ovpn only redirects IPv4 — any IPv6-reachable
# site silently bypasses the tunnel on a plain connection. This script
# reproduces that same kill switch, trimmed to what this config actually needs
# (no Xray traffic marking or split tunnel — those are for protocols this .ovpn
# doesn't use).
#
# The VPN-server-IP allow rule is NOT optional, unlike the split-tunnel pieces
# above: redirect-gateway makes tun the new default route, but openvpn's own UDP
# packets carrying the tunnel keep going out the physical interface to the real
# server for the whole session. Skipping this rule blackholes the connection
# the instant the kill switch arms — found this the hard way on the first real
# connect (tunnel looked up, kill switch armed, and then nothing could reach
# anything, because openvpn itself could no longer reach its own server).
#
# Deliberate difference from Amnezia: this fails OPEN, not closed. If openvpn exits
# unexpectedly (crash, server kick, network drop), the firewall is torn down and
# normal internet resumes immediately, rather than staying blocked until you
# reconnect. Amnezia's default kill switch fails closed. We chose fail-open here
# because this script cannot be test-connected before you run it for real — a bug
# that leaves you stuck offline is a far worse failure mode than an occasional
# leak during an unexpected drop. If you want strict fail-closed behaviour later,
# that's a deliberate follow-up change, not an accident of this version.
#
# DNS is NOT firewalled here on purpose. The .ovpn's own `up`/`down
# update-systemd-resolved` directives already route DNS the same way Amnezia's own
# connections do (systemd-resolved, via D-Bus). Also blocking stray DNS ourselves
# risks a connection that looks "up" but resolves nothing — worse than the leak
# we're fixing. IPv6 blocking is the main fix being applied here.
#
# Firewall rules are never persisted (no iptables-save / netfilter-persistent) —
# a reboot always clears them, even in the worst case where this script is killed
# before its own cleanup runs.
#
# Manual override, any time, if the chain ever looks stuck (safe to run even if
# nothing is up):
#   sudo /opt/butler-vpn/butler-vpn-down.sh
#
# Debugging: journalctl -u butler-vpn -e   (this script's own log lines)
#            sudo tail -100 /var/log/butler-vpn-openvpn.log   (raw openvpn output)

set -euo pipefail

OVPN_CONFIG="__HOME__/vpn/germany/openvpn_full.ovpn"   # placeholder filled in by install.sh
OPENVPN_BIN="/usr/bin/openvpn"
IPTABLES="/usr/bin/iptables"
IP6TABLES="/usr/bin/ip6tables"
PGREP="/usr/bin/pgrep"
GREP="/usr/bin/grep"
SYSTEMD_NOTIFY="/usr/bin/systemd-notify"
SYSTEMD_CAT="/usr/bin/systemd-cat"
CHAIN="bvpn"
LOG_FILE="/var/log/butler-vpn-openvpn.log"
READY_TIMEOUT=30   # seconds to wait for "Initialization Sequence Completed"

log() { echo "$*" | "$SYSTEMD_CAT" -t butler-vpn -p info 2>/dev/null || true; echo "[butler-vpn] $*" >&2 || true; }
die() {
    log "FATAL: $*"
    "$SYSTEMD_NOTIFY" --status="failed: $*" 2>/dev/null || true
    exit 1
}

[ "$(id -u)" -eq 0 ] || die "must run as root (via systemd)"
[ -f "$OVPN_CONFIG" ] || die "config not found: $OVPN_CONFIG"
[ -x "$OPENVPN_BIN" ] || die "openvpn binary not found: $OPENVPN_BIN"

# Refuse to run alongside another openvpn (e.g. Amnezia) — two tunnels fighting
# over the default route is exactly the kind of breakage we're trying to avoid.
if "$PGREP" -x openvpn >/dev/null 2>&1; then
    die "another openvpn process is already running (Amnezia connected?) — stop it first"
fi

OVPN_PID=""
FW_UP=0

teardown_fw() {
    [ "$FW_UP" -eq 1 ] || return 0
    log "tearing down firewall"
    "$IPTABLES"  -D OUTPUT -j "$CHAIN" 2>/dev/null || true
    "$IP6TABLES" -D OUTPUT -j "$CHAIN" 2>/dev/null || true
    "$IPTABLES"  -F "$CHAIN" 2>/dev/null || true
    "$IPTABLES"  -X "$CHAIN" 2>/dev/null || true
    "$IP6TABLES" -F "$CHAIN" 2>/dev/null || true
    "$IP6TABLES" -X "$CHAIN" 2>/dev/null || true
    FW_UP=0
}

cleanup() {
    local code=$?
    trap - EXIT TERM INT
    log "shutting down (exit code so far: $code)"
    "$SYSTEMD_NOTIFY" --stopping 2>/dev/null || true
    if [ -n "$OVPN_PID" ] && kill -0 "$OVPN_PID" 2>/dev/null; then
        log "sending SIGTERM to openvpn (pid $OVPN_PID)"
        kill -TERM "$OVPN_PID" 2>/dev/null || true
        for _ in $(seq 1 20); do
            kill -0 "$OVPN_PID" 2>/dev/null || break
            sleep 0.5
        done
        if kill -0 "$OVPN_PID" 2>/dev/null; then
            log "openvpn did not exit in time, killing"
            kill -KILL "$OVPN_PID" 2>/dev/null || true
        fi
    fi
    teardown_fw
    log "stopped"
    exit "$code"
}
trap cleanup EXIT TERM INT

log "starting openvpn: $OVPN_CONFIG"
"$SYSTEMD_NOTIFY" --status="starting openvpn" 2>/dev/null || true
: > "$LOG_FILE"
"$OPENVPN_BIN" --config "$OVPN_CONFIG" --verb 4 >>"$LOG_FILE" 2>&1 &
OVPN_PID=$!
log "openvpn pid $OVPN_PID, waiting up to ${READY_TIMEOUT}s for tunnel"
"$SYSTEMD_NOTIFY" --status="waiting for tunnel (pid $OVPN_PID)" 2>/dev/null || true

deadline=$((SECONDS + READY_TIMEOUT))
while [ "$SECONDS" -lt "$deadline" ]; do
    kill -0 "$OVPN_PID" 2>/dev/null || die "openvpn exited early, see $LOG_FILE"
    if "$GREP" -q "Initialization Sequence Completed" "$LOG_FILE" 2>/dev/null; then
        break
    fi
    sleep 0.5
done
"$GREP" -q "Initialization Sequence Completed" "$LOG_FILE" 2>/dev/null \
    || die "openvpn did not connect within ${READY_TIMEOUT}s, see $LOG_FILE"

TUN_IF=$("$GREP" -oE 'TUN/TAP device tun[0-9]+ opened' "$LOG_FILE" | tail -1 | "$GREP" -oE 'tun[0-9]+' || true)
[[ "$TUN_IF" =~ ^tun[0-9]+$ ]] || die "could not determine tunnel interface from log"
log "tunnel is up on $TUN_IF"

# redirect-gateway makes tun the new default route, but openvpn's own UDP
# packets carrying the tunnel still go out the PHYSICAL interface to this IP
# for the whole session, not just the handshake — without an explicit allow,
# the kill switch below blocks openvpn's own traffic to itself and blackholes
# everything the instant it arms (this happened on the first real connect: the
# tunnel looked up but nothing could reach it, because nothing could reach the
# server either). Read from openvpn's own log line so this always matches what
# it's actually talking to, not a possibly-stale separate DNS lookup.
SERVER_IP=$("$GREP" -oE '\[AF_INET\][0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+' "$LOG_FILE" \
    | head -1 | "$GREP" -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' || true)
[[ "$SERVER_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] \
    || die "could not determine VPN server IP from log — refusing to arm a kill switch that would cut off the tunnel itself"
log "VPN server is $SERVER_IP, tunnel on $TUN_IF"

log "enabling firewall (kill switch)"
# Set before any iptables call below: teardown_fw's own steps are all
# idempotent (|| true), so it's safe to attempt even if setup fails halfway —
# and if FW_UP stayed 0 on a partial failure, our own trap would skip cleanup
# on a rule that did get linked. (ExecStopPost still catches that either way,
# but this way the primary trap doesn't need to rely on the failsafe for it.)
FW_UP=1
"$IPTABLES"  -N "$CHAIN" 2>/dev/null || "$IPTABLES"  -F "$CHAIN"
"$IP6TABLES" -N "$CHAIN" 2>/dev/null || "$IP6TABLES" -F "$CHAIN"

"$IPTABLES" -A "$CHAIN" -o lo -j ACCEPT
for net in 10.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.168.0.0/16 224.0.0.0/4 255.255.255.255/32; do
    "$IPTABLES" -A "$CHAIN" -d "$net" -j ACCEPT
done
"$IPTABLES" -A "$CHAIN" -p udp -d 255.255.255.255 --sport 68 --dport 67 -j ACCEPT
"$IPTABLES" -A "$CHAIN" -d "$SERVER_IP" -j ACCEPT
"$IPTABLES" -A "$CHAIN" -o "$TUN_IF" -j ACCEPT
"$IPTABLES" -A "$CHAIN" -j REJECT

"$IP6TABLES" -A "$CHAIN" -o lo -j ACCEPT
for net in fc00::/7 fe80::/10 ff00::/8; do
    "$IP6TABLES" -A "$CHAIN" -d "$net" -j ACCEPT
done
"$IP6TABLES" -A "$CHAIN" -p udp -d ff00::/8 --sport 546 --dport 547 -j ACCEPT
"$IP6TABLES" -A "$CHAIN" -j REJECT

"$IPTABLES"  -C OUTPUT -j "$CHAIN" 2>/dev/null || "$IPTABLES"  -I OUTPUT -j "$CHAIN"
"$IP6TABLES" -C OUTPUT -j "$CHAIN" 2>/dev/null || "$IP6TABLES" -I OUTPUT -j "$CHAIN"

log "connected, kill switch active on $TUN_IF (server $SERVER_IP allowed through)"
"$SYSTEMD_NOTIFY" --ready --status="connected on $TUN_IF via $SERVER_IP" 2>/dev/null || true

wait "$OVPN_PID"
