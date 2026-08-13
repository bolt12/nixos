# bolt-nixos: ThinkPad X1 Carbon Gen 8

Intel UHD 620 graphics, fcitx5 input method, niri/Wayland desktop, and a Tailscale
client (`100.64.0.2`) on the self-hosted Headscale tailnet.

## What runs here

- TLP for battery thresholds (start 85%, stop 90%) and per-AC/BAT governor
  profiles.
- PipeWire + WirePlumber audio.
- greetd + cage + gtkgreet for login (niri session, Sway as fallback).
- Bluetooth, CUPS printing, Flatpak, fwupd.
- Tailscale client via `services.headscaleClient` (the shared
  `system/common/services/tailscale-client.nix`), joined to the Headscale hub for
  a DIRECT path to ninho (game streaming) and general access, behind one stable
  address that works at home and away.

## Forking notes

- The home-manager user `bolt` is wired in from
  `home-manager/users/bolt-with-de/home.nix`. Swap usernames there +
  `userConfig.username` to rename.
- The tailscale authkey is hand-placed at `/etc/tailscale/authkey` (minted with
  `headscale preauthkeys create` on the hub). Place it before the first rebuild
  that enables the client, or `tailscaled-autoconnect` hangs 90s and fails the
  deploy.
- `nixos-hardware.nixosModules.lenovo-thinkpad-x1-7th-gen` is imported via
  `flake.nix`. There is no `x1-8th-gen` module upstream: the modules jump from 7th
  to 9th gen, and the Gen 8 X1 Carbon shares the Gen 7 Comet Lake platform, so
  7th-gen is the correct closest match (not a typo). Drop or replace for non-X1
  hardware.
