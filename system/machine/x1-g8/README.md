# bolt-nixos: ThinkPad X1 Carbon Gen 8

Intel UHD 620 graphics, fcitx5 input method, niri/Wayland desktop,
WireGuard client at `10.100.0.2/24` to the RPi gateway.

## What runs here

- TLP for battery thresholds (start 85%, stop 90%) and per-AC/BAT
  governor profiles.
- PipeWire + WirePlumber audio.
- greetd + cage + gtkgreet for login (niri session, Sway as fallback).
- Bluetooth, CUPS printing, Flatpak, fwupd.
- WireGuard `wg0` peering to the RPi at
  `${constants.network.rpi.hostname}:${constants.network.wireguard.port}`,
  routing only the VPN subnet (avoids the boot-time default-route
  conflict that existed when `0.0.0.0/0` was allowed).

## Forking notes

- The home-manager user `bolt` is wired in from
  `home-manager/users/bolt-with-de/home.nix`. Swap usernames there +
  `userConfig.username` to rename.
- WireGuard private key lives at `constants.paths.wireguardPrivateKey`
  (`/etc/wireguard/private`); install once before deploying.
- `nixos-hardware.nixosModules.lenovo-thinkpad-x1-7th-gen` is imported
  via `flake.nix`. There is no `x1-8th-gen` module upstream: the modules
  jump from 7th to 9th gen, and the Gen 8 X1 Carbon shares the Gen 7 Comet
  Lake platform, so 7th-gen is the correct closest match (not a typo). Drop
  or replace for non-X1 hardware.
