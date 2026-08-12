# AGENTS.md: NixOS Configuration Repository

Instructions for AI agents working on this codebase. Read fully before making changes.

## Repository Layout

```
flake.nix                              # Entry point: NixOS configs, HM configs, Colmena, checks
system/
  common/constants.nix                 # Centralized ports, IPs, storage paths
  common/overlays.nix                  # Package overlays (CUDA, unstable, etc.)
  machine/ninho/configuration.nix      # ninho-nixos (home server)
  machine/ninho/services/              # ~25 service modules (Nextcloud, Immich, Jellyfin, etc.)
  machine/hetzner/                     # hetzner (public WireGuard hub + tunnel DNS)
  machine/rpi/                         # RPi 5 (Tang server, LAN DNS)
  machine/thinkpadx200/                # ThinkPad X200 (incomplete stub)
  machine/x1-g8/                       # bolt-nixos (X1 Carbon Gen 8 laptop)
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

4. **Port allocation**: all service ports go in `system/common/constants.nix`. Never hardcode port numbers in service modules. Import `constants` and use `constants.ports.<name>`.

5. **Format with nixfmt**: run `nix fmt` (uses `nixfmt-rfc-style`). Check before committing.

6. **Never commit directly to main without review**. Use feature branches for non-trivial changes.

7. **Never apply a NixOS rebuild** without verifying the repo is in sync with `origin/main`. Use `nixos-rebuild-safe` or run `git fetch && git status` first.

8. **Never post comments, replies, or reviews on GitHub PRs/issues** unless explicitly asked.

## Multi-User Architecture (ninho)

| User | Home-Manager Config | Role |
|------|-------------------|------|
| bolt | `home-manager/users/bolt/home.nix` | Primary admin, Haskell dev |
| pollard | `home-manager/users/pollard/home.nix` | Software engineer, learning NixOS |

Both users are declared in `system/machine/ninho/users.nix` (groups, SSH keys, lingering). Their packages, services, and dotfiles are entirely in HM.

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

Home server: AMD Ryzen 9 9950X3D, ASUS ROG Strix X870E, RTX 5090, 128GB RAM.

### Network / RTL8126A NIC

The RTL8126A 5 GbE NIC hit `NETDEV WATCHDOG` transmit-queue timeouts under the old `r8169` driver. Kernel 6.15+ ships the native `r8126` driver, which fixes it, and ninho runs 6.18 (pinned for NVIDIA driver compat), so the old userland recovery service and preventive-reboot timer are retired. `pcie_aspm=off` stays in `boot.kernelParams` defensively (also covers AHCI/SATA).

**Supporting services:**
- `wol-enable.service`: enables Wake-on-LAN on `enp11s0` once NetworkManager is up (for RPi-based remote power-on).
- `systemd.watchdog`: hardware watchdog via `sp5100_tco` (60s runtime, 10min reboot timeout).

**Key detail:** WireGuard uses `networking.wireguard.interfaces.wg0`, which creates `wireguard-wg0.service` (NOT `wg-quick-wg0`).

### Tang/Clevis LUKS Auto-Unlock

Automatic LUKS decryption at boot via Tang (on the RPi) and Clevis (in ninho's initrd), so unattended reboots don't wait at a passphrase prompt.

**Architecture:**
- **Tang server**: RPi at `192.168.1.110:7654` (`system/machine/rpi/rpi5.nix`, `constants.ports.tang`).
- **Clevis client**: `boot.initrd.clevisLuksAskpass` (ninho `boot.nix`) unlocks all 5 LUKS devices from clevis tokens bound into each LUKS2 header. No JWE files and no `boot.initrd.secrets` for the unlock: the token lives in the header, enrolled per-device with `clevis luks bind` on the running system.
- **Initrd networking**: systemd stage-1 DHCP on `enp11s0` (`boot.initrd.systemd.network`), `r8169` in initrd modules.
- **SSH fallback**: port 2222 (not 22; a separate host key avoids known_hosts conflicts).

**Key details for future edits:**
- `boot.initrd.availableKernelModules` is set in `boot.nix` (not `hardware-configuration.nix`) to add `r8169`.
- `flushBeforeStage2 = true` tears down initrd networking so NetworkManager starts clean in stage 2.
- Each LUKS device carries its own clevis token in its LUKS2 header (allows per-device passphrase changes later).
- Tang is stateless: rotating its keys requires re-binding every Clevis client.

### llama-swap / stable-diffusion.cpp

**Key details for future edits:**
- SD3.5 GGUF quantizations (e.g. from second-state) strip the VAE (`first_stage_model` tensors), so a separate `--vae` safetensors file is required when using `--diffusion-model` with split GGUF components in stable-diffusion.cpp.
- Wyoming faster-whisper uses CTranslate2 format; whisper.cpp (whisper-server) uses GGML format, and model files are not interchangeable between the two.
