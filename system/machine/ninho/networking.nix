# Networking: hostname, hostId (ZFS), NetworkManager, DNS,
# firewall (TCP/UDP allowed ports + service-port aggregation),
# Tailscale, and game-streaming sysctl tuning.
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
    #
    # Careful with the port lists below: they are address-family blind. The
    # generated firewall script pushes nearly every rule through its `ip46tables`
    # helper, so one entry here opens the port on IPv4 and IPv6 alike, on every
    # interface, with no source restriction. Since the 2026-08 ISP change each
    # LAN host also gets a routable global IPv6 address over DHCPv6, and there is
    # no NAT in front of those.
    #
    # What keeps these services off the internet today is the ISP router's
    # inbound IPv6 firewall, not anything in this file. Verified 2026-08-20 by
    # dialling ninho's global address from the Hetzner hub: connection timed out.
    # If that ever changes, or a future router ships with it off, everything
    # below is immediately world-reachable. Reaching these services is meant to
    # happen over Tailscale (cf. homepage.nix and nextcloud.nix, which key their
    # URLs to the tailnet address), so the fix would be to refuse inbound IPv6
    # from global unicast sources rather than to prune this list.
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
