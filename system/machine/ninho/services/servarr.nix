{ config, pkgs, inputs, constants, ... }:
let
  inherit (constants) ports storage;
in
{

  # Disable the stable service
  disabledModules = [ "${inputs.nixpkgs}/nixos/modules/services/misc/servarr/prowlarr.nix" ];
  # Get the unstable service version
  imports = [
    "${inputs.nixpkgs-unstable}/nixos/modules/services/misc/servarr/prowlarr.nix"
  ];

  systemd.tmpfiles.rules = [
    # Deluge auth file
    "f /var/lib/secrets/deluge-auth 0600 deluge deluge - deluge:deluge:10"

    # Create organized media directories with proper ownership
    # These are where *Arr services will organize and hardlink media
    "d ${storage.media}/movies 0775 radarr storage-users - -"
    "d ${storage.media}/tv 0775 sonarr storage-users - -"
    "d ${storage.media}/music 0775 lidarr storage-users - -"
    "d ${storage.media}/books 0775 readarr storage-users - -"

    # Ensure torrents directory exists with proper permissions
    "d ${storage.torrents} 0775 deluge storage-users - -"
  ];

  services = {
    prowlarr = {
      enable = true;
      package = pkgs.unstable.prowlarr;
      openFirewall = true;
      settings = {
        server.port = ports.prowlarr;
      };
    };

    radarr = {
      enable = true;
      package = pkgs.unstable.radarr;
      openFirewall = true;
      settings = {
        server.port = ports.radarr;
      };
    };

    sonarr = {
      enable = true;
      openFirewall = true;
      settings = {
        server.port = ports.sonarr;
      };
    };

    lidarr = {
      enable = true;
      package = pkgs.unstable.lidarr;
      openFirewall = true;
      settings = {
        server.port = ports.lidarr;
      };
    };

    readarr = {
      enable = true;
      package = pkgs.unstable.readarr;
      openFirewall = true;
      settings = {
        server.port = ports.readarr;
      };
    };

    bitmagnet = {
      enable = true;
      useLocalPostgresDB = true;
      openFirewall = true;
      settings = {
        # The default value F***ed my router
        dht_crawler.scaling_factor = 1;
      };
    };

    deluge = {
      enable = true;
      openFirewall = true;
      declarative = true;
      authFile = "/var/lib/secrets/deluge-auth";
      config = {
        allow_remote = true;
        listen_interface = "0.0.0.0";
        download_location = storage.torrents;
        move_completed = true;
        move_completed_path = storage.torrents;
      };
      web = {
        enable = true;
        openFirewall = true;
        port = ports.deluge;
      };
    };
  };
}
