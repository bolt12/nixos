{ lib, ... }:
{
  # Network configuration
  network = {
    ninho = {
      vpnIp = "10.100.0.100";
      hostname = "ninho.local";
      wireguard = {
        port = 51820;
        interface = "wg0";
      };
    };
    rpi = {
      vpnIp = "10.100.0.1";
      hostname = "rpi-nixos.ddns.net";
    };
  };

  # Storage paths
  storage = {
    root = "/storage";
    data = "/storage/data";
    media = "/storage/media";
    backup = "/storage/backup";
    torrents = "/storage/torrents";
  };

  # Service ports (centralized port allocation)
  ports = {
    nextcloud = 8081;
    onlyoffice = 8000;
    immich = 2283;
    grafana = 3000;
    ollama = 8080;
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
  };
}
