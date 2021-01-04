{ config, lib, pkgs, ... }:

{
  environment.sessionVariables = {
      MOZ_ENABLE_WAYLAND = "1";
      XDG_CURRENT_DESKTOP = "sway"; # TODO: Do we need this in non-sway setups?
      XDG_SESSION_TYPE = "wayland";
  };

  programs.sway = {
      enable = true;
      wrapperFeatures.gtk = true;
      extraPackages = with pkgs; [
        swayidle
        xwayland
        dmenu
        brightnessctl
        libnotify
        i3status
        wl-clipboard
        mako
        compton
      ];
    };

  services = {
    gnome3.gnome-keyring.enable = true;
    upower.enable = true;

    xserver = {

      enable = true;

      displayManager.defaultSession = "sway";

      xkbOptions = "caps:escape";

      libinput.enable = true;

      layout = "pt";

    };
  };
}
