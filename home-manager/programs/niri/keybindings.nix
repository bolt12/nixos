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

  workspaceBinds = lib.listToAttrs (
    lib.concatMap (
      n:
      let
        key = if n == 10 then "0" else toString n;
      in
      [
        {
          name = "Mod+${key}";
          value.action.focus-workspace = toString n;
        }
        {
          name = "Mod+Shift+${key}";
          value.action.move-column-to-workspace = toString n;
        }
      ]
    ) (lib.range 1 10)
  );
in
{
  programs.niri.settings.binds = lib.mkMerge [
    {
      "Mod+Return" = spawn [ "konsole" ];
      "Mod+d" = spawn [ "fuzzel" ];
      "Mod+v" = shell "cliphist list | fuzzel --dmenu | cliphist decode | wl-copy";

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
      "Mod+e".action.toggle-overview = { };
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

      "Mod+Shift+minus".action.move-column-to-workspace = "scratchpad";
      "Mod+Shift+equal".action.focus-workspace = "scratchpad";

      "Mod+Tab".action.toggle-overview = { };

      "Mod+ctrl+Shift+m".action.power-off-monitors = { };
      "Mod+Shift+e" = spawn [ "wlogout" ];
      "Mod+Shift+x" = shell "loginctl lock-session";
    }

    (lib.optionalAttrs (portraitMonitor != null) {
      "Mod+Shift+m" = shell ''niri msg output "${portraitMonitor}" toggle || true'';
    })

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
