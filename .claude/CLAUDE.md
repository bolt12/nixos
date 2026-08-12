# NixOS Configuration

## Repository Layout

```
flake.nix                              # Entry point: NixOS configs, HM configs, Colmena, checks
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
- **Port allocation**: all service ports go in `system/common/constants.nix`, never hardcoded in service modules.
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

Home server: AMD Ryzen 9 9950X3D, ASUS ROG Strix X870E, RTX 5090, 128GB RAM.

### Hardware Watchdog

`sp5100_tco` (AMD) auto-reboots on hard kernel lockups. Configured in `configuration.nix`:
- Module loaded via `boot.kernelModules`
- `systemd.settings.Manager.RuntimeWatchdogSec = "60s"`, `RebootWatchdogSec = "10min"`

The kernel-level RTL8126A `NETDEV WATCHDOG` bug from older kernels was fixed upstream in 6.15+ with the native `r8126` driver. Kernel 6.18 (currently pinned for NVIDIA 580.x compat) includes it, so no userspace recovery is needed.

`pcie_aspm=off` is kept defensively in `boot.kernelParams` (also covers AHCI/SATA).

### Tang/Clevis LUKS Auto-Unlock

Automatic LUKS decryption at boot via Tang (on RPi) and Clevis (in ninho's initrd). Eliminates manual passphrase entry during unattended reboots.

**Architecture:**
- **Tang server**: RPi at `192.168.1.110:7654` (`system/machine/rpi/rpi5.nix`, `constants.ports.tang`)
- **Clevis client**: `boot.initrd.clevisLuksAskpass` (ninho `boot.nix`) answers each device's systemd LUKS prompt from a clevis token bound into that device's LUKS2 header. No JWE files and no `boot.initrd.secrets` for the unlock: the token lives in the header, so enrollment is per-device on the running system.
- **Initrd networking**: systemd stage-1 DHCP on `enp11s0` (`boot.initrd.systemd.network.networks."10-enp11s0"`), with `r8169` added to `boot.initrd.availableKernelModules` in `boot.nix`.
- **SSH fallback**: port 2222 (not 22, a separate host key avoids known_hosts conflicts). The host key is the one secret still on disk, `/etc/secrets/initrd/ssh_host_ed25519_key`, added to the initrd by `boot.initrd.network.ssh.hostKeys`.

**Enrollment** (once per device after initial deploy, or after a Tang key rotation):
1. Deploy Tang to the RPi: `eval $(ssh-agent) && ssh-add ~/.ssh/id_ed25519 && colmena apply --on rpi-5 --impure`
2. Verify Tang: `ssh root@192.168.1.110 "curl -sf http://127.0.0.1:7654/adv" | jq .`
3. Generate the initrd SSH host key (first time only): `sudo ssh-keygen -t ed25519 -N "" -f /etc/secrets/initrd/ssh_host_ed25519_key`
4. Bind each LUKS device to Tang, for every UUID under `boot.initrd.luks.devices` in `boot.nix`:
   ```
   sudo clevis luks bind -d /dev/disk/by-uuid/<uuid> tang '{"url":"http://192.168.1.110:7654"}'
   ```
5. Reboot and verify: `journalctl -b | grep -i clevis`

**SSH fallback** (if Tang is unreachable at boot):
```
ssh -p 2222 root@<ninho-lan-ip>
# cryptsetup-askpass runs automatically; type the passphrase
```

**Key details for future edits:**
- `boot.initrd.availableKernelModules` is set in `boot.nix` (not `hardware-configuration.nix`) to add `r8169`.
- `flushBeforeStage2 = true` tears down initrd networking so NetworkManager starts clean in stage 2.
- The clevis token is per-device (bound into each LUKS2 header), so a device's passphrase can change independently; re-bind that device with step 4 afterwards.
- Tang is stateless. Rotating its keys requires re-binding every Clevis client (rerun step 4 per device).
- Colmena RPi deploy requires: ssh-agent with the key loaded, `--impure`, and `targetUser = "root"` (no interactive sudo).

### llama-swap / stable-diffusion.cpp

**Key details for future edits:**
- SD3.5 GGUF quantizations (e.g. from second-state) strip the VAE (`first_stage_model` tensors), so a separate `--vae` safetensors file is required when using `--diffusion-model` with split GGUF components in stable-diffusion.cpp
- Wyoming faster-whisper uses CTranslate2 format; whisper.cpp (whisper-server) uses GGML format, and model files are not interchangeable between the two
