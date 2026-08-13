# rpi-nixos, Raspberry Pi 5 (LAN adblock DNS + Tang + tailnet node)

Always-on home box. Three roles:

1. **LAN adblock DNS** via `unbound` + the `hagezi-pro` RPZ blocklist, configured
   through the shared `services.adblockDns` module
   (`system/common/services/unbound-adblock.nix`). Binds `0.0.0.0` and answers the
   LAN (`192.168.0.0/16`); ninho and the laptop use the hub resolver over Tailscale
   as primary and this RPi (`192.168.1.110`) as the LAN fallback.
2. **Tang server** on `127.0.0.1:7654` so ninho's initrd can decrypt LUKS without a
   passphrase. Allowed IPs are loopback + `${constants.network.lan.subnet}`. Reached
   over the LAN.
3. **Tailnet node** (`100.64.0.1`) via `services.headscaleClient`, so the box and
   its services are reachable off-LAN over Tailscale.

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
environment. Place the tailscale authkey at `/etc/tailscale/authkey` before the
first deploy that enables the client.

## Forking notes

- The adblock resolver is shared with the hub via `services.adblockDns`; this host
  sets `user = "bolt"`, `interfaces = [ "0.0.0.0" ]`, and a LAN `accessControl`
  (`192.168.0.0/16 allow`, deliberately the whole `/16`, not a typo). The public,
  tailnet-served variant lives in `system/machine/hetzner/dns.nix`.
- `network-watchdog.nix` is no longer needed: kernel 6.15+ has the native r8126
  driver; the userland recovery script that used to live in `services/` was
  retired.
