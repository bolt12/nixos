{ config, pkgs, ... }:
{
  services.redshift = {
    enable = true;
    package = pkgs.redshift-wlr;
  };
}
