{ pkgs, lib, ... }:

let
  iconMap = {
    "firefox" = "";
    "Chromium" = "";
    "chromium-browser" = "";
    "google-chrome" = "";
    "org.kde.konsole" = "";
    "code" = "";
    "Code" = "";
    "code-url-handler" = "";
    "neovide" = "";
    "Emacs" = "";
    "discord" = "󰙯";
    "Slack" = "";
    "org.telegram.desktop" = "";
    "Signal" = "";
    "thunderbird" = "";
    "obsidian" = "";
    "spotify" = "";
    "Spotify" = "";
    "org.keepassxc.KeePassXC" = "";
    "Bitwarden" = "";
    "1Password" = "";
    "imv" = "";
    "mpv" = "";
    "vlc" = "󰕼";
    "steam" = "";
    "moonlight" = "󰊴";
    "org.pulseaudio.pavucontrol" = "";
    "pwvucontrol" = "";
    "blueman-manager" = "";
    "nm-connection-editor" = "󰖩";
  };

  iconArrayLines = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (k: v: "  [${lib.escapeShellArg k}]=${lib.escapeShellArg v}") iconMap
  );

  rename = pkgs.writeShellApplication {
    name = "niri-auto-rename-workspace";
    runtimeInputs = with pkgs; [
      niri-unstable
      jq
    ];
    text = ''
      declare -A icons=(
      ${iconArrayLines}
      )

      apply() {
        local app_id ws_idx ws_name glyph
        app_id=$(niri msg --json focused-window 2>/dev/null | jq -r '.app_id // ""')
        IFS=$'\t' read -r ws_idx ws_name < <(
          niri msg --json focused-workspace 2>/dev/null \
            | jq -r '"\(.idx // "")\t\(.name // "")"'
        ) || true

        [ -z "$ws_idx" ] && return 0
        case "$ws_name" in scratchpad) return 0 ;; esac

        glyph="''${icons[$app_id]:-$ws_idx}"
        # Idempotent: niri's workspace name already matches what we'd set.
        [ "$ws_name" = "$glyph" ] && return 0

        niri msg action set-workspace-name "$glyph" --workspace "$ws_idx" \
          >/dev/null 2>&1 || true
      }

      apply
      niri msg --json event-stream 2>/dev/null | while IFS= read -r line; do
        case "$line" in
          *WindowFocusChanged*|*WorkspaceActivated*) apply ;;
        esac
      done
    '';
  };
in
{
  systemd.user.services.niri-auto-rename-workspace = {
    Unit = {
      Description = "Rename niri workspaces based on the focused window";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    Service = {
      ExecStart = lib.getExe rename;
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
