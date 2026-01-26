{ config, pkgs, lib, constants, ... }:
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

  # Bazarr needs access to media files for subtitle matching
  users.users.bazarr.extraGroups = [ "media" "storage-users" ];
}
