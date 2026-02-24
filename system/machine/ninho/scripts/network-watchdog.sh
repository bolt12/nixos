#!/usr/bin/env bash
# Network Watchdog for RTL8126A NIC Failures
# Escalating recovery: interface bounce -> NM reconnect -> driver reload -> reboot
# Replaces monitor-network-health.sh (which only logged)

set -uo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

INTERFACE="enp11s0"
STATE_DIR="/var/lib/network-watchdog"
STATE_FILE="$STATE_DIR/state"
NTFY_URL="http://127.0.0.1:8106/network-watchdog"
FAILURES_PER_LEVEL=3
MAX_REBOOT_DEFERRALS=3

# Cooldowns (seconds) per recovery level
COOLDOWN_L1=60
COOLDOWN_L2=120
COOLDOWN_L3=180

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

notify() {
    local priority="${2:-default}"
    local title="${3:-Network Watchdog}"
    curl -sf -o /dev/null \
        -H "Title: $title" \
        -H "Priority: $priority" \
        -d "$1" \
        "$NTFY_URL" 2>/dev/null || true
}

# Read a key from the state file, with a default value
state_get() {
    local key="$1" default="${2:-}"
    if [[ -f "$STATE_FILE" ]]; then
        grep -m1 "^${key}=" "$STATE_FILE" 2>/dev/null | cut -d= -f2- || echo "$default"
    else
        echo "$default"
    fi
}

# Write a key=value to the state file (create/update)
state_set() {
    local key="$1" value="$2"
    mkdir -p "$STATE_DIR"
    if [[ -f "$STATE_FILE" ]] && grep -q "^${key}=" "$STATE_FILE" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$STATE_FILE"
    else
        echo "${key}=${value}" >> "$STATE_FILE"
    fi
}

now_epoch() { date +%s; }

zfs_scrub_running() {
    zpool status 2>/dev/null | grep -q "scrub in progress"
}

# ---------------------------------------------------------------------------
# Health checks
# ---------------------------------------------------------------------------

get_gateway() {
    ip route show default dev "$INTERFACE" 2>/dev/null | awk '/default/{print $3; exit}'
}

check_ping() {
    local gw
    gw="$(get_gateway)"
    if [[ -z "$gw" ]]; then
        log "WARN: No default gateway found for $INTERFACE"
        return 1
    fi
    if ! ping -c 3 -W 2 -I "$INTERFACE" "$gw" &>/dev/null; then
        log "FAIL: Gateway $gw unreachable via $INTERFACE"
        return 1
    fi
    return 0
}

check_carrier() {
    local carrier
    carrier="$(cat /sys/class/net/"$INTERFACE"/carrier 2>/dev/null || echo 0)"
    if [[ "$carrier" != "1" ]]; then
        log "FAIL: No carrier on $INTERFACE"
        return 1
    fi
    return 0
}

check_watchdog_errors() {
    if journalctl -k --since "2 minutes ago" --no-pager 2>/dev/null \
        | grep -q "NETDEV WATCHDOG.*$INTERFACE"; then
        log "FAIL: NETDEV WATCHDOG timeout detected for $INTERFACE"
        return 1
    fi
    return 0
}

run_health_checks() {
    local failed=0
    check_carrier || failed=1
    check_watchdog_errors || failed=1
    check_ping || failed=1
    return $failed
}

# ---------------------------------------------------------------------------
# Recovery actions
# ---------------------------------------------------------------------------

recovery_l1() {
    log "L1: Bouncing interface $INTERFACE"
    notify "L1: Bouncing interface $INTERFACE (fail count: $(state_get FAIL_COUNT 0))" "high"
    ip link set "$INTERFACE" down
    sleep 2
    ip link set "$INTERFACE" up
    sleep 5
}

recovery_l2() {
    log "L2: NetworkManager reconnect for $INTERFACE"
    notify "L2: NetworkManager reconnect for $INTERFACE" "high"
    nmcli device disconnect "$INTERFACE" 2>/dev/null || true
    sleep 3
    nmcli device connect "$INTERFACE" 2>/dev/null || true
    sleep 10
}

recovery_l3() {
    log "L3: Reloading r8169 driver"
    notify "L3: Reloading r8169 driver + restarting NM & WireGuard" "urgent"
    modprobe -r r8169 2>/dev/null || true
    sleep 3
    if ! modprobe r8169; then
        log "CRITICAL: Failed to reload r8169 — retrying"
        sleep 5
        modprobe r8169 || log "CRITICAL: r8169 reload failed twice"
    fi
    sleep 5
    systemctl restart NetworkManager || log "WARN: NetworkManager restart failed"
    sleep 10
    systemctl restart wireguard-wg0 2>/dev/null || true
    sleep 5
}

recovery_l4() {
    local deferrals
    deferrals="$(state_get REBOOT_DEFERRALS 0)"

    if zfs_scrub_running && (( deferrals < MAX_REBOOT_DEFERRALS )); then
        deferrals=$((deferrals + 1))
        state_set REBOOT_DEFERRALS "$deferrals"
        log "L4: Reboot deferred ($deferrals/$MAX_REBOOT_DEFERRALS) — ZFS scrub in progress"
        notify "L4: Reboot deferred ($deferrals/$MAX_REBOOT_DEFERRALS) — ZFS scrub in progress" "urgent"
        return 1
    fi

    log "L4: Initiating system reboot"
    notify "L4: System reboot initiated (network unrecoverable)" "urgent" "REBOOT"
    sleep 2
    systemctl reboot
}

# Verify network works after a recovery action
verify_recovery() {
    sleep 5
    if run_health_checks; then
        log "Recovery successful — network is healthy"
        notify "Recovery successful — $INTERFACE is healthy again" "default" "Recovery OK"
        state_set FAIL_COUNT 0
        state_set LAST_RECOVERY_LEVEL 0
        state_set REBOOT_DEFERRALS 0
        return 0
    fi
    return 1
}

# ---------------------------------------------------------------------------
# Cooldown check
# ---------------------------------------------------------------------------

cooldown_active() {
    local level="$1"
    local last_action_time last_level cooldown elapsed
    last_action_time="$(state_get LAST_ACTION_TIME 0)"
    last_level="$(state_get LAST_RECOVERY_LEVEL 0)"

    # Cooldown only gates retries at the same level, not escalation
    if (( level > last_level )); then
        return 1
    fi

    elapsed=$(( $(now_epoch) - last_action_time ))

    case "$level" in
        1) cooldown=$COOLDOWN_L1 ;;
        2) cooldown=$COOLDOWN_L2 ;;
        3) cooldown=$COOLDOWN_L3 ;;
        *) return 1 ;;
    esac

    if (( elapsed < cooldown )); then
        log "Cooldown active for L${level} (${elapsed}s / ${cooldown}s)"
        return 0
    fi
    return 1
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
    # Ensure state directory exists
    mkdir -p "$STATE_DIR"

    # Run health checks
    if run_health_checks; then
        # Healthy — reset failure count if it was non-zero
        local prev_fails
        prev_fails="$(state_get FAIL_COUNT 0)"
        if (( prev_fails > 0 )); then
            log "Network healthy — resetting fail count (was $prev_fails)"
            state_set FAIL_COUNT 0
            state_set LAST_RECOVERY_LEVEL 0
            state_set REBOOT_DEFERRALS 0
        fi
        state_set LAST_CHECK "$(date -Iseconds)"
        state_set LAST_STATUS "OK"
        return 0
    fi

    # Unhealthy — increment failure count
    local fail_count last_level
    fail_count="$(state_get FAIL_COUNT 0)"
    fail_count=$((fail_count + 1))
    state_set FAIL_COUNT "$fail_count"
    state_set LAST_CHECK "$(date -Iseconds)"
    state_set LAST_STATUS "FAIL"

    last_level="$(state_get LAST_RECOVERY_LEVEL 0)"
    log "Health check failed (consecutive: $fail_count, last recovery level: $last_level)"

    # Determine which recovery level to attempt
    local target_level=$(( (fail_count - 1) / FAILURES_PER_LEVEL + 1 ))
    # Don't go below what we've already tried
    if (( target_level <= last_level )); then
        target_level=$((last_level + 1))
    fi
    # Cap at L4
    if (( target_level > 4 )); then
        target_level=4
    fi

    # Only act when we've hit the threshold for the current level
    local threshold=$(( (target_level - 1) * FAILURES_PER_LEVEL + FAILURES_PER_LEVEL ))
    # For levels beyond what failures alone would indicate, act immediately
    if (( fail_count < threshold && target_level <= (fail_count / FAILURES_PER_LEVEL + 1) )); then
        log "Accumulating failures ($fail_count/$threshold) before L${target_level} action"
        return 0
    fi

    # Check cooldown (L1-L3 only)
    if (( target_level < 4 )) && cooldown_active "$target_level"; then
        return 0
    fi

    # Execute recovery
    state_set LAST_ACTION_TIME "$(now_epoch)"
    state_set LAST_RECOVERY_LEVEL "$target_level"

    case "$target_level" in
        1) recovery_l1 ;;
        2) recovery_l2 ;;
        3) recovery_l3 ;;
        4) recovery_l4; return $? ;;
    esac

    # Verify recovery worked (L1-L3)
    verify_recovery || log "Recovery L${target_level} did not restore connectivity"
}

main "$@"
