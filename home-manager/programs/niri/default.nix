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
    portraitWallpaperPath
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
        # The bar/shell (DankMaterialShell) autostarts via its own systemd
        # user service (dms.service), not from here. waybar is a manual
        # fallback only. This block handles the wallpaper + other startup apps.
        {
          # Single swaybg with per-output config: default fill, then override
          # the portrait output with -m fit so a landscape source letterboxes
          # instead of cropping.
          argv = [
            "swaybg"
            "-o"
            "*"
            "-i"
            "${toString wallpaperPath}"
            "-m"
            "fill"
          ]
          ++ lib.optionals (portraitMonitor != null) [
            "-o"
            portraitMonitor
            "-i"
            "${toString portraitWallpaperPath}"
            "-m"
            "fit"
          ];
        }
        # No nm-applet here: DankMaterialShell (the bar on niri) ships its own
        # NetworkManager (WiFi) widget, so the GTK tray applet would just be a
        # duplicate icon. The Sway fallback still spawns nm-applet (it has no
        # DMS), and networkmanagerapplet stays installed for nm-connection-editor.
        # XWayland bridge for X11-only apps (Steam launcher, older IDEs,
        # wine, xdotool/xev, etc) runs as a systemd user service below, so it
        # can import DISPLAY into the activation environment. niri's own
        # `environment.DISPLAY` only reaches niri-spawned children, not apps
        # launched via the launcher / D-Bus, which is why Steam (X11) failed.
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
        # xwayland-satellite advertises itself on DISPLAY=:0 by default.
        DISPLAY = ":0";
      };
    };
  };

  # DISPLAY must live in the systemd user manager's environment from the start,
  # so that EVERY graphical unit launched at login (notably dms.service, the
  # DankMaterialShell launcher) inherits it and can spawn X11 apps like Steam.
  #
  # `systemctl --user import-environment` (done by the service below) only
  # affects units started AFTER the import; dms.service starts at login, before
  # the import lands, so its launcher children never saw DISPLAY. That is why
  # Steam worked from a terminal (fresh shell, post-import) but not from the dms
  # menu. Setting it here writes ~/.config/environment.d, which the user manager
  # reads before launching any unit, fixing it for all launchers.
  systemd.user.sessionVariables.DISPLAY = ":0";

  # Run xwayland-satellite as a systemd user service rather than a niri
  # spawn-at-startup child. niri's own `environment.DISPLAY` only reaches
  # niri-spawned children. xwayland-satellite signals readiness via sd_notify
  # (Type=notify), and on a fixed display (:0) so the env var above is correct.
  systemd.user.services.xwayland-satellite = {
    Unit = {
      Description = "Xwayland outside your Wayland (for niri)";
      BindsTo = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      Requisite = [ "graphical-session.target" ];
    };
    Service = {
      Type = "notify";
      NotifyAccess = "all";
      ExecStart = "${pkgs.xwayland-satellite-unstable}/bin/xwayland-satellite :0";
      # Belt-and-suspenders: also publish/unpublish DISPLAY to the running
      # manager env (covers a manual restart after login). The sessionVariables
      # entry above is what actually fixes launcher-spawned apps.
      ExecStartPost = "${pkgs.systemd}/bin/systemctl --user import-environment DISPLAY";
      ExecStopPost = "${pkgs.systemd}/bin/systemctl --user unset-environment DISPLAY";
      Restart = "on-failure";
      RestartSec = 1;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
