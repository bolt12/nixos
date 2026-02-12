{ config, lib, pkgs, inputs, system, ... }:

# Bolt's desktop configuration for bolt-nixos
# This imports the base bolt configuration and adds desktop environment components
# Zero redundancy: all headless config comes from ../bolt/home.nix

{
  imports = [
    # Import base bolt configuration (headless)
    ../bolt/home.nix

    # Stylix theming (Gruvbox Dark)
    inputs.stylix.homeModules.stylix

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
          qt6Packages.fcitx5-configtool
          fcitx5-mozc
          fcitx5-nord
          fcitx5-rime
        ];
      };
    };
  };

  # Desktop-specific programs
  programs = {
    firefox.enable = true;
  };

  # Desktop-specific services
  services = {
    lorri.enable = true;
    blueman-applet.enable = true;
    udiskie.enable = true;
    swayidle.enable = true;
    poweralertd.enable = true;
    safeeyes.enable = true;

    wlsunset = {
      enable = true;
      latitude = "39";
      longitude = "-8";
    };
  };

  # Stylix theming - purely additive, no existing configs modified
  # Sway/waybar use raw config files; Stylix only manages GTK/cursor/fonts
  # To remove: delete this block and the stylix import above
  stylix = {
    enable = true;
    autoEnable = false;  # Don't auto-enable all targets

    image = ../../background.png;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-hard.yaml";
    polarity = "dark";

    fonts = {
      monospace = {
        package = pkgs.jetbrains-mono;
        name = "JetBrains Mono";
      };
      sansSerif = {
        package = pkgs.noto-fonts;
        name = "Noto Sans";
      };
      serif = {
        package = pkgs.noto-fonts;
        name = "Noto Serif";
      };
    };

    cursor = {
      package = pkgs.numix-cursor-theme;
      name = "Numix-Cursor";
      size = 24;
    };

    targets = {
      gtk.enable = true;
    };
  };
}
