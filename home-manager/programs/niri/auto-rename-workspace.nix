{ pkgs, lib, ... }:

let
  rename = pkgs.writeShellApplication {
    name = "niri-auto-rename-workspace";
    runtimeInputs = with pkgs; [
      niri-stable
      jq
    ];
    text = ''
      apply() {
        local app_id ws_idx ws_name
        app_id=$(niri msg --json focused-window 2>/dev/null | jq -r '.app_id // ""')
        ws_idx=$(niri msg --json focused-workspace 2>/dev/null | jq -r '.idx // empty')
        ws_name=$(niri msg --json focused-workspace 2>/dev/null | jq -r '.name // ""')

        # Skip named workspaces (scratchpad etc.); only relabel numbered ones.
        case "$ws_name" in ""|[1-9]|10) ;; *) return 0 ;; esac
        [ -z "$ws_idx" ] && return 0

        niri msg action set-workspace-name "$app_id" --workspace "$ws_idx" \
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
