{ config, pkgs, ... }:
{
  services.immich = {
    enable = true;
    host = "0.0.0.0";
    port = 2283;
    mediaLocation = "/storage/data/immich";

    openFirewall = true; # Automatically opens port 2283 in firewall

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
    "d /storage/data/immich/ 0750 immich immich"
  ];
}
