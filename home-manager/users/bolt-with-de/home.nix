{ config, lib, pkgs, inputs, system, ... }:

# Bolt's desktop configuration for bolt-nixos
# This imports the base bolt configuration and adds desktop environment components
# Zero redundancy: all headless config comes from ../bolt/home.nix

{
  imports = [
    # Import base bolt configuration (headless)
    ../bolt/home.nix

    # Add desktop-specific profiles
    ../../profiles/desktop.nix
    ../../profiles/wayland.nix

    # Add desktop-specific modules
    ../../modules/wayland.nix

    # Add desktop program configurations
    ../../programs/sway/default.nix
    ../../programs/waybar/default.nix
    ../../programs/wofi/default.nix

    # Add XDG desktop configurations
    ../../xdg/sway/default.nix

    # Desktop-specific user data (Syncthing configuration)
    ./user-data.nix
  ];

  # Desktop-specific input method configuration
  i18n = {
    inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5 = {
        addons = with pkgs; [
          fcitx5-gtk
          fcitx5-configtool
          fcitx5-mozc
          fcitx5-nord
          fcitx5-rime
        ];
      };
    };
  };

  # Desktop-specific programs
  programs = {
    autorandr.enable = true;
    firefox.enable = true;
  };

  # Desktop-specific services
  services = {
    lorri.enable = true;
    blueman-applet.enable = true;
    udiskie.enable = true;
    swayidle.enable = true;
    poweralertd.enable = true;
    autorandr.enable = true;
    safeeyes.enable = true;

    wlsunset = {
      enable = true;
      latitude = "39";
      longitude = "-8";
    };
  };
}
