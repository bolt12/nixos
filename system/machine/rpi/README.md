# rpi-nixos — Raspberry Pi 5 (gateway, DNS, VPN, Tang)

Always-on edge box. Three roles:

1. **WireGuard server** at `10.100.0.1/24`, port 51820. Every other host
   in the fleet is a peer (ninho, x1, phone, steam-deck, supernote,
   pollard's phone+macOS).
2. **Recursive DNS** via `unbound` with the `hagezi-pro` RPZ blocklist
   (config in `services/dns-blocklist.nix`). Listens on
   `127.0.0.1:53` + the WireGuard subnet.
3. **Tang server** on `127.0.0.1:7654` so ninho's initrd can decrypt
   LUKS without typing a passphrase. Allowed IPs are loopback +
   `${constants.network.lan.subnet}` + `${constants.network.wireguard.subnet}`.

Also runs the `emanote` public journal gateway on
`${constants.ports.emanote}` (writes to `/home/bolt/journal`; designed
single-user).

## Deploying

The RPi is built locally via QEMU binfmt emulation and pushed with
Colmena (no on-target builds):

```
eval $(ssh-agent) && ssh-add ~/.ssh/id_ed25519
colmena apply --on rpi-5 --impure
```

`--impure` is required because raspberry-pi-nix touches the
build-time environment.

## Forking notes

- The peer table at the bottom of `rpi5.nix` is per-device. Replace each
  `publicKey` with your peer's `wg pubkey` output and pick a free
  `10.100.0.X/32`.
- `services.unbound.settings.server.access-control` allows
  `192.168.0.0/16` and `10.100.0.0/16` (intentionally broader than the
  LAN/VPN subnets — both `/16`s are deliberate, not typos).
- `network-watchdog.nix` is no longer needed: kernel 6.15+ has the
  native r8126 driver; the userland recovery script that used to live in
  `services/` was retired.
