{
  config,
  pkgs,
  lib,
  ...
}:

let
  inherit (config.userConfig.niri)
    primaryMonitor
    externalMonitor
    portraitMonitor
    wallpaperPath
    ;
in
{
  imports = [
    ./keybindings.nix
    ./window-rules.nix
    ./gestures.nix
    ./animations.nix
    ./auto-rename-workspace.nix
  ];

  programs.niri = {
    package = pkgs.niri-stable;

    settings = {
      input = {
        keyboard.xkb = {
          layout = "us";
          options = "caps:escape";
        };
        touchpad = {
          tap = true;
          natural-scroll = true;
          dwt = true;
          accel-profile = "adaptive";
          click-method = "clickfinger";
        };
        focus-follows-mouse.enable = true;
        warp-mouse-to-focus.enable = true;
        workspace-auto-back-and-forth = true;
        mod-key = "Alt";
      };

      outputs = {
        ${primaryMonitor} = {
          enable = true;
          mode = {
            width = 1920;
            height = 1080;
          };
          scale = 1.0;
        };
      }
      // lib.optionalAttrs (externalMonitor != null) {
        ${externalMonitor} = {
          enable = true;
          mode = {
            width = 3440;
            height = 1440;
            refresh = 60.0;
          };
          scale = 1.3;
          position = {
            x = 0;
            y = 0;
          };
          variable-refresh-rate = "on-demand";
        };
      }
      // lib.optionalAttrs (portraitMonitor != null) {
        # USB-C dock bandwidth caps the LG at 1080p@30 when both externals are active.
        ${portraitMonitor} = {
          enable = true;
          mode = {
            width = 1920;
            height = 1080;
            refresh = 30.0;
          };
          scale = 1.0;
          transform.rotation = 90;
          position = {
            x = 2646;
            y = 0;
          };
        };
      };

      layout = {
        gaps = 8;
        border = {
          enable = true;
          width = 2;
          # Signature niri gradient: Catppuccin Mocha mauve → blue, 45°.
          # Stylix's niri target sets a flat colour by default; we override
          # to get the gradient look while keeping inactive subtle.
          active.gradient = {
            from = "#cba6f7";
            to = "#89b4fa";
            angle = 45;
          };
          inactive.color = "#313244";
        };
        focus-ring.enable = false;
        preset-column-widths = [
          { proportion = 1.0 / 3.0; }
          { proportion = 1.0 / 2.0; }
          { proportion = 2.0 / 3.0; }
        ];
        preset-window-heights = [
          { proportion = 1.0 / 3.0; }
          { proportion = 1.0 / 2.0; }
          { proportion = 2.0 / 3.0; }
        ];
        default-column-width.proportion = 0.5;
        center-focused-column = "on-overflow";
        tab-indicator = {
          enable = true;
          place-within-column = true;
          hide-when-single-tab = true;
        };
      };

      workspaces = {
        "1" = { };
        "2" = { };
        "3" = { };
        "4" = { };
        "5" = { };
        "6" = { };
        "7" = { };
        "8" = { };
        "9" = { };
        "10" = { };
        "scratchpad" = { };
      };

      spawn-at-startup = [
        { argv = [ "waybar" ]; }
        {
          argv = [
            "swaybg"
            "-i"
            "${toString wallpaperPath}"
            "-m"
            "fill"
          ];
        }
        {
          argv = [
            "nm-applet"
            "--indicator"
          ];
        }
        {
          argv = [
            "wl-paste"
            "--type"
            "text"
            "--watch"
            "cliphist"
            "store"
          ];
        }
        {
          argv = [
            "wl-paste"
            "--type"
            "image"
            "--watch"
            "cliphist"
            "store"
          ];
        }
      ];

      hotkey-overlay.skip-at-startup = true;

      screenshot-path = "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png";

      overview.zoom = 0.25;

      prefer-no-csd = true;

      environment = {
        NIXOS_OZONE_WL = "1";
        MOZ_ENABLE_WAYLAND = "1";
        QT_QPA_PLATFORM = "wayland";
      };
    };
  };
}
