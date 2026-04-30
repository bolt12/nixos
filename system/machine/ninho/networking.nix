# Networking — hostname, hostId (ZFS), NetworkManager, DNS,
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

    # DNS servers
    nameservers = [
      constants.network.rpi.vpnIp # RPi 5 acts as recursive DNS over VPN
      "1.1.1.1"
      "8.8.8.8"
      "8.8.4.4"
    ];

    # Firewall
    firewall = {
      enable = true;
      trustedInterfaces = [ "wg0" ];
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
        jellyseerr
        syncthing
        coolercontrol
      ])
      ++ builtins.attrValues constants.wyoming;
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
          publicKey = constants.network.wireguard.rpiServerPubKey;
          allowedIPs = [ "0.0.0.0/0" ]; # Full tunnel
          endpoint = "${constants.network.rpi.lanIp}:${toString constants.network.wireguard.port}";
          persistentKeepalive = 25;
        }
      ];
    };
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
