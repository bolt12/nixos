# bolt-x200: ThinkPad X200 (legacy, incomplete)

Old Intel Core 2 Duo laptop (GM45). This config is an incomplete stub: it has no
`hardware-configuration.nix` (no root filesystem), so its toplevel does not build
and it is left out of `flake checks`. Run `nixos-generate-config` on the X200 and
commit the result before deploying.

The kernel was pinned to `pkgs.linuxPackages_4_19`, which nixpkgs 26.05 removed
(EOL upstream), so the config stopped evaluating. It now tracks
`linuxPackages_6_12` (LTS); the X200 has no special kernel needs.

## What runs here

- TLP with charge thresholds 85/90 (battery health).
- `boot.loader.grub` on `/dev/sda` (legacy BIOS).
- greetd + cage + gtkgreet on X11 (xserver, intel driver).
- The bolt-with-de home-manager profile, attached for user `bolt`.

## Forking notes

- This exists mostly as a scratch surface for old hardware. If you don't have a
  pre-2010 laptop, ignore it entirely.
- Add a real `hardware-configuration.nix` and it can rejoin `flake checks`.
