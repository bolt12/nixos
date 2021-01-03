{ config, pkgs, ... }:
{
  services.redshift = {
    enable = true;
    package = pkgs.redshift-wlr;
    provider = "geoclue2";
  };
}
