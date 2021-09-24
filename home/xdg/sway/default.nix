{ pkgs, lib, ...}:
{
  xdg.configFile."sway/config".source = lib.mkForce (./config);
}
