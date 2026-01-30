#!/usr/bin/env bash
# Network Health Monitoring Script
# Monitors for early warning signs of RTL8126A driver issues
# Created: 2026-01-30

set -euo pipefail

LOG_FILE="/var/log/network-health-monitor.log"
INTERFACE="enp11s0"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

check_network_watchdog() {
    if journalctl -n 100 --since "5 minutes ago" | grep -q "NETDEV WATCHDOG"; then
        log "WARNING: Network watchdog timeout detected on $INTERFACE"
        return 1
    fi
    return 0
}

check_soft_lockup() {
    if journalctl -n 100 --since "5 minutes ago" | grep -q "soft lockup"; then
        log "CRITICAL: Kernel soft lockup detected"
        return 1
    fi
    return 0
}

check_pci_errors() {
    if journalctl -n 100 --since "5 minutes ago" | grep -q "pci_mmcfg_read"; then
        log "WARNING: PCI configuration space read errors detected"
        return 1
    fi
    return 0
}

check_interface_status() {
    if ! ip link show "$INTERFACE" | grep -q "state UP"; then
        log "WARNING: Interface $INTERFACE is not UP"
        return 1
    fi
    return 0
}

main() {
    log "Starting network health check"

    local status=0

    check_network_watchdog || status=1
    check_soft_lockup || status=1
    check_pci_errors || status=1
    check_interface_status || status=1

    if [ $status -eq 0 ]; then
        log "Network health check: OK"
    else
        log "Network health check: WARNINGS DETECTED"
    fi

    return $status
}

main "$@"
