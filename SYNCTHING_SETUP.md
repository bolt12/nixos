# Syncthing Setup Guide

## Overview

Syncthing is configured as a **home-manager service** to synchronize files between your X1 Carbon laptop and Ninho server over the WireGuard VPN. The setup provides:

- **Bi-directional sync** between `/home/bolt/Documents` (laptop) ↔ `/home/bolt/X1-G8-Laptop` (ninho)
- **File versioning** keeps 10 versions of changed/deleted files
- **Backup protection** via ZFS snapshots on ninho (Sanoid maintains 2+ years of history)
- **Bandwidth control** via web UI or command-line
- **Private connections** only (no public relays, VPN-only communication)
- **User-level service** runs as systemd user service (no root required)

---

## Architecture

Syncthing is configured at the **home-manager level**, not system-wide:

**Configuration files:**
- `home-manager/programs/syncthing/default.nix` - Base Syncthing module (enables service)
- `home-manager/users/bolt/user-data.nix` - Ninho server sync config
- `home-manager/users/bolt-with-de/user-data.nix` - X1 laptop sync config

**Firewall rules** remain at NixOS level:
- `system/machine/ninho/configuration.nix` (lines 179-195)
- `system/configuration.nix` (lines 51-66)

---

## Initial Setup

### Step 1: Deploy Configurations

Apply the NixOS configurations on both machines:

```bash
# On X1 Carbon laptop
sudo nixos-rebuild switch --flake .#bolt-nixos

# On Ninho server (via SSH)
sudo nixos-rebuild switch --flake .#ninho-nixos
```

Syncthing will start automatically as a **systemd user service** after rebuild.

### Step 2: Access Web UIs

Both machines run Syncthing web interfaces:

**On X1 Laptop:**
- Direct: http://localhost:8384
- From ninho: http://10.100.0.2:8384

**On Ninho Server:**
- Direct: http://localhost:8384
- From laptop: http://10.100.0.100:8384

### Step 3: Get Device IDs

Each device has a unique identifier. Open both web UIs and:

1. Click "Actions" → "Show ID" on each machine
2. Copy the device IDs (they look like: `ABCDEFG-HIJKLMN-OPQRSTU-VWXYZAB-CDEFGHI-JKLMNOP-QRSTUVW-XYZABCD`)

### Step 4: Add Device IDs to Configuration

Edit the home-manager user-data files and add the real device IDs:

**For ninho** (`home-manager/users/bolt/user-data.nix` line 33):
```nix
"x1-laptop" = {
  id = "PASTE-X1-DEVICE-ID-HERE";
};
```

**For x1-g8** (`home-manager/users/bolt-with-de/user-data.nix` line 13):
```nix
"ninho-server" = {
  id = "PASTE-NINHO-DEVICE-ID-HERE";
};
```

### Step 5: Rebuild with Device IDs

```bash
# On laptop
sudo nixos-rebuild switch --flake .#bolt-nixos

# On ninho
sudo nixos-rebuild switch --flake .#ninho-nixos
```

### Step 6: Accept Connection Requests

After rebuild, each device will see a connection request from the other:

1. Open web UI (http://localhost:8384)
2. Click "Add Device" notification
3. Accept the new device
4. **Accept the folder share** when prompted

---

## File Organization

### On X1 Laptop
```
/home/bolt/Documents/
├── Projects/
├── Work/
├── Personal/
└── ... (synced to ninho)
```

### On Ninho Server
```
/home/bolt/X1-G8-Laptop/
├── Projects/
├── Work/
├── Personal/
└── ... (mirror of laptop Documents/)
```

---

## Usage

### Starting/Stopping Sync

**Pause all syncing (on either machine):**
```bash
systemctl --user stop syncthing
```

**Resume syncing:**
```bash
systemctl --user start syncthing
```

**Check status:**
```bash
systemctl --user status syncthing
```

### Pause Sync on Mobile Data

**Method 1: Web UI**
1. Open http://localhost:8384
2. Click folder name → "Edit"
3. Click "Pause" button

**Method 2: Command-line**
```bash
# Pause specific folder
syncthing cli config folders laptop-to-ninho paused set true

# Resume
syncthing cli config folders laptop-to-ninho paused set false
```

### Monitor Sync Status

**Web UI Dashboard:**
- Shows real-time sync progress
- Bandwidth usage graphs
- Last sync time
- Conflicts (if any)

**Command-line:**
```bash
# Show sync status
syncthing cli show status

# Show folder status
syncthing cli show folders

# Show connections
syncthing cli show connections
```

---

## Bandwidth Control

### Set Transfer Rate Limits

In the web UI (http://localhost:8384):

1. Click "Actions" → "Settings"
2. Go to "Connections" tab
3. Set limits:
   - **Download Rate:** e.g., 1000 KiB/s for mobile data
   - **Upload Rate:** e.g., 500 KiB/s for mobile data
   - Set to `0` for unlimited on home WiFi

### Automatic Bandwidth Scheduling

Create custom script to detect network and adjust:

```bash
#!/usr/bin/env bash
# ~/bin/syncthing-bandwidth.sh

# Check if on mobile data (example: check if on specific SSID)
if nmcli -t -f active,ssid dev wifi | grep -q "^yes:Home-WiFi"; then
    # On home WiFi - unlimited
    syncthing cli config options max-recv-kbps set 0
    syncthing cli config options max-send-kbps set 0
else
    # On mobile/limited - restrict to 1MB/s down, 500KB/s up
    syncthing cli config options max-recv-kbps set 1000
    syncthing cli config options max-send-kbps set 500
fi
```

---

## File Recovery

### Recover Deleted Files (Syncthing Versioning)

Syncthing keeps 10 versions of each file in `.stversions/`:

**On ninho:**
```bash
cd /home/bolt/X1-G8-Laptop/.stversions/
ls -la

# Find your file (timestamped)
# Example: important-doc.txt~20251126-143022
cp important-doc.txt~20251126-143022 ../important-doc.txt
```

### Recover Deleted Files (ZFS Snapshots)

Ninho has comprehensive ZFS snapshots via Sanoid:

```bash
# List available snapshots
zfs list -t snapshot rpool/home

# Browse specific snapshot
ls /home/bolt/.zfs/snapshot/autosnap_2025-11-26_14:00:00/X1-G8-Laptop/

# Restore entire folder
cp -r /home/bolt/.zfs/snapshot/autosnap_2025-11-26_14:00:00/X1-G8-Laptop/ \
     /home/bolt/X1-G8-Laptop-recovered/

# Restore single file
cp /home/bolt/.zfs/snapshot/autosnap_2025-11-26_14:00:00/X1-G8-Laptop/important.txt \
   /home/bolt/X1-G8-Laptop/
```

**Snapshot retention on ninho:**
- Every 15 minutes for last 1 hour
- Hourly for 2 days
- Daily for 2 weeks
- Weekly for 2 months
- Monthly for 1 year
- Yearly for 2 years

---

## Conflict Resolution

If both machines modify the same file while disconnected, Syncthing creates conflict copies:

```
important.txt                        # Latest version
important.sync-conflict-20251126.txt # Conflicting version
```

**Manual resolution:**
1. Compare both files
2. Merge changes manually
3. Delete the conflict file
4. Keep the merged version

---

## Troubleshooting

### Devices Not Connecting

**Check WireGuard VPN:**
```bash
# Verify VPN is up
sudo wg show wg0

# Ping ninho from laptop
ping 10.100.0.100

# Ping laptop from ninho
ping 10.100.0.2
```

**Check Syncthing is running:**
```bash
systemctl --user status syncthing
journalctl --user -u syncthing -f
```

**Check firewall:**
```bash
# Should show ports 8384, 22000 (TCP) and 21027, 22000 (UDP)
sudo iptables -L -n | grep -E "8384|22000|21027"
```

### Sync Is Slow

**Check connection type:**
- Open web UI → Remote Devices → should show "Direct" (not "Relay")
- If using relay, check WireGuard configuration

**Check bandwidth limits:**
- Web UI → Actions → Settings → Connections
- Ensure limits aren't too restrictive

### Files Not Syncing

**Check folder status:**
```bash
syncthing cli show folders
```

**Check for errors:**
```bash
journalctl --user -u syncthing | grep -i error
```

**Check ignore patterns:**
- Web UI → Folder → Edit → Ignore Patterns
- Ensure you're not accidentally ignoring files

---

## Security Notes

1. **Initial passwords:** Both ninho users have `initialPassword = "ninho"` - **CHANGE IMMEDIATELY** after first login
2. **Syncthing web UI:** Only accessible via localhost and VPN (10.100.0.0/24)
3. **No public relays:** Configuration disables public relay servers (VPN-only)
4. **Encryption:** All transfers use TLS (Syncthing's built-in encryption)
5. **Authentication:** Device IDs act as authentication tokens

---

## Advanced Configuration

### Add More Folders

Edit the user-data.nix file for your machine and add to the `folders` section:

**Example for ninho** (`home-manager/users/bolt/user-data.nix`):
```nix
services.syncthing.settings.folders = {
  "x1-laptop-sync" = { ... };  # Existing

  # New folder
  "projects" = {
    path = "${config.userConfig.homeDirectory}/Projects";
    devices = [ "x1-laptop" ];
    versioning = {
      type = "simple";
      params.keep = "10";
    };
  };
};
```

### Selective Sync (Ignore Patterns)

Add ignore patterns in web UI or via configuration in user-data.nix:

```nix
services.syncthing.settings.folders."x1-laptop-sync" = {
  path = "${config.userConfig.homeDirectory}/X1-G8-Laptop";
  devices = [ "x1-laptop" ];
  ignorePatterns = [
    "(?d).git"         # Ignore .git directories
    "*.tmp"            # Ignore temp files
    "node_modules"     # Ignore npm packages
    "*.iso"            # Ignore large ISOs
  ];
};
```

### One-Way Sync (Send-Only/Receive-Only)

**Send-only from laptop** (`home-manager/users/bolt-with-de/user-data.nix`):
```nix
services.syncthing.settings.folders."laptop-to-ninho" = {
  path = "${config.userConfig.homeDirectory}/Documents";
  devices = [ "ninho-server" ];
  type = "sendonly";  # Only send changes, never receive
};
```

**Receive-only on ninho** (`home-manager/users/bolt/user-data.nix`):
```nix
services.syncthing.settings.folders."x1-laptop-sync" = {
  path = "${config.userConfig.homeDirectory}/X1-G8-Laptop";
  devices = [ "x1-laptop" ];
  type = "receiveonly";  # Only receive changes, never send
};
```

---

## Useful Commands Reference

```bash
# Syncthing service management
systemctl --user start syncthing
systemctl --user stop syncthing
systemctl --user restart syncthing
systemctl --user status syncthing

# View logs
journalctl --user -u syncthing -f
journalctl --user -u syncthing --since "1 hour ago"

# CLI operations (requires syncthing CLI)
syncthing cli show status          # Overall status
syncthing cli show devices         # Connected devices
syncthing cli show folders         # Folder sync status
syncthing cli show connections     # Connection details

# ZFS snapshot recovery
zfs list -t snapshot rpool/home                          # List snapshots
ls /home/bolt/.zfs/snapshot/                             # Browse snapshots
cp /home/bolt/.zfs/snapshot/<name>/X1-G8-Laptop/file.txt # Restore file

# Network diagnostics
ping 10.100.0.100                  # Test ninho connectivity
sudo wg show                       # WireGuard status
ss -tlnp | grep 8384              # Check Syncthing port
```

---

## References

- [Syncthing Documentation](https://docs.syncthing.net/)
- [NixOS Syncthing Options](https://search.nixos.org/options?query=services.syncthing)
- [WireGuard Configuration](https://www.wireguard.com/quickstart/)
- [ZFS Snapshots Guide](https://docs.oracle.com/cd/E19253-01/819-5461/gbciq/index.html)
