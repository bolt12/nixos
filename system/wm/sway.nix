{ config, lib, pkgs, ... }:

{
  environment.sessionVariables = {
      MOZ_ENABLE_WAYLAND = "1";
      XDG_CURRENT_DESKTOP = "sway"; # TODO: Do we need this in non-sway setups?
      XDG_SESSION_TYPE = "wayland";
      SDL_VIDEODRIVER = "wayland";
      QT_QPA_PLATFORM = "wayland";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
      ECORE_EVAS_ENGINE = "wayland_egl";
      ELM_ENGINE = "wayland_egl";
  };

  programs.sway = {
      enable = true;
      wrapperFeatures.gtk = true;
      extraPackages = with pkgs; [
        xwayland
        dmenu
        brightnessctl
        libnotify
        i3status
        compton
      ];
    };

  services = {
    gnome3.gnome-keyring.enable = true;
    upower.enable = true;

    xserver = {
      enable = true;
      displayManager.defaultSession = "sway";
      layout = "us,pt";
      xkbOptions = "caps:escape, grp:shifts_toggle";
      libinput.enable = true;
      libinput.clickMethod = "clickfinger";
      videoDrivers = [ "intel" ];
    };
  };
}
