{ config, pkgs, constants, ... }:
let
  inherit (constants) ports storage;
  immichHome = "${storage.data}/immich";
in
{
  services.immich = {
    enable = true;
    host = "0.0.0.0";
    port = ports.immich;
    mediaLocation = immichHome;

    openFirewall = true; # Automatically opens port in firewall

    database = {
      enable = true;
      createDB = true;  # Auto-creates database
      enableVectors = false;  # x86_64 supports this
    };

    machine-learning.enable = true;

    redis.enable = true;  # Auto-configures Redis

    accelerationDevices = null;
  };

  systemd.tmpfiles.rules = [
    "d ${immichHome}/ 0750 immich immich"
  ];
}
