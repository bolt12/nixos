{ config, lib, pkgs, ... }:

{
  environment.sessionVariables = {
      MOZ_DISABLE_RDD_SANDBOX="1";
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
      wrapperFeatures.base = true;
      wrapperFeatures.gtk = true;
      extraPackages = with pkgs; [
        xwayland
        dmenu
        brightnessctl
        libnotify
        i3status
        compton
      ];
      extraSessionCommands =
      ''
        export SDL_VIDEODRIVER=wayland
        export QT_QPA_PLATFORM=wayland
        export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"
        export _JAVA_AWT_WM_NONREPARENTING=1
        export SUDO_ASKPASS="${pkgs.ksshaskpass}/bin/ksshaskpass"
        export SSH_ASKPASS="${pkgs.ksshaskpass}/bin/ksshaskpass"
        export XDG_SESSION_TYPE=wayland
        export XDG_CURRENT_DESKTOP=sway
      '';
    };

  services = {
    gnome.gnome-keyring.enable = true;
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
