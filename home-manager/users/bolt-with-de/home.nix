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
    # Niri ↔ Stylix bridge (themes border colors from base16 scheme).
    # Lives in niri-flake (not stylix); only wires into HM when imported here.
    inputs.niri.homeModules.stylix

    inputs.dms.homeModules.dank-material-shell
    inputs.dms.homeModules.niri

    # Add desktop-specific profiles
    ../../profiles/desktop.nix
    ../../profiles/fonts.nix
    ../../profiles/wayland.nix

    # Add desktop-specific modules
    ../../modules/wayland.nix

    # Add desktop program configurations
    ../../programs/sway/default.nix
    ../../programs/waybar/default.nix
    ../../programs/fuzzel/default.nix
    ../../programs/niri/default.nix
    # Noctalia (Quickshell-based) is currently broken on this iGPU + Mesa —
    # its render thread crashes inside libLLVM. Re-enable once upstream
    # stabilizes, or once we move off Mesa 25.2.x + LLVM 21.x.
    # ../../programs/noctalia/default.nix

    # Desktop-specific user data (Syncthing configuration)
    ./user-data.nix
  ];

  # Ninho-only modules excluded on the laptop:
  #   - development-lean.nix: Lean4 toolchain (heavy, only used on ninho)
  #   - emanote-user.nix: journal server (bolt's data lives on ninho)
  disabledModules = [
    ../../profiles/development-lean.nix
    ../../services/emanote-user.nix
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

    # `niri.enableKeybinds` and `niri.includes.enable` are off: explicit binds
    # in programs/niri/keybindings.nix remain authoritative. Re-enable
    # includes to inherit DMS's bar-toggle / dashboard / spotlight chords.
    dank-material-shell = {
      enable = false;
      systemd.enable = true;
      niri = {
        enableKeybinds = false;
        enableSpawn = true;
        includes.enable = false;
      };
    };
  };

  # Stretchly — Wayland-native break reminder (replaces safeeyes, which has
  # broken fullscreen/DND detection under Niri). Autostarted via niri's
  # spawn-at-startup; minimizes to tray on launch.
  home.packages = [ pkgs.stretchly ];

  # Desktop-specific services
  services = {
    lorri.enable = true;
    blueman-applet.enable = true;
    udiskie.enable = true;
    poweralertd.enable = true;

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

    # kanshi was previously responsible for switching between docked-dual /
    # docked-blitzwolf / docked-lg / undocked profiles based on detected
    # outputs. Niri's static output declarations in programs/niri/default.nix
    # already cover the geometry/scale/refresh per monitor, and niri silently
    # ignores declared-but-disconnected outputs (re-applies on hotplug), so
    # kanshi is redundant.
    #
    # Trade-offs accepted vs the kanshi setup:
    #   - eDP-1 stays enabled while docked (kanshi disabled it). Toggle with
    #     `Mod+ctrl+Shift+e` (see programs/niri/keybindings.nix) when wanted.
    #   - The 4K-when-LG-solo profile (3840x2160@30, scale 2.0) is gone; the
    #     LG runs at 1920x1080@30 always now. Use `Mod+ctrl+Shift+m` to
    #     bump it to 4K mode at runtime if needed.
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
      niri.enable = true; # provided by inputs.niri.homeModules.stylix
    };
  };
}
