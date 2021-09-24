{ config, lib, pkgs, ... }:

{


  programs.sway.enable = true;
  programs.sway.extraPackages = [];

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
