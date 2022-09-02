{ config, lib, pkgs, ... }:

{
  programs.sway.enable = true;
  programs.sway.wrapperFeatures.base = true;
  programs.sway.wrapperFeatures.gtk = true;
  programs.sway.extraPackages = [ ];
  programs.xwayland.enable = true;

  services = {
    upower.enable = true;

    xserver = {
      enable = true;
      displayManager.defaultSession = "sway";
      layout = "us,pt";
      xkbOptions = "caps:escape, grp:shifts_toggle";
      libinput.enable = true;
      libinput.touchpad.clickMethod = "clickfinger";
      videoDrivers = [ "intel" ];
    };
  };
}
