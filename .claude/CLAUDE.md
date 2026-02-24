# NixOS Configuration

## Machine: ninho

Home server — AMD Ryzen 9 9950X3D, ASUS ROG Strix X870E, RTX 5090, 128GB RAM.

### Network Watchdog (RTL8126A)

The RTL8126A 5 GbE NIC uses the `r8169` driver which suffers from `NETDEV WATCHDOG` transmit queue timeouts roughly every 7 days. The dedicated `r8126` driver won't land upstream until kernel 6.15+. Kernel params (`pcie_aspm=off`, `r8169.aspm=0`, `r8169.use_dac=1`) mitigate but don't prevent the issue.

**Recovery system** (`services/network-watchdog.nix` + `scripts/network-watchdog.sh`):
- Runs every 30s via systemd timer, escalates through 4 levels (3 consecutive failures per level):
  - L1: interface bounce (`ip link down/up`)
  - L2: NetworkManager reconnect
  - L3: `modprobe -r r8169 && modprobe r8169` + restart NM + restart WireGuard
  - L4: system reboot (defers up to 3x if ZFS scrub in progress)
- State persisted in `/var/lib/network-watchdog/state`
- Notifications via ntfy on `http://127.0.0.1:8106/network-watchdog`

**Supporting services:**
- `wol-enable.service` — enables Wake-on-LAN on `enp11s0` after NetworkManager is up (for RPi-based remote recovery)
- `preventive-reboot.timer` — calendar-based reboot every ~6 days at 04:00 (`*-*-01,07,13,19,25`), skips during ZFS scrub
- `systemd.watchdog` — hardware watchdog via `sp5100_tco` (60s runtime, 10min reboot timeout)

**Key details for future edits:**
- WireGuard uses `networking.wireguard.interfaces.wg0` which creates `wireguard-wg0.service` (NOT `wg-quick-wg0`)
- Gateway is discovered dynamically via `ip route show default` (no hardcoded IPs)
- The script runs without `set -e` because recovery commands (especially L3 modprobe) must not abort mid-sequence
- Cooldowns only gate same-level retries, not escalation to higher levels

### Tang/Clevis LUKS Auto-Unlock

Automatic LUKS decryption at boot via Tang (on RPi) and Clevis (in ninho's initrd). Eliminates manual passphrase entry during unattended reboots (network watchdog, preventive reboot timer).

**Architecture:**
- **Tang server**: RPi at `192.168.1.110:7654` (`system/machine/rpi/rpi5.nix`)
- **Clevis client**: ninho initrd contacts Tang to decrypt JWE → unlock all 5 LUKS devices
- **Initrd networking**: DHCP on `enp11s0` via `ip=:::::enp11s0:dhcp` kernel param, `r8169` in initrd modules
- **SSH fallback**: port 2222 (not 22 — separate host key avoids known_hosts conflicts)

**Secrets** (stored in `/etc/secrets/initrd/`, injected via `boot.initrd.secrets`):
- `luks-rpool-nvme0n1-part2.jwe`, `luks-rpool-nvme1n1-part2.jwe` — root pool NVMe
- `luks-storage-sd{a,b,c}-part2.jwe` — storage pool HDDs
- `ssh_host_ed25519_key` — initrd SSH host key

**Manual enrollment steps** (required after initial deploy or key rotation):
1. Deploy Tang to RPi: `eval $(ssh-agent) && ssh-add ~/.ssh/id_ed25519 && colmena apply --on rpi-5 --impure`
2. Verify Tang: `ssh root@192.168.1.110 "curl -sf http://127.0.0.1:7654/adv" | jq .`
3. Generate initrd SSH key: `sudo ssh-keygen -t ed25519 -N "" -f /etc/secrets/initrd/ssh_host_ed25519_key`
4. Create JWE files:
   ```
   echo -n "PASSPHRASE" | sudo clevis encrypt tang '{"url":"http://192.168.1.110:7654"}' | sudo tee /etc/secrets/initrd/luks-rpool-nvme0n1-part2.jwe > /dev/null
   for dev in luks-rpool-nvme1n1-part2 luks-storage-sda-part2 luks-storage-sdb-part2 luks-storage-sdc-part2; do
     sudo cp /etc/secrets/initrd/luks-rpool-nvme0n1-part2.jwe /etc/secrets/initrd/${dev}.jwe
   done
   sudo chmod 600 /etc/secrets/initrd/*.jwe
   ```
5. Rebuild ninho (bakes JWE into initrd): `sudo nixos-rebuild switch --flake .#ninho-nixos`
6. Reboot and verify: `journalctl -b | grep -i clevis`

**SSH fallback** (if Tang unreachable during boot):
```
ssh -p 2222 root@<ninho-lan-ip>
# cryptsetup-askpass runs automatically
```

**Key details for future edits:**
- `boot.initrd.availableKernelModules` is overridden in `configuration.nix` (not `hardware-configuration.nix`) to add `r8169`
- `flushBeforeStage2 = true` tears down initrd networking so NetworkManager starts clean
- Each LUKS device has its own JWE file (allows per-device passphrase changes later)
- Tang is stateless — rotating keys requires re-enrolling all Clevis clients
- `boot.initrd.secrets` files must exist on disk before `nixos-rebuild switch` — create placeholders if enrolling later
- Colmena RPi deploy requires: ssh-agent with key loaded, `--impure` flag, `targetUser = "root"` (no interactive sudo support)
