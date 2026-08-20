# rpi-nixos, Raspberry Pi 5 (LAN adblock DNS + Tang + tailnet node)

Always-on home box. Three roles:

1. **LAN adblock DNS** via `unbound` + the `hagezi-pro` RPZ blocklist, configured
   through the shared `services.adblockDns` module
   (`system/common/services/unbound-adblock.nix`). Binds `0.0.0.0` and answers the
   LAN (`192.168.0.0/16`); ninho and the laptop use the hub resolver over Tailscale
   as primary and this RPi (`192.168.1.110`) as the LAN fallback.
2. **Tang server** on `${constants.ports.tang}`, listening on the LAN so ninho's
   initrd can decrypt LUKS without a passphrase. The systemd socket sets
   `IPAddressDeny = "any"` with `ipAddressAllow` of loopback +
   `${constants.network.lan.subnet}`, which is what keeps it off the internet;
   note that ACL is IPv4-only, so a client reaching this box over IPv6 is denied.

   This host's address is load-bearing and not free to change: ninho's five LUKS2
   headers carry clevis tokens naming `192.168.1.110` literally, and its stage-1
   networking is IPv4 DHCP. Hold the address with a reservation on the router.
   Losing the old router's reservation is what broke ninho's unattended boot in
   August 2026.
3. **Tailnet node** (`100.64.0.9`) via `services.headscaleClient`, so the box and
   its services are reachable off-LAN over Tailscale. It held `100.64.0.1` until
   the 2026-08 reflash; see the authkey note under Deploying for why the address
   climbs instead of coming back.

Also runs the `emanote` journal on `${constants.ports.emanote}` (writes to
`/home/bolt/journal`; single-user) and sends a Wake-on-LAN packet to bring ninho
back after a mains outage.

## Deploying

Built locally via QEMU binfmt emulation and pushed with Colmena (no on-target
builds):

```
eval $(ssh-agent)
SSH_ASKPASS_REQUIRE=never ssh-add ~/.ssh/id_ed25519
colmena apply --on rpi-5 --impure
```

All three in one shell, or `SSH_AUTH_SOCK` does not carry. `SSH_ASKPASS_REQUIRE`
is not optional on ninho: gnome-keyring points `SSH_ASKPASS` at `x11-ssh-askpass`
and the box is headless, so a plain `ssh-add` blocks forever on a prompt that
cannot draw. The symptom is a push failing with `Permission denied` while the Pi
logs `Connection closed by authenticating user root [preauth]`.

`--impure` is for the flake hive input, which colmena cannot lock.

Place the tailscale authkey at `/etc/tailscale/authkey` before the first deploy
that enables the client, and again after every reflash. It lives on the root
filesystem, not in the image, so imaging wipes it along with
`/var/lib/tailscale/tailscaled.state`. Without the state file tailscaled mints a
fresh machine key, headscale cannot tie that to the old row, and the Pi lands as
a brand new node on the next free address (headscale allocates sequentially and
never walks back into addresses a deleted node freed). Skipping this step in
August 2026 cost four registrations and moved the Pi from `100.64.0.1` to
`100.64.0.9`. `tailscale-client.nix` warns at activation when the file is
missing, but the warning scrolls past in a colmena run, so place it first:

```
ssh root@<hub> cat /etc/tailscale/authkey \
  | ssh root@192.168.1.110 install -D -m600 /dev/stdin /etc/tailscale/authkey
```

## Forking notes

- The adblock resolver is shared with the hub via `services.adblockDns`; this host
  sets `user = "bolt"`, `interfaces = [ "0.0.0.0" ]`, and a LAN `accessControl`
  (`192.168.0.0/16 allow`, deliberately the whole `/16`, not a typo). The public,
  tailnet-served variant lives in `system/machine/hetzner/dns.nix`.
- `network-watchdog.nix` is no longer needed: kernel 6.15+ has the native r8126
  driver; the userland recovery script that used to live in `services/` was
  retired.
- This host builds from `nixpkgs-unstable`, not the 26.05 pin the other machines
  use, via `meta.nodeNixpkgs.rpi-5` in `flake.nix`. Pi 5 support in
  `sd-image-aarch64.nix` (a single `u-boot.bin`, the `[pi5]` and `[cm5]`
  `config.txt` sections, the bcm2712 dtbs) landed after 26.05 branched. Booting
  is upstream u-boot chainloading `extlinux.conf` off ext4, so nothing writes to
  the 30 MiB FAT partition after flashing.
- raspberry-pi-nix was dropped. Its `firmware-migration-service` copied the
  kernel onto that FAT partition on every activation and, running without
  `set -e`, installed a truncated one rather than failing when it ran out of
  room.
