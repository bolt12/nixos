{ lib, ... }:
{
  # Network configuration
  network = {
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
      # RPi WireGuard server public key (derived from its generated private key).
      # Referenced as a peer by every client config. Update here if the RPi key rotates.
      rpiServerPubKey = "2OIP77a10/Fas+eCvYQNa3ixFNOq0JqZIuSk1tY/QTM=";
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

  # Wyoming voice service ports (STT = faster-whisper, TTS = piper)
  # Convention: 10200s = piper TTS, 10300s = whisper STT
  wyoming = {
    piperEn = 10200;
    piperPt = 10201;
    whisperEn = 10300;
    whisperPt = 10301;
  };
}
