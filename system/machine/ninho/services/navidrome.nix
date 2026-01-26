{ config, pkgs, lib, constants, ... }:
let
  inherit (constants) ports storage;
  navidromeHome = "${storage.data}/navidrome";
in
{
  services.navidrome = {
    enable = true;
    package = pkgs.unstable.navidrome;
    settings = {
      # Network - must set both when using settings
      Address = "0.0.0.0";
      Port = ports.navidrome;

      # Storage paths
      MusicFolder = "${storage.media}/music";
      DataFolder = "${navidromeHome}/data";
      CacheFolder = "${navidromeHome}/cache";

      # Performance tuning (128GB RAM available)
      ScanSchedule = "@every 1h";
      TranscodingCacheSize = "500MB";

      # Features
      EnableSharing = true;
      EnableStarRating = true;
      EnableDownloads = true;

      # Privacy
      EnableInsightsCollector = false;
    };
    openFirewall = true;
  };

  # Create data directories
  systemd.tmpfiles.rules = [
    "d ${navidromeHome} 0750 navidrome navidrome - -"
    "d ${navidromeHome}/data 0750 navidrome navidrome - -"
    "d ${navidromeHome}/cache 0750 navidrome navidrome - -"
  ];

  # Grant navidrome read access to music folder
  users.users.navidrome.extraGroups = [ "media" "storage-users" ];
}
