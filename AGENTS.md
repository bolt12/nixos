# AGENTS.md — NixOS Configuration Repository

Instructions for AI agents working on this codebase. Read fully before making changes.

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

## Rules

1. **Home-manager first**: user-specific services and data belong in `home-manager/users/<user>/`, not in `system/`. System config (`system/`) is for system-level concerns only: user declarations, groups, lingering, hardware, system-wide services.

2. **No hardcoded home paths in system services**: use `%h` (systemd user specifier) or `config.userConfig.homeDirectory` in HM modules. If a system service genuinely needs a user path, use a NixOS option or `constants.nix`.

3. **Dual-checkout model**: ninho is shared by **bolt** and **pollard**, each with their own clone at `$HOME/nixos/`. Never assume a single source of truth. Always verify the repo is up-to-date before rebuilding (`install.sh` enforces this with pre-flight checks).

4. **Port allocation**: all service ports go in `system/common/constants.nix`. Never hardcode port numbers in service modules — import `constants` and use `constants.ports.<name>`.

5. **Format with nixfmt**: run `nix fmt` (uses `nixfmt-rfc-style`). Check before committing.

6. **Never commit directly to main without review**. Use feature branches for non-trivial changes.

7. **Never apply a NixOS rebuild** without verifying the repo is in sync with `origin/main`. Use `nixos-rebuild-safe` or run `git fetch && git status` first.

8. **Never post comments, replies, or reviews on GitHub PRs/issues** unless explicitly asked.

## Multi-User Architecture (ninho)

| User | Home-Manager Config | Role |
|------|-------------------|------|
| bolt | `home-manager/users/bolt/home.nix` | Primary admin, Haskell dev |
| pollard | `home-manager/users/pollard/home.nix` | Software engineer, learning NixOS |

Both users are declared in `system/machine/ninho/configuration.nix` (groups, SSH keys, lingering). Their packages, services, and dotfiles are entirely in HM.

### File Ownership

| Path | Owner | Managed by |
|------|-------|-----------|
| `system/machine/ninho/configuration.nix` | root (system) | `nixos-rebuild switch` |
| `system/machine/ninho/services/*.nix` | root (system) | `nixos-rebuild switch` |
| `home-manager/users/bolt/*` | bolt | HM via `nixos-rebuild` or standalone `home-manager switch` |
| `home-manager/users/pollard/*` | pollard | HM via `nixos-rebuild` or standalone `home-manager switch` |
| `system/common/constants.nix` | shared | Both system and HM modules import this |

## Module Structure

- **User options** (`home-manager/common/user-options.nix`): defines `userConfig.{username, homeDirectory, git.userName, git.userEmail, git.signingKey, bash.extraAliases}`. Every user's `home.nix` sets these.
- **Profiles** (`home-manager/profiles/`): package bundles imported by user configs. `development.nix` = compilers, tools; `system-tools.nix` = monitoring, networking; `specialized.nix` = Agda, Lean, Arduino.
- **Programs** (`home-manager/programs/`): per-program configuration (neovim, git, bash, etc.), imported by user configs.
- **Services** (`system/machine/ninho/services/`): each service is a separate `.nix` file, imported via `services/default.nix`. All use `constants.ports` for port numbers.

## Rebuild Commands

| Command | What it does |
|---------|-------------|
| `nixos-rebuild-safe` (or `nrs`) | cd to `$HOME/nixos`, run pre-flight checks, show interactive menu |
| `sudo nixos-rebuild switch --flake .#ninho-nixos` | Direct ninho rebuild (no safety checks) |
| `sudo nixos-rebuild switch --flake .#bolt-nixos` | Direct laptop rebuild |
| `sudo nixos-rebuild dry-activate --flake .#ninho-nixos` | Dry-run (evaluate + build, no activation) |
| `home-manager switch --flake .#bolt` | Standalone HM activation for bolt |
| `home-manager switch --flake .#pollard` | Standalone HM activation for pollard |
| `nix flake check` | Validate flake (runs checks defined in `flake.nix`) |
| `nix fmt` | Format all `.nix` files with `nixfmt-rfc-style` |

## Known Issues

- **Agda libraries** (`home-manager/programs/agda/.agda/libraries`): hardcodes paths into `/home/bolt/Desktop/Bolt/Playground/Agda/...`. Correctly scoped to bolt's HM only. Will break if the Agda playground moves.

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

**Key details for future edits:**
- `boot.initrd.availableKernelModules` is overridden in `configuration.nix` (not `hardware-configuration.nix`) to add `r8169`
- `flushBeforeStage2 = true` tears down initrd networking so NetworkManager starts clean
- Each LUKS device has its own JWE file (allows per-device passphrase changes later)
- Tang is stateless — rotating keys requires re-enrolling all Clevis clients

### llama-swap / stable-diffusion.cpp

**Key details for future edits:**
- SD3.5 GGUF quantizations (e.g. from second-state) strip the VAE (`first_stage_model` tensors) — a separate `--vae` safetensors file is required when using `--diffusion-model` with split GGUF components in stable-diffusion.cpp
- Wyoming faster-whisper uses CTranslate2 format; whisper.cpp (whisper-server) uses GGML format — model files are not interchangeable between the two
