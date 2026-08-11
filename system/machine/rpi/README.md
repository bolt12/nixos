# rpi-nixos, Raspberry Pi 5 (LAN adblock DNS + Tang)

Always-on home box. Since the ISP switch removed the home public IP, the
**WireGuard server role moved to the Hetzner hub** (`system/machine/hetzner/`);
this RPi is now LAN-only. Two roles remain:

1. **LAN adblock DNS** via `unbound` + the `hagezi-pro` RPZ blocklist, configured
   through the shared `services.adblockDns` module
   (`system/common/services/unbound-adblock.nix`). Binds `0.0.0.0` and answers
   the LAN (`ninho` uses it at `192.168.1.110`). Access-control allows the
   LAN + VPN subnets.
2. **Tang server** on `127.0.0.1:7654` so ninho's initrd can decrypt LUKS without
   a passphrase. Allowed IPs are loopback + `${constants.network.lan.subnet}` +
   `${constants.network.wireguard.subnet}`. Reached over the LAN, so the WG move
   does not affect it.

Also runs the `emanote` journal on `${constants.ports.emanote}` (writes to
`/home/bolt/journal`; single-user) and sends a Wake-on-LAN packet to bring ninho
back after a mains outage.

## Deploying

Built locally via QEMU binfmt emulation and pushed with Colmena (no on-target
builds):

```
eval $(ssh-agent) && ssh-add ~/.ssh/id_ed25519
colmena apply --on rpi-5 --impure
```

`--impure` is required because raspberry-pi-nix touches the build-time
environment.

## Forking notes

- The adblock resolver is shared with the hub via `services.adblockDns`; this
  host sets `user = "bolt"`, `interfaces = [ "0.0.0.0" ]`, and an LAN/VPN
  `accessControl`. The public, tunnel-only variant lives in
  `system/machine/hetzner/dns.nix`.
- The `accessControl` allows `192.168.0.0/16` and `10.100.0.0/16` (intentionally
  broader than the exact LAN/VPN subnets: both `/16`s are deliberate, not typos).
- `network-watchdog.nix` is no longer needed: kernel 6.15+ has the native r8126
  driver; the userland recovery script that used to live in `services/` was
  retired.
