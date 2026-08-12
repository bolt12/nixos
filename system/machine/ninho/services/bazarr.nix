# Subtitle auto-downloader for Sonarr / Radarr.
{
  config,
  pkgs,
  lib,
  constants,
  ...
}:
let
  inherit (constants) ports storage;
  bazarrHome = "${storage.data}/bazarr";
in
{
  services.bazarr = {
    enable = true;
    package = pkgs.unstable.bazarr;
    listenPort = ports.bazarr;
    openFirewall = true;
  };

  # Create data directory
  systemd.tmpfiles.rules = [
    "d ${bazarrHome} 0750 bazarr bazarr - -"
  ];

  # Group membership (media, storage-users) is assigned centrally in
  # services/permissions.nix, like the rest of the *arr stack.
}
