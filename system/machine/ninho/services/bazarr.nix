# Subtitle auto-downloader for Sonarr / Radarr.
{
  config,
  pkgs,
  lib,
  constants,
  ...
}:
let
  inherit (constants) ports;
in
{
  services.bazarr = {
    enable = true;
    package = pkgs.unstable.bazarr;
    listenPort = ports.bazarr;
    openFirewall = true;
  };

  # Group membership (media, storage-users) is assigned centrally in
  # services/permissions.nix, like the rest of the *arr stack.
}
