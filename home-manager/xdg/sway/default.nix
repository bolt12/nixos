{ pkgs, lib, ... }:
{
  xdg.configFile."sway/config".source = lib.mkForce (./config);
  xdg.configFile."sway/laptop-lid.sh".source = lib.mkForce (./laptop-lid.sh);
}
