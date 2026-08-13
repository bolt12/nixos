# Networking: hostname, hostId (ZFS), NetworkManager, DNS,
# firewall (TCP/UDP allowed ports + service-port aggregation),
# WireGuard, and game-streaming sysctl tuning.
{ constants, ... }:
{
  networking = {
    hostName = "nixos-ninho";
    # Required for ZFS (generated with: head -c4 /dev/urandom | od -A none -t x4)
    hostId = "d8e24c1d";

    networkmanager = {
      enable = true;
      dns = "none";
    };

    # DNS servers. Hub adblock resolver (10.100.0.1) first: it is the stable DNS
    # anchor across the wg->tailscale transport swap (the hub keeps 10.100.0.1
    # after the later tailscale renumber), so this list never has to change. RPi
    # LAN resolver is the always-reachable fallback if the tunnel is down.
    nameservers = [
      constants.network.hub.vpnIp # hub adblock resolver over the tunnel (primary)
      constants.network.rpi.lanIp # RPi LAN recursive DNS (fallback)
      "1.1.1.1"
      "8.8.8.8"
      "8.8.4.4"
    ];

    # Firewall
    firewall = {
      enable = true;
      trustedInterfaces = [
        "wg0"
        "tailscale0"
      ];
      allowedTCPPorts = [
        22 # SSH
        80 # HTTP
        8920 # Jellyfin HTTPS
        22000 # Syncthing file transfers
      ]
      ++ (with constants.ports; [
        immich
        grafana
        emanote
        llamaswap
        nextcloud
        homepage
        jellyfin
        prowlarr
        radarr
        sonarr
        lidarr
        readarr
        bitmagnet
        deluge
        syncthing
        coolercontrol
      ]);
      allowedUDPPorts = [
        constants.network.wireguard.port
        22000 # Syncthing discovery
        21027 # Syncthing discovery
        1900 # Jellyfin SSDP
        7359 # Jellyfin discovery
      ];
    };

    # WireGuard VPN
    wireguard.interfaces.wg0 = {
      ips = [ constants.network.wireguard.ninhoIp ];
      listenPort = constants.network.wireguard.port;
      privateKeyFile = constants.paths.wireguardPrivateKey;

      peers = [
        {
          publicKey = constants.network.wireguard.serverPubKey;
          # Split tunnel: only WG subnet routes through wg0. Default route stays on
          # enp11s0 so ninho's internet traffic (Steam/SDR and other UDP-heavy
          # workloads) does not detour through the remote hub.
          allowedIPs = [ constants.network.wireguard.subnet ];
          endpoint = "${constants.network.hub.publicHost}:${toString constants.network.wireguard.port}";
          persistentKeepalive = 25;
        }
      ];
    };
  };

  # Tailscale client. Registers against the self-hosted Headscale on the hub and
  # negotiates a DIRECT peer path (over ninho's public IPv6 when available) so
  # game streaming to the laptop no longer hairpins through the wg0 hub in
  # Germany. Coexists with wg0: tailscale0 (100.64.0.0/10, udp 41641) and wg0
  # (10.100.0.0/24, udp 51820) are disjoint, so nothing collides.
  services.tailscale = {
    enable = true;
    openFirewall = true; # UDP 41641 for direct NAT traversal
    useRoutingFeatures = "none"; # pure host; not advertising routes or exit node
    authKeyFile = "/etc/tailscale/authkey"; # hand-placed, cf. /etc/wireguard/private
    extraUpFlags = [
      "--login-server=${constants.network.headscale.url}"
      "--hostname=ninho"
      "--accept-dns=false" # keep the hub adblock resolver; do not push MagicDNS
    ];
    extraSetFlags = [ "--accept-dns=false" ]; # re-applied every rebuild
  };

  # Network performance tuning for game streaming (Sunshine)
  boot.kernel.sysctl = {
    # UDP buffer optimization (Sunshine uses UDP for video streaming)
    "net.core.rmem_max" = 134217728; # 128MB read buffer
    "net.core.wmem_max" = 134217728; # 128MB write buffer
    "net.core.rmem_default" = 1048576; # 1MB default
    "net.core.wmem_default" = 1048576;

    # Reduce bufferbloat for lower latency
    "net.core.netdev_max_backlog" = 5000;

    # Smart queue on ninho's egress: fq_codel keeps a fair, low-latency queue
    # so a bandwidth spike from one flow can't build a standing backlog that
    # shows up as stutter on the Steam Remote Play / Sunshine video stream.
    # NOTE: the dominant bufferbloat hop is usually the router's Wi-Fi downlink;
    # enable SQM/cake there too: this only smooths the host's sending side.
    "net.core.default_qdisc" = "fq_codel";

    # TCP optimization for control channel
    "net.ipv4.tcp_fastopen" = 3;
    "net.ipv4.tcp_notsent_lowat" = 16384;

    # TCP buffer tuning
    "net.ipv4.tcp_rmem" = "8192 1048576 134217728";
    "net.ipv4.tcp_wmem" = "8192 1048576 134217728";

    # Emergency kernel recovery - Magic SysRq key
    # Usage: Alt+SysRq+<command> or echo <command> > /proc/sysrq-trigger
    # REISUB sequence for safe emergency reboot: R E I S U B
    "kernel.sysrq" = 1;
  };

}
