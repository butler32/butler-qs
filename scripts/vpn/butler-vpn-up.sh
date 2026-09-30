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

DEFAULT_OVPN="__HOME__/vpn/germany/openvpn_full.ovpn"   # placeholder filled in by install.sh
CONFIG_JSON="__HOME__/.local/state/quickshell/by-shell/butler/config.json"
OPENVPN_BIN="/usr/bin/openvpn"
IPTABLES="/usr/bin/iptables"
IP6TABLES="/usr/bin/ip6tables"
IP_BIN="/usr/bin/ip"
PGREP="/usr/bin/pgrep"
GREP="/usr/bin/grep"
AWK="/usr/bin/awk"
GETENT="/usr/bin/getent"
TIMEOUT_BIN="/usr/bin/timeout"
PYTHON3="/usr/bin/python3"
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

# Which .ovpn to use: Menu -> VPN -> Config file stores it in network.vpnConfig of
# the same state file the excluded domains come from; empty = the default above.
# Note: openvpn runs whatever this file says (it can contain `up` scripts) as root,
# so it is exactly as trusted as the user-owned file the path points to.
OVPN_CONFIG="$DEFAULT_OVPN"
if [ -f "$CONFIG_JSON" ] && [ -x "$PYTHON3" ]; then
    CHOSEN=$("$PYTHON3" -c "
import json
try:
    with open('$CONFIG_JSON') as f:
        print(json.load(f).get('network', {}).get('vpnConfig', '').strip())
except Exception:
    pass
" 2>/dev/null || true)
    [ -n "$CHOSEN" ] && OVPN_CONFIG="$CHOSEN"
fi
[[ "$OVPN_CONFIG" == /* ]] || die "vpn config path must be absolute: $OVPN_CONFIG"
[ -f "$OVPN_CONFIG" ] || die "config not found: $OVPN_CONFIG"
[ -x "$OPENVPN_BIN" ] || die "openvpn binary not found: $OPENVPN_BIN"

# Refuse to run alongside another openvpn (e.g. Amnezia) — two tunnels fighting
# over the default route is exactly the kind of breakage we're trying to avoid.
if "$PGREP" -x openvpn >/dev/null 2>&1; then
    die "another openvpn process is already running (Amnezia connected?) — stop it first"
fi

# Captured now, before openvpn's redirect-gateway replaces the default route —
# this is the only point where "the original physical gateway" is still what
# `ip route show default` actually reports. Needed for excluded-domain bypass
# routes below; harmless to compute even if no domains end up excluded.
ORIG_ROUTE=$("$IP_BIN" route show default | head -1)
ORIG_GW=$(echo "$ORIG_ROUTE" | "$AWK" '{for(i=1;i<=NF;i++) if ($i=="via") print $(i+1)}')
ORIG_IFACE=$(echo "$ORIG_ROUTE" | "$AWK" '{for(i=1;i<=NF;i++) if ($i=="dev") print $(i+1)}')

OVPN_PID=""
FW_UP=0
EXCLUDE_ROUTES=""   # space-separated IPs we added a bypass /32 route for, torn down below
STOP_REQUESTED=0    # set only by the TERM/INT handler — distinguishes "systemctl stop asked
                    # us to" from "openvpn exited on its own" so a normal stop reports success
                    # to systemd instead of the trap's own re-exit(143) reading as a crash

teardown_fw() {
    [ "$FW_UP" -eq 1 ] || return 0
    log "tearing down firewall"
    "$IPTABLES"  -D OUTPUT -j "$CHAIN" 2>/dev/null || true
    "$IP6TABLES" -D OUTPUT -j "$CHAIN" 2>/dev/null || true
    "$IPTABLES"  -F "$CHAIN" 2>/dev/null || true
    "$IPTABLES"  -X "$CHAIN" 2>/dev/null || true
    "$IP6TABLES" -F "$CHAIN" 2>/dev/null || true
    "$IP6TABLES" -X "$CHAIN" 2>/dev/null || true
    for ip in $EXCLUDE_ROUTES; do
        "$IP_BIN" route del "$ip/32" 2>/dev/null || true
    done
    FW_UP=0
}

cleanup() {
    local code=$?
    trap - EXIT TERM INT
    if [ "$STOP_REQUESTED" -eq 1 ]; then
        code=0
    fi
    log "shutting down (exit code: $code, stop requested: $STOP_REQUESTED)"
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
on_stop_signal() {
    STOP_REQUESTED=1
    cleanup
}
trap cleanup EXIT
trap on_stop_signal TERM INT

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

# Domains excluded from the tunnel (Config.network.vpnExcludedDomains, edited
# from the Network popup's VPN section — read straight out of the Quickshell
# state file, since it's just JSON and root can read any file). Resolved once,
# right here — a domain whose IP changes later (common for CDN-backed sites)
# stays excluded under its OLD IP until the next reconnect. That's a known,
# accepted tradeoff: a live DNS-triggered refresh would mean a privileged
# background loop adding/removing routes on its own, which is a bigger risk
# than occasionally needing a reconnect to pick up a changed IP.
if [ -f "$CONFIG_JSON" ] && [ -x "$PYTHON3" ] && [ -n "$ORIG_GW" ] && [ -n "$ORIG_IFACE" ]; then
    DOMAINS=$("$PYTHON3" -c "
import json
try:
    with open('$CONFIG_JSON') as f:
        data = json.load(f)
    for d in data.get('network', {}).get('vpnExcludedDomains', []):
        if isinstance(d, str) and d.strip():
            print(d.strip())
except Exception:
    pass
" 2>/dev/null || true)
    while IFS= read -r domain; do
        [ -n "$domain" ] || continue
        if ! [[ "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$ ]]; then
            log "WARNING: skipping malformed excluded domain: $domain"
            continue
        fi
        IPS=$("$TIMEOUT_BIN" 5 "$GETENT" ahostsv4 "$domain" 2>/dev/null | "$AWK" '{print $1}' | sort -u || true)
        if [ -z "$IPS" ]; then
            log "WARNING: could not resolve excluded domain: $domain"
            continue
        fi
        while IFS= read -r ip; do
            [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] || continue
            if "$IP_BIN" route add "$ip/32" via "$ORIG_GW" dev "$ORIG_IFACE" 2>/dev/null; then
                EXCLUDE_ROUTES="$EXCLUDE_ROUTES $ip"
                "$IPTABLES" -A "$CHAIN" -d "$ip" -j ACCEPT
                log "excluded from VPN: $domain -> $ip"
            fi
        done <<< "$IPS"
    done <<< "$DOMAINS"
elif [ -f "$CONFIG_JSON" ] && ([ -z "$ORIG_GW" ] || [ -z "$ORIG_IFACE" ]); then
    log "WARNING: could not determine the original gateway/interface, skipping domain exclusions"
fi

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
