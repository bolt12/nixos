# NixOS Configuration

## Repository Layout

```
flake.nix                              # Entry point — NixOS configs, HM configs, Colmena, checks
system/
  common/constants.nix                 # Centralized ports, IPs, storage paths
  common/overlays.nix                  # Package overlays (CUDA, unstable, etc.)
  configuration.nix                    # bolt-nixos (X1 Carbon laptop)
  machine/ninho/configuration.nix      # ninho-nixos (home server)
  machine/ninho/services/              # ~25 service modules (Nextcloud, Immich, Jellyfin, etc.)
  machine/rpi/                         # RPi 5 (Tang server, DNS, WireGuard gateway)
  machine/thinkpadx200/                # ThinkPad X200
  machine/x1-g8/                       # X1 Carbon Gen 8 hardware
home-manager/
  common/base.nix                      # Shared HM base (starship, direnv, bat, etc.)
  common/user-options.nix              # Custom options: userConfig.{username,homeDirectory,git,...}
  profiles/{development,system-tools,specialized,desktop,wayland}.nix
  programs/{neovim,git,bash,tmux,emacs,...}/default.nix
  users/bolt/home.nix                  # bolt on ninho (headless)
  users/bolt/user-data.nix             # bolt aliases, Syncthing config
  users/bolt-with-de/home.nix          # bolt on laptop (desktop environment)
  users/pollard/home.nix               # pollard on ninho (headless)
  users/pollard/user-data.nix          # pollard aliases
  users/steam-deck/home.nix            # Steam Deck (standalone HM)
install.sh                             # Interactive rebuild menu with pre-flight safety checks
```

## Multi-User Rules (ninho)

Ninho is shared by **bolt** and **pollard**, each with their own clone at `$HOME/nixos/`.

- **Home-manager first**: user-specific services and data belong in `home-manager/users/<user>/`, not in `system/`. System config is for system-level concerns only (user declarations, groups, system services).
- **No hardcoded home paths in system services**: use `%h` (systemd user specifier) or `config.userConfig.homeDirectory` in HM modules. If a system service genuinely needs a user path, use a NixOS option or `constants.nix`.
- **Dual-checkout model**: both users have independent git clones. Always `git pull` before rebuilding. The `install.sh` pre-flight checks enforce this (aborts if behind `origin/main`).
- **Port allocation**: all service ports go in `system/common/constants.nix` — never hardcode port numbers in service modules.
- **Format with nixfmt**: `nix fmt` uses `nixfmt-rfc-style`.

## Rebuild Commands

| Command | What it does |
|---------|-------------|
| `nixos-rebuild-safe` (or `nrs`) | cd to `$HOME/nixos`, run pre-flight checks, show interactive menu |
| `sudo nixos-rebuild switch --flake .#ninho-nixos` | Direct ninho rebuild (no safety checks) |
| `sudo nixos-rebuild switch --flake .#bolt-nixos` | Direct laptop rebuild |
| `home-manager switch --flake .#bolt` | Standalone HM activation for bolt |
| `home-manager switch --flake .#pollard` | Standalone HM activation for pollard |

## Known Issues

- **Agda libraries** (`home-manager/programs/agda/.agda/libraries`): hardcodes paths into `/home/bolt/Desktop/Bolt/Playground/Agda/...`. Correctly scoped to bolt's HM only. Will break if the Agda playground moves.

## Machine: ninho

Home server — AMD Ryzen 9 9950X3D, ASUS ROG Strix X870E, RTX 5090, 128GB RAM.

### Hardware Watchdog

`sp5100_tco` (AMD) auto-reboots on hard kernel lockups. Configured in `configuration.nix`:
- Module loaded via `boot.kernelModules`
- `systemd.settings.Manager.RuntimeWatchdogSec = "60s"`, `RebootWatchdogSec = "10min"`

The kernel-level RTL8126A `NETDEV WATCHDOG` bug from older kernels was fixed upstream in 6.15+ with the native `r8126` driver. Kernel 6.18 (currently pinned for NVIDIA 580.x compat) includes it, so no userspace recovery is needed.

`pcie_aspm=off` is kept defensively in `boot.kernelParams` (also covers AHCI/SATA).

### Tang/Clevis LUKS Auto-Unlock

Automatic LUKS decryption at boot via Tang (on RPi) and Clevis (in ninho's initrd). Eliminates manual passphrase entry during unattended reboots.

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

### llama-swap / stable-diffusion.cpp

**Key details for future edits:**
- SD3.5 GGUF quantizations (e.g. from second-state) strip the VAE (`first_stage_model` tensors) — a separate `--vae` safetensors file is required when using `--diffusion-model` with split GGUF components in stable-diffusion.cpp
- Wyoming faster-whisper uses CTranslate2 format; whisper.cpp (whisper-server) uses GGML format — model files are not interchangeable between the two
