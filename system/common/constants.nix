# =============================================================================
# Centralized constants: single source of truth for ports, IPs, paths.
# =============================================================================
#
# Imported via flake `specialArgs` and reachable in every system/HM module
# as `constants` (no need to `import` it manually).
#
# Two flavours of value live here:
#
#   1. INFRASTRUCTURE-SPECIFIC. LAN topology, ZFS pool layout, VPN IPs,
#      hostnames, public keys. **You almost certainly want to change these
#      when forking**: they describe my home network, not yours.
#
#   2. CONVENTIONAL. Port allocations, Wyoming TTS/STT port grid,
#      `paths.wireguardPrivateKey`. Likely fine to keep as-is; pick
#      different ports only if you have a clash on your network.
#
# Each section below is annotated.
# =============================================================================
let
  # Bare VPN addresses. The /24 CIDR forms under `wireguard` below are derived
  # from these so a hand-edit can't leave the mask out of sync with the address
  # (unbound binds the bare form on the hub; wg0 assigns the CIDR form).
  ninhoVpnIp = "10.100.0.100";
  hubVpnIp = "10.100.0.1";
in
{
  # ---------------------------------------------------------------------------
  # Network: INFRASTRUCTURE-SPECIFIC
  # ---------------------------------------------------------------------------
  # `ninho` is my home server. `hub` is a Hetzner Cloud VM that is the public
  # WireGuard server + tunnel DNS resolver (it took over from the RPi when the
  # home ISP switch removed the public IP). `rpi` is now LAN-only (Tang + local
  # adblock DNS). The WireGuard subnet (`10.100.0.0/24`) is private and
  # arbitrary; pick anything that doesn't collide with your LAN or other VPNs.
  # `serverPubKey` is derived from the hub's WireGuard private key (reused from
  # the RPi): rotate here whenever that key rotates.
  network = {
    lan = {
      subnet = "192.168.1.0/24";
      gateway = "192.168.1.254";
    };
    ninho = {
      vpnIp = ninhoVpnIp;
      hostname = "ninho.local";
      # Wired NIC (RTL8126A) + its MAC. Used to arm Wake-on-LAN on ninho and to
      # target the magic packet from the RPi so it can power ninho back on after
      # a mains outage.
      lanInterface = "enp11s0";
      lanMac = "a0:ad:9f:13:7e:80";
    };
    # Public WireGuard hub + tunnel DNS resolver (Hetzner Cloud VM). Reuses the
    # RPi's key and VPN address, so clients only had to change endpoint.
    hub = {
      publicHost = "2.28.9.140"; # rDNS static.140.9.28.2.clients.your-server.de
      ipv6 = "2a01:4f8:c015:61f9::1";
      vpnIp = hubVpnIp; # DNS resolver address, over the tunnel (bare form of wireguard.serverIp)
      externalInterface = "eth0"; # public NIC (usePredictableInterfaceNames = false)
    };
    # RPi: LAN-only now (Tang + local adblock DNS). No longer on the VPN.
    rpi = {
      lanIp = "192.168.1.110";
    };
    wireguard = {
      port = 51820;
      interface = "wg0";
      subnet = "10.100.0.0/24";
      # CIDR forms used by per-host wireguard `address`/`ips` settings.
      # ninhoIp/serverIp are derived from the bare addresses in the `let` above.
      ninhoIp = "${ninhoVpnIp}/24";
      x1Ip = "10.100.0.2/24";
      serverIp = "${hubVpnIp}/24"; # the hub's wg0 address
      # WireGuard server (hub) public key, derived from the reused private key.
      # Referenced as a peer by every client config. Update here if it rotates.
      serverPubKey = "8/0ivDjLLlkPuQYvX5mKIdf+IVeqnGHXkpxNY7EWtUM=";
    };

    # Self-hosted Headscale control plane (Tailscale coordinator) on the hub.
    # The DDNS name forward-resolves to hub.publicHost (2.28.9.140); clients dial
    # it as their --login-server, and headscale obtains its Let's Encrypt cert for
    # it. The adblock resolvers allowlist this name (see unbound-adblock.nix).
    headscale = {
      hostname = "hetzner-nixos.ddns.net";
      url = "https://hetzner-nixos.ddns.net";
    };
  };

  # ---------------------------------------------------------------------------
  # Storage paths: INFRASTRUCTURE-SPECIFIC
  # ---------------------------------------------------------------------------
  # Mount points on the ninho server. `/storage` is a ZFS RAIDZ1 pool
  # (3× HDD); subdirectories are conventional but not enforced. Forks on
  # different layouts should rewrite these to wherever bulk data lives.
  storage = {
    root = "/storage";
    data = "/storage/data";
    media = "/storage/media";
    backup = "/storage/backup";
    torrents = "/storage/torrents";
  };

  # ---------------------------------------------------------------------------
  # Filesystem paths: CONVENTIONAL
  # ---------------------------------------------------------------------------
  # Where root-readable secrets live. `/etc/wireguard/private` is the
  # conventional wg-quick location; you must `install -m600 -o root -g root
  # <key> /etc/wireguard/private` once before deploying any host that uses
  # WireGuard. Not generated automatically (intentional: it's a secret).
  paths = {
    wireguardPrivateKey = "/etc/wireguard/private";
  };

  # ---------------------------------------------------------------------------
  # Service ports: CONVENTIONAL
  # ---------------------------------------------------------------------------
  # Loose port-range conventions:
  #   2283        Immich (upstream default)
  #   3000        Grafana (upstream default)
  #   3333        Bitmagnet
  #   8080–8089   AI / inference / nix cache
  #   8090–8099   nix cache, *arr, dashboards
  #   8100–8199   media + tools (deluge, miniflux, etc.)
  #   8200–8299   media frontends
  #   8384        Syncthing (upstream default)
  #   8888        Atuin (upstream default)
  #   9090        Prometheus (upstream default)
  #  11987        CoolerControl
  #  27701        Anki sync server
  ports = {
    nextcloud = 8081;
    immich = 2283;
    grafana = 3000;
    llamaswap = 8080;
    homepage = 8082;
    jellyfin = 8096;
    prowlarr = 8097;
    radarr = 8098;
    sonarr = 8099;
    lidarr = 8100;
    readarr = 8101;
    deluge = 8103;
    syncthing = 8384;
    coolercontrol = 11987;
    emanote = 7000;
    bitmagnet = 3333;
    miniflux = 8104;
    anki-sync-server = 27701;

    # New services
    ntfy = 8106;
    filebrowser = 8107;
    home-assistant = 8123;

    # Additional services
    redlib = 8108;
    frigate = 8114; # NVR (Docker stable-tensorrt): camera detection + clips + API
    pet-report = 8115; # Pet-activity journal over Frigate: web UI via nginx
    pet-report-backend = 8116; # ...and its API, loopback only, behind that nginx
    bazarr = 8112;
    open-webui = 8113;
    comfy-ui = 8188;

    # Monitoring
    prometheus = 9090;

    # Sync
    atuin = 8888;

    # Nix cache
    attic = 8090;

    # Tang (RPi): Clevis/LUKS auto-unlock key advertisement
    tang = 7654;
  };
}
