{ config, lib, ... }:

let
  inherit (config.userConfig.niri) portraitMonitor;
  spawn = argv: { action.spawn = argv; };
  shell =
    cmd:
    spawn [
      "sh"
      "-c"
      cmd
    ];

  # niri's focus-workspace takes either an integer (per-monitor index) or
  # a string (global workspace name). With on-demand workspaces the named
  # form silently no-ops because no workspace carries the name "1".."10".
  # Pass integers so Mod+N jumps to (or creates) the Nth workspace on the
  # focused monitor — niri's native per-monitor model.
  workspaceBinds = lib.listToAttrs (
    lib.concatMap (
      n:
      let
        key = if n == 10 then "0" else toString n;
      in
      [
        {
          name = "Mod+${key}";
          value.action.focus-workspace = n;
        }
        {
          name = "Mod+Shift+${key}";
          value.action.move-column-to-workspace = n;
        }
      ]
    ) (lib.range 1 10)
  );
in
{
  programs.niri.settings.binds = lib.mkMerge [
    {
      "Mod+Return" = spawn [ "konsole" ];

      # Launcher + clipboard: DankMaterialShell's theme-matched panels.
      # (fuzzel is still installed and drives the sway session; cliphist's
      # store daemons in niri/default.nix still populate history — DMS's
      # clipboard panel reads from them. Revert these two lines to
      # `spawn [ "fuzzel" ]` / the cliphist|fuzzel pipe to go back.)
      "Mod+d" = spawn [
        "dms"
        "ipc"
        "spotlight"
        "toggle"
      ];
      "Mod+v" = spawn [
        "dms"
        "ipc"
        "clipboard"
        "toggle"
      ];

      "Mod+Shift+q".action.close-window = { };

      "Mod+j".action.focus-column-left = { };
      "Mod+k".action.focus-window-down = { };
      "Mod+l".action.focus-window-up = { };
      "Mod+semicolon".action.focus-column-right = { };
      "Mod+Left".action.focus-column-left = { };
      "Mod+Down".action.focus-window-down = { };
      "Mod+Up".action.focus-window-up = { };
      "Mod+Right".action.focus-column-right = { };

      "Mod+Shift+j".action.move-column-left = { };
      "Mod+Shift+k".action.move-window-down = { };
      "Mod+Shift+l".action.move-window-up = { };
      "Mod+Shift+semicolon".action.move-column-right = { };
      "Mod+Shift+Left".action.move-column-left = { };
      "Mod+Shift+Down".action.move-window-down = { };
      "Mod+Shift+Up".action.move-window-up = { };
      "Mod+Shift+Right".action.move-column-right = { };

      "Mod+t".action.consume-or-expel-window-left = { };
      "Mod+f".action.maximize-column = { };
      "Mod+Shift+f".action.fullscreen-window = { };
      "Mod+w".action.toggle-column-tabbed-display = { };
      "Mod+s".action.switch-focus-between-floating-and-tiling = { };
      "Mod+o".action.toggle-overview = { };
      "Mod+Shift+space".action.toggle-window-floating = { };
      "Mod+space".action.switch-focus-between-floating-and-tiling = { };
      "Mod+a".action.center-column = { };
      "Mod+z".action.consume-or-expel-window-right = { };

      "Mod+r".action.switch-preset-column-width = { };
      "Mod+ctrl+Shift+r".action.switch-preset-window-height = { };
      "Mod+ctrl+r".action.reset-window-height = { };
      "Mod+minus".action.set-column-width = "-10%";
      "Mod+equal".action.set-column-width = "+10%";
      "Mod+ctrl+minus".action.set-window-height = "-10%";
      "Mod+ctrl+equal".action.set-window-height = "+10%";

      # Fuzzel-based MRU-ish window picker. niri-flake doesn't expose
      # focus-window-by-id directly, so we shell out: list windows as
      # "id\tapp · title", let fuzzel filter, and dispatch by id.
      "Mod+Tab" = shell ''
        id=$(niri msg --json windows \
          | jq -r '.[] | "\(.id)\t\(.app_id // "?") · \(.title // "")"' \
          | fuzzel --dmenu --prompt "windows: " \
          | cut -f1)
        [ -n "$id" ] && niri msg action focus-window --id "$id"
      '';
      # Quick toggle to the previously focused window (sway's swayr-1-back).
      "Mod+grave".action.focus-window-previous = { };

      "Mod+Shift+slash".action.show-hotkey-overlay = { };

      # DankMaterialShell panels (IPC). Only chords that don't clash with the
      # binds above (notably NOT Mod+p — that family is screenshots). DMS's
      # `enableKeybinds` is left off so these stay hand-managed here, and so
      # Mod stays Alt rather than DMS's Super default.
      "Mod+x" = spawn [
        "dms"
        "ipc"
        "powermenu"
        "toggle"
      ];
      "Mod+comma" = spawn [
        "dms"
        "ipc"
        "settings"
        "toggle"
      ];
      "Mod+m" = spawn [
        "dms"
        "ipc"
        "processlist"
        "toggle"
      ];
      "Mod+n" = spawn [
        "dms"
        "ipc"
        "notifications"
        "toggle"
      ];
      "Mod+alt+n" = spawn [
        "dms"
        "ipc"
        "night"
        "toggle"
      ];

      "Mod+ctrl+Shift+m".action.power-off-monitors = { };
      "Mod+Shift+e" = spawn [ "wlogout" ];
      "Mod+Shift+x" = shell "loginctl lock-session";
      # Restart waybar (e.g. after a crash). pkill first so the new instance
      # doesn't race with stale tray registrations.
      "Mod+Shift+b" = shell "pkill -x waybar; sleep 0.2; waybar &";
    }

    (lib.optionalAttrs (portraitMonitor != null) {
      "Mod+Shift+m" = shell ''niri msg output "${portraitMonitor}" toggle || true'';
      # 4K@30 is only feasible when BlitzWolf is off — the USB-C dock can't
      # sustain both at full bandwidth.
      "Mod+alt+Shift+m" = shell ''niri msg output "${portraitMonitor}" mode 3840x2160@30.000 || true'';
    })

    {
      "Mod+ctrl+Shift+e" = shell ''niri msg output "eDP-1" toggle || true'';
    }

    {
      "XF86AudioRaiseVolume" = spawn [
        "wpctl"
        "set-volume"
        "@DEFAULT_AUDIO_SINK@"
        "5%+"
      ];
      "XF86AudioLowerVolume" = spawn [
        "wpctl"
        "set-volume"
        "@DEFAULT_AUDIO_SINK@"
        "5%-"
      ];
      "XF86AudioMute" = spawn [
        "wpctl"
        "set-mute"
        "@DEFAULT_AUDIO_SINK@"
        "toggle"
      ];
      "XF86AudioMicMute" = spawn [
        "wpctl"
        "set-mute"
        "@DEFAULT_AUDIO_SOURCE@"
        "toggle"
      ];
      "XF86MonBrightnessDown" = spawn [
        "brightnessctl"
        "set"
        "10%-"
      ];
      "XF86MonBrightnessUp" = spawn [
        "brightnessctl"
        "set"
        "+10%"
      ];
      "XF86AudioPlay" = spawn [
        "playerctl"
        "play-pause"
      ];
      "XF86AudioNext" = spawn [
        "playerctl"
        "next"
      ];
      "XF86AudioPrev" = spawn [
        "playerctl"
        "previous"
      ];

      "Print".action.screenshot = { };
      "Mod+Shift+p".action.screenshot = { };
      "Mod+alt+p".action.screenshot-screen = { };
      "Mod+ctrl+Shift+p".action.screenshot-window = { };
      "Mod+Shift+s" = shell ''grim -g "$(slurp)" - | satty -f -'';
      "Mod+Shift+o" = shell ''grim -g "$(slurp)" - | tesseract stdin stdout | wl-copy'';
      # Second press SIGINTs the recorder so the MP4 finalises cleanly.
      "Mod+Shift+r" =
        shell ''pkill -INT wl-screenrec || (mkdir -p "$HOME/Videos" && wl-screenrec -f "$HOME/Videos/$(date +%Y%m%d-%H%M%S).mp4")'';

      "Mod+ctrl+Left".action.focus-monitor-left = { };
      "Mod+ctrl+Right".action.focus-monitor-right = { };
      "Mod+ctrl+Shift+Left".action.move-column-to-monitor-left = { };
      "Mod+ctrl+Shift+Right".action.move-column-to-monitor-right = { };

      "Mod+WheelScrollDown".action.focus-workspace-down = { };
      "Mod+WheelScrollUp".action.focus-workspace-up = { };
      "Mod+Shift+WheelScrollDown".action.move-column-to-workspace-down = { };
      "Mod+Shift+WheelScrollUp".action.move-column-to-workspace-up = { };
    }

    workspaceBinds
  ];
}
