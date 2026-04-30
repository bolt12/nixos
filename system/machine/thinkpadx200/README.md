# bolt-x200 — ThinkPad X200 (legacy)

Old Intel Core 2 laptop. Pinned to `pkgs.linuxPackages_4_19` because
the userland depends on the legacy kernel — bumping breaks userland
binaries. Note that `linuxPackages_4_19` was archived from current
nixpkgs, so this configuration's evaluation will fail until we drop the
pin or vendor the kernel.

## What runs here

- TLP with charge thresholds 85/90 (battery health).
- `boot.loader.grub` on `/dev/sda` (legacy BIOS).
- A minimal `programs.sway`/Wayland-free environment.
- The bolt-with-de home-manager profile.

## Forking notes

- This config exists mostly as a scratch surface for old hardware. If
  you don't have a pre-2010 laptop, ignore it entirely.
- If you want to keep it alive, swap `pkgs.linuxPackages_4_19` to
  whatever the oldest still-supported `linuxPackages_X_Y` is in your
  nixpkgs pin and rebuild userland.
