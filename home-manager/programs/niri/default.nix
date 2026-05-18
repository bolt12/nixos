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
    ./layer-rules.nix
    ./gestures.nix
    ./animations.nix
    ./auto-rename-workspace.nix
    ./lid-watch.nix
  ];

  programs.niri = {
    package = pkgs.niri-unstable;

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
        # eDP-1 starts enabled (no black-screen-at-login race when undocked).
        # niri-lid-watch (./lid-watch.nix) flips it on/off in response to
        # lid events, and forces it off at startup if the lid is closed.
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
        # BlitzWolf ultrawide sits to the right of eDP-1 (logical width 1920).
        # Logical width at scale 1.2 = 3440 / 1.2 ≈ 2867, so the next monitor
        # starts at 1920 + 2867 = 4787.
        ${externalMonitor} = {
          enable = true;
          mode = {
            width = 3440;
            height = 1440;
            refresh = 60.0;
          };
          scale = 1.2;
          position = {
            x = 1920;
            y = 0;
          };
          variable-refresh-rate = "on-demand";
        };
      }
      // lib.optionalAttrs (portraitMonitor != null) {
        # USB-C dock bandwidth caps the LG at 1080p@30 when both externals are active.
        # LG portrait sits to the right of the BlitzWolf.
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
            x = 4787;
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
        default-column-width.proportion = 1.0;
        center-focused-column = "on-overflow";
        tab-indicator = {
          enable = true;
          place-within-column = true;
          hide-when-single-tab = true;
        };
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
        # XWayland bridge for X11-only apps (Steam launcher, older IDEs,
        # wine, xdotool/xev, etc). niri itself is pure Wayland.
        { argv = [ "${pkgs.xwayland-satellite-unstable}/bin/xwayland-satellite" ]; }
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
        { argv = [ "stretchly" ]; }
      ];

      hotkey-overlay.skip-at-startup = true;

      screenshot-path = "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png";

      overview.zoom = 0.25;

      prefer-no-csd = true;

      environment = {
        NIXOS_OZONE_WL = "1";
        MOZ_ENABLE_WAYLAND = "1";
        QT_QPA_PLATFORM = "wayland";
        # xwayland-satellite advertises itself on DISPLAY=:0 by default.
        DISPLAY = ":0";
      };
    };
  };
}
