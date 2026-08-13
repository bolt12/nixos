# ninho: home server

AMD Ryzen 9 9950X3D · ASUS ROG Strix X870E · RTX 5090 · 128 GB RAM ·
2× NVMe (rpool mirror) + 3× HDD (storage RAIDZ1).

Hostname: `nixos-ninho` · ZFS hostId: `d8e24c1d` (LUKS-encrypted disks
auto-unlocked at boot via Tang on the RPi).

## What runs here

Top-level layout under `services/`:

- `nextcloud`, `immich`, `jellyfin`
- `*arr` stack via `servarr.nix` + `bazarr` + `deluge` + `bitmagnet`
- `home-assistant` (split into config domains under `services/home-assistant/`)
- `monitoring` (Prometheus + exporters + Grafana, split per concern)
- `llama-cpp` + `llama-cpp/models.nix` (llama-swap with 13 models, FLUX,
  SD3.5, Whisper, Jina reranker)
- `faster-whisper` + Wyoming voice grid (en/pt)
- `homepage` (dashboard), `ntfy`, `atuin`, `attic`, `miniflux`,
  `anki-sync-server`, `open-webui`, `redlib`, `frigate` + `pet-report`,
  `supernote`, `gaming` (Steam + Sunshine).

System-level pieces split out of `configuration.nix`:

- `boot.nix`: kernel 6.18, initrd modules, LUKS + Clevis unlock, GRUB.
- `networking.nix`: NetworkManager, DNS (hub adblock resolver over Tailscale,
  RPi LAN fallback), firewall, Tailscale client via `services.headscaleClient`
  (`100.64.0.3`), game-streaming sysctl tuning.
- `storage.nix`: ZFS pools, sanoid snapshot policies, storage seed dirs.
- `users.nix`: bolt + pollard (initial password `"ninho"`, change ASAP).

## Gotchas worth knowing

- **Kernel pin (6.18).** 6.19 breaks NVIDIA 580.x
  (`vm_area_struct.__vm_flags` removed). Don't bump until upstream catches
  up.
- **NVIDIA-only.** RTX 5090 is hard-coded into kernelModules, NVENC for
  Jellyfin, gaming.nix, and CUDA. Forks on AMD/Intel must rip these out.
- **Tang/Clevis.** Initrd contacts the RPi (`192.168.1.110:7654`) to unlock
  the 5 LUKS volumes from clevis tokens bound into each LUKS2 header
  (`boot.initrd.clevisLuksAskpass`). Manual SSH-based fallback on port 2222.
  See the top-level `CLAUDE.md`, "Tang/Clevis LUKS Auto-Unlock", for
  enrollment steps.
- **r8169 in initrd.** RTL8126A 5 GbE NIC needs the r8169 driver baked
  into initrd for Tang networking (`boot.initrd.availableKernelModules`).
- **Hardware watchdog.** `sp5100_tco` reboots on hard kernel lockups
  (60s runtime, 10min reboot timeout).
