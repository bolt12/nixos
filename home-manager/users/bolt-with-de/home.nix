{
  config,
  lib,
  pkgs,
  inputs,
  system,
  ...
}:

# Bolt's desktop configuration for bolt-nixos
# This imports the base bolt configuration and adds desktop environment components
# Zero redundancy: all headless config comes from ../bolt/home.nix

{
  imports = [
    # Import base bolt configuration (headless)
    ../bolt/home.nix

    # Stylix theming
    inputs.stylix.homeModules.stylix

    # Add desktop-specific profiles
    ../../profiles/desktop.nix
    ../../profiles/wayland.nix

    # Add desktop-specific modules
    ../../modules/wayland.nix

    # Add desktop program configurations
    ../../programs/sway/default.nix
    ../../programs/waybar/default.nix
    ../../programs/fuzzel/default.nix

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
    poweralertd.enable = true;
    safeeyes.enable = true;

    # Idle management — lock after 5min, DPMS off after 10min
    swayidle = {
      enable = true;
      timeouts = [
        {
          timeout = 300;
          command = "swaylock -f --clock --indicator --effect-blur 7x5 --effect-vignette 0.5:0.5";
        }
        {
          timeout = 600;
          command = ''swaymsg "output * dpms off"'';
          resumeCommand = ''swaymsg "output * dpms on"'';
        }
      ];
      events = [
        {
          event = "before-sleep";
          command = "swaylock -f --clock --indicator --effect-blur 7x5 --effect-vignette 0.5:0.5";
        }
      ];
    };

    wlsunset = {
      enable = true;
      latitude = "39";
      longitude = "-8";
    };

    # Automatic display profile switching
    kanshi = {
      enable = true;
      settings = [
        {
          # Both external monitors — disable laptop, use 2560x1080 ultrawide
          # to free extender bandwidth for LG at 60Hz
          profile.name = "docked-dual";
          profile.outputs = [
            {
              criteria = "eDP-1";
              status = "disable";
            }
            {
              criteria = "OOO BW-GM3 0000000000001";
              mode = "2560x1080@60Hz";
              position = "0,0";
            }
            {
              criteria = "LG Electronics LG HDR 4K 0x000694F9";
              mode = "1920x1080@60Hz";
              transform = "90";
              position = "2560,0";
            }
          ];
        }
        {
          # Ultrawide only
          profile.name = "docked-ultrawide";
          profile.outputs = [
            {
              criteria = "eDP-1";
              status = "disable";
            }
            {
              criteria = "OOO BW-GM3 0000000000001";
              mode = "3440x1440@60Hz";
              position = "0,0";
            }
          ];
        }
        {
          # LG 4K only — full 4K possible when ultrawide is off
          profile.name = "docked-lg";
          profile.outputs = [
            {
              criteria = "eDP-1";
              status = "disable";
            }
            {
              criteria = "LG Electronics LG HDR 4K 0x000694F9";
              mode = "3840x2160@30Hz";
              scale = 2.0;
              transform = "90";
            }
          ];
        }
        {
          # Laptop only
          profile.name = "undocked";
          profile.outputs = [
            {
              criteria = "eDP-1";
              status = "enable";
            }
          ];
        }
      ];
    };
  };

  # Stylix theming — Catppuccin Mocha (unified with sway/waybar)
  stylix = {
    enable = true;
    autoEnable = false;

    image = ../../background.png;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
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
      bat.enable = true;
      fzf.enable = true;
    };
  };
}
