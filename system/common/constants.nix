# =============================================================================
# Centralized constants — single source of truth for ports, IPs, paths.
# =============================================================================
#
# Imported via flake `specialArgs` and reachable in every system/HM module
# as `constants` (no need to `import` it manually).
#
# Two flavours of value live here:
#
#   1. INFRASTRUCTURE-SPECIFIC. LAN topology, ZFS pool layout, VPN IPs,
#      hostnames, public keys. **You almost certainly want to change these
#      when forking** — they describe my home network, not yours.
#
#   2. CONVENTIONAL. Port allocations, Wyoming TTS/STT port grid,
#      `paths.wireguardPrivateKey`. Likely fine to keep as-is; pick
#      different ports only if you have a clash on your network.
#
# Each section below is annotated.
# =============================================================================
{ lib, ... }:
{
  # ---------------------------------------------------------------------------
  # Network — INFRASTRUCTURE-SPECIFIC
  # ---------------------------------------------------------------------------
  # `ninho` is my home server, `rpi` is a Raspberry Pi 5 acting as VPN
  # gateway / DNS / Tang server. The WireGuard subnet (`10.100.0.0/24`)
  # is private and arbitrary; pick anything that doesn't collide with your
  # LAN or other VPNs. The `rpiServerPubKey` is derived from the RPi's
  # WireGuard private key — rotate here whenever that key rotates.
  network = {
    lan = {
      subnet = "192.168.1.0/24";
      gateway = "192.168.1.254";
    };
    ninho = {
      vpnIp = "10.100.0.100";
      hostname = "ninho.local";
    };
    rpi = {
      vpnIp = "10.100.0.1";
      lanIp = "192.168.1.110";
      hostname = "rpi-nixos.ddns.net";
    };
    wireguard = {
      port = 51820;
      interface = "wg0";
      subnet = "10.100.0.0/24";
      # CIDR forms used by per-host wireguard `address`/`ips` settings.
      ninhoIp = "10.100.0.100/24";
      x1Ip = "10.100.0.2/24";
      rpiIp = "10.100.0.1/24";
      # RPi WireGuard server public key (derived from its generated private
      # key). Referenced as a peer by every client config. Update here if
      # the RPi key rotates.
      rpiServerPubKey = "8/0ivDjLLlkPuQYvX5mKIdf+IVeqnGHXkpxNY7EWtUM=";
    };
  };

  # ---------------------------------------------------------------------------
  # Storage paths — INFRASTRUCTURE-SPECIFIC
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
  # Filesystem paths — CONVENTIONAL
  # ---------------------------------------------------------------------------
  # Where root-readable secrets live. `/etc/wireguard/private` is the
  # conventional wg-quick location; you must `install -m600 -o root -g root
  # <key> /etc/wireguard/private` once before deploying any host that uses
  # WireGuard. Not generated automatically (intentional — it's a secret).
  paths = {
    wireguardPrivateKey = "/etc/wireguard/private";
  };

  # ---------------------------------------------------------------------------
  # Service ports — CONVENTIONAL
  # ---------------------------------------------------------------------------
  # Loose port-range conventions:
  #   2283        Immich (upstream default)
  #   3000        Grafana (upstream default)
  #   3333        Bitmagnet
  #   8080–8089   AI / inference / nix cache
  #   8090–8099   nix cache, *arr, dashboards
  #   8100–8199   media + tools (deluge, miniflux, navidrome, etc.)
  #   8200–8299   media frontends (jellyseerr)
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
    jellyseerr = 8200;
    syncthing = 8384;
    coolercontrol = 11987;
    emanote = 7000;
    bitmagnet = 3333;
    miniflux = 8104;
    anki-sync-server = 27701;

    # New services
    navidrome = 8105;
    ntfy = 8106;
    filebrowser = 8107;
    home-assistant = 8123;

    # Additional services
    uptime-kuma = 8109;
    kavita = 8110;
    memos = 8111;
    bazarr = 8112;
    open-webui = 8113;
    comfy-ui = 8188;

    # Monitoring
    prometheus = 9090;

    # Sync
    atuin = 8888;

    # Nix cache
    attic = 8090;
  };

  # ---------------------------------------------------------------------------
  # Wyoming voice ports — CONVENTIONAL
  # ---------------------------------------------------------------------------
  # 10200s = piper TTS, 10300s = whisper STT, language suffix (En/Pt).
  # Add more as you bring up additional locales.
  wyoming = {
    piperEn = 10200;
    piperPt = 10201;
    whisperEn = 10300;
    whisperPt = 10301;
  };
}
