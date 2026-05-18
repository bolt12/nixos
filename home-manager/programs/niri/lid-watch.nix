{
  config,
  pkgs,
  lib,
  ...
}:

# Lid-aware eDP-1 toggle. Mirrors sway's `bindswitch lid:on/off` but lives
# entirely in user space: a small daemon polls /proc/acpi/button/lid/LID/state
# and runs `niri msg output eDP-1 on|off` whenever the value flips.
#
# Why /proc polling (vs upower / acpid / dbus-monitor):
#   - acpid runs as root → would need sudo to talk to the niri socket.
#   - upower on this kernel doesn't expose `lid-is-closed` (verified empty
#     across DisplayDevice + every battery/line_power device on X1G8).
#   - dbus-monitor on logind works but pulls a much heavier dependency for
#     a single-bit poll. The /proc node is cheap and universally available.

let
  inherit (config.userConfig.niri) primaryMonitor;

  lidWatch = pkgs.writeShellApplication {
    name = "niri-lid-watch";
    runtimeInputs = with pkgs; [
      niri-unstable
      coreutils
    ];
    text = ''
      output=${lib.escapeShellArg primaryMonitor}
      lid_file=/proc/acpi/button/lid/LID/state

      apply() {
        local state="$1"
        case "$state" in
          open)   niri msg output "$output" on  >/dev/null 2>&1 || true ;;
          closed) niri msg output "$output" off >/dev/null 2>&1 || true ;;
        esac
      }

      read_state() {
        # /proc line looks like:  "state:      closed"
        if [ -r "$lid_file" ]; then
          awk '{print $2}' "$lid_file"
        else
          echo open
        fi
      }

      last=""
      while :; do
        cur=$(read_state)
        if [ "$cur" != "$last" ]; then
          apply "$cur"
          last="$cur"
        fi
        sleep 2
      done
    '';
  };
in
{
  systemd.user.services.niri-lid-watch = {
    Unit = {
      Description = "Toggle ${primaryMonitor} on laptop lid open/close";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    Service = {
      ExecStart = lib.getExe lidWatch;
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
