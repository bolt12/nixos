{ config, lib, pkgs, ... }:

{

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

    dbus = {
      enable = true;
      packages = [ pkgs.gnome3.dconf ];
    };

    xserver = {
      enable = true;
      displayManager.defaultSession = "sway";
      xkbOptions = "caps:escape";
      libinput.enable = true;
      layout = "pt-latin1";
      xrandrHeads = [
        { output = "HDMI-1";
          primary = true;
          monitorConfig = ''
            Option "PreferredMode" "1280x800"
            Option "Position" "0 0"
          '';
        }
        { output = "eDP-1";
          monitorConfig = ''
            Option "PreferredMode" "1280x800"
            Option "Position" "0 0"
          '';
        }
      ];
      resolutions = [
        { x = 1280; y = 800; }
        { x = 2048; y = 1152; }
        { x = 1920; y = 1080; }
        { x = 2560; y = 1440; }
        { x = 3072; y = 1728; }
        { x = 3840; y = 2160; }
      ];
    };
  };
}
