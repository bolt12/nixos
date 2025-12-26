{ config, pkgs, ... }:
{
  services = {
    jellyfin = {
      enable = true;
      openFirewall = true;
    };

    jellyseerr = {
      enable = true;
      openFirewall = true;
      port = 8200;
      package = pkgs.unstable.jellyseerr;
    };
  };
}
