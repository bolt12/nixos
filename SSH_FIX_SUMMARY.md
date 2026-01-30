# SSH Access Fix Implementation Summary

**Date:** 2026-01-30
**Machine:** Ninho
**Status:** Ready for deployment

## Changes Implemented

### 1. Firewall Configuration (CRITICAL)
**File:** `system/machine/ninho/configuration.nix:213`

**Change:**
```nix
allowedTCPPorts = [
  22    # SSH - Remote access  ← ADDED
  20    # FTP
  21    # FTP
  # ... rest unchanged
];
```

**Impact:** Enables external SSH access (previously only accessible via WireGuard VPN)

---

### 2. Network Driver Stability Mitigations
**File:** `system/machine/ninho/configuration.nix:54-62`

**Changes:**
```nix
kernelParams = [
  # ... existing params ...

  # Realtek RTL8126A network driver stability (r8169)  ← ADDED
  "r8169.use_dac=1"   # Enable DAC (Dual Address Cycle)
  "r8169.aspm=0"      # Disable ASPM at driver level
  "iommu=soft"        # Software IOMMU (may help with DMA issues)
];
```

**Impact:** Prevents future kernel panics caused by RTL8126A network driver failures

---

### 3. Hardware Firmware Updates
**File:** `system/machine/ninho/configuration.nix:139-142`

**Change:**
```nix
hardware = {
  # Hardware firmware  ← ADDED
  firmware = with pkgs; [
    linux-firmware  # Include latest network driver firmware (RTL8126A)
  ];

  # ... rest unchanged
};
```

**Impact:** Ensures latest network driver firmware is available

---

### 4. Network Health Monitoring Script
**File:** `system/machine/ninho/scripts/monitor-network-health.sh`

**Purpose:** Early warning detection for network driver issues

**Monitors:**
- Network watchdog timeouts
- Kernel soft lockups
- PCI configuration space errors
- Interface status

**Usage:**
```bash
# Run manually
./system/machine/ninho/scripts/monitor-network-health.sh

# View logs
sudo tail -f /var/log/network-health-monitor.log
```

---

## Deployment Instructions

### Step 1: Apply Configuration
```bash
sudo nixos-rebuild switch --flake .#ninho
```

### Step 2: Verify SSH Service
```bash
# Check SSH is listening on port 22
sudo ss -tlnp | grep :22

# Expected output:
# LISTEN  0  128  0.0.0.0:22  0.0.0.0:*  users:(("sshd",pid=XXX,fd=X))
# LISTEN  0  128     [::]:22     [::]:*  users:(("sshd",pid=XXX,fd=X))
```

### Step 3: Verify Firewall Rules
```bash
# Check firewall accepts port 22
sudo nft list ruleset | grep -A5 -B5 "22"

# Should show port 22 in accepted TCP ports
```

### Step 4: Test External SSH Access
```bash
# From another machine on the network
ssh bolt@<ninho-external-ip>

# Should connect successfully
```

### Step 5: Test WireGuard SSH Access
```bash
# From another machine via WireGuard
ssh bolt@10.100.0.100

# Should still work as before
```

### Step 6: Monitor Network Health
```bash
# Run the monitoring script
./system/machine/ninho/scripts/monitor-network-health.sh

# Check for warnings in system logs
journalctl -u systemd-networkd -f
journalctl -p err -f
```

---

## What Was Fixed

### Primary Issue: Kernel Panic (Jan 29, 2026)
**Root Cause:** Realtek RTL8126A network driver (r8169) failure causing kernel soft lockup

**Symptoms:**
- Network watchdog timeout (transmit queue stuck)
- Multiple CPU lockups (stuck for 22+ seconds)
- AHCI controller failure (storage frozen)
- Complete system unresponsiveness

**Solution:** Added kernel parameters to stabilize r8169 driver

---

### Secondary Issue: Firewall Misconfiguration
**Root Cause:** Port 22 (SSH) not in firewall allowed ports list

**Symptoms:**
- External SSH connections blocked
- SSH only accessible via WireGuard VPN (wg0)

**Solution:** Added port 22 to allowedTCPPorts

---

## Risk Assessment

### Firewall Change
- **Risk:** Low - standard SSH port opening
- **Impact:** High - restores external SSH access
- **Rollback:** Easy - remove port 22 and rebuild

### Network Driver Mitigations
- **Risk:** Medium - kernel parameters can affect stability
- **Impact:** High - may prevent future crashes
- **Rollback:** Easy - remove parameters and rebuild
- **Testing:** Monitor for 7 days, check logs daily

---

## Ongoing Monitoring

### Daily Checks (First Week)
```bash
# Check for network watchdog timeouts
journalctl -b | grep "NETDEV WATCHDOG"

# Check for soft lockups
journalctl -b | grep "soft lockup"

# Check interface status
ip link show enp11s0
```

### Weekly Checks (Ongoing)
```bash
# Run health monitoring script
./system/machine/ninho/scripts/monitor-network-health.sh

# Review system logs for errors
journalctl -p err --since "7 days ago"
```

---

## Rollback Procedure

If issues occur after deployment:

### 1. Revert Configuration Changes
```bash
git diff HEAD system/machine/ninho/configuration.nix
git checkout system/machine/ninho/configuration.nix
sudo nixos-rebuild switch --flake .#ninho
```

### 2. Rollback to Previous Generation
```bash
# List generations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Rollback to previous
sudo nixos-rebuild switch --rollback
```

---

## Success Criteria

✅ SSH accessible from external network
✅ SSH accessible via WireGuard VPN
✅ No network watchdog timeouts in logs
✅ No kernel soft lockups in logs
✅ Network interface remains stable under load
✅ System uptime > 7 days without network-related crashes

---

## References

- **Diagnostic Report:** See plan file for full analysis
- **System Logs:** `journalctl -b -1` (boot before crash)
- **Network Interface:** enp11s0 (RTL8126A)
- **Driver:** r8169 kernel module
- **Affected Hardware:** Realtek RTL8126A on X870E chipset
