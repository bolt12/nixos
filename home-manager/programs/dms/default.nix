{ pkgs, ... }:

# DankMaterialShell (DMS) escape-hatch helpers.
#
# DMS itself is the daily-driver shell/bar, enabled via the upstream
# `dank-material-shell` HM module in users/bolt-with-de/home.nix — that module
# installs the dms-shell + Quickshell packages, every feature dependency
# (dgop, matugen, cava, khal, wtype), and the autostart systemd user service.
# We do NOT duplicate any of that here.
#
# This module only ships two small convenience scripts for when DMS misbehaves
# (it's Quickshell-based — the same engine whose threaded render loop crashed
# Noctalia on this iGPU):
#
#   dms-stop  — kill DMS and start waybar as a fallback bar
#   dms-start — kill waybar and (re)start DMS via its systemd service
#
# DMS runs under the systemd user service `dms.service`, so the normal control
# path is `systemctl --user restart dms` — these wrappers just add the
# waybar handoff and a broad kill for stuck Quickshell processes.

let
  dms-stop = pkgs.writeShellScriptBin "dms-stop" ''
    set -euo pipefail
    echo "Stopping DankMaterialShell…"
    ${pkgs.systemd}/bin/systemctl --user stop dms.service 2>/dev/null || true
    dms kill 2>/dev/null || ${pkgs.procps}/bin/pkill -f 'dms run' || true
    # Belt-and-suspenders: clean up any stuck Quickshell process DMS spawned.
    ${pkgs.procps}/bin/pkill -f quickshell || true

    echo "Starting waybar as a fallback bar…"
    ${pkgs.systemd}/bin/systemctl --user start waybar.service || true
  '';

  dms-start = pkgs.writeShellScriptBin "dms-start" ''
    set -euo pipefail
    echo "Stopping waybar fallback…"
    ${pkgs.systemd}/bin/systemctl --user stop waybar.service || true

    echo "(Re)starting DankMaterialShell via its systemd service…"
    ${pkgs.systemd}/bin/systemctl --user restart dms.service
  '';
in
{
  home.packages = [
    dms-stop
    dms-start
  ];
}
