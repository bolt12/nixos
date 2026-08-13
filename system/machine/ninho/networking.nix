# Networking: hostname, hostId (ZFS), NetworkManager, DNS,
# firewall (TCP/UDP allowed ports + service-port aggregation),
# WireGuard, and game-streaming sysctl tuning.
{ constants, ... }:
{
  imports = [ ../../common/services/tailscale-client.nix ];

  networking = {
    hostName = "nixos-ninho";
    # Required for ZFS (generated with: head -c4 /dev/urandom | od -A none -t x4)
    hostId = "d8e24c1d";

    networkmanager = {
      enable = true;
      dns = "none";
    };

    # DNS servers. Hub adblock resolver (constants.network.hub.vpnIp) first, over
    # Tailscale; the RPi LAN resolver is the always-reachable fallback if the
    # tailnet is down.
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
      # tailscale0 is trusted via services.headscaleClient (tailscale-client.nix).
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
        22000 # Syncthing discovery
        21027 # Syncthing discovery
        1900 # Jellyfin SSDP
        7359 # Jellyfin discovery
      ];
    };
  };

  # Tailscale client (see common/services/tailscale-client.nix). Joins the
  # self-hosted Headscale hub for a DIRECT peer path (over ninho's public IPv6
  # when available) so game streaming to the laptop goes straight to it instead
  # of hairpinning through a relay.
  services.headscaleClient = {
    enable = true;
    hostname = "ninho";
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
