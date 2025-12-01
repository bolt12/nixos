{ config, pkgs, inputs, ... }:
let
  # Import unstable packages for latest ollama
  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs) system;
    overlays = [];
    config.allowUnfree = true;
  };
in
{

  # Disable the stable service
  disabledModules = [ "${inputs.nixpkgs}/nixos/modules/services/misc/servarr/prowlarr.nix" ];
  # Get the unstable service version
  imports = [
    "${inputs.nixpkgs-unstable}/nixos/modules/services/misc/servarr/prowlarr.nix"
  ];

  systemd.tmpfiles.rules = [
    "f /var/lib/secrets/deluge-auth 0600 deluge deluge - deluge:deluge:10"
  ];

  services = {
    prowlarr = {
      enable = true;
      package = unstable.prowlarr;
      openFirewall = true;
      settings = {
        server.port = 8097;
      };
    };

    radarr = {
      enable = true;
      package = unstable.radarr;
      openFirewall = true;
      settings = {
        server.port = 8098;
      };
    };

    sonarr = {
      enable = true;
      openFirewall = true;
      settings = {
        server.port = 8099;
      };
    };

    lidarr = {
      enable = true;
      package = unstable.lidarr;
      openFirewall = true;
      settings = {
        server.port = 8100;
      };
    };

    readarr = {
      enable = true;
      openFirewall = true;
      settings = {
        server.port = 8101;
      };
    };

    bitmagnet = {
      enable = true;
      useLocalPostgresDB = true;
      openFirewall = true;
      settings = {
        # The default value F***ed my router
        dht_crawler.scaling_factor = 2;
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
        download_location = "/storage/torrents";
        move_completed = true;
        move_completed_path = "/storage/torrents";
      };
      web = {
        enable = true;
        openFirewall = true;
        port = 8103;
      };
    };
  };
}
