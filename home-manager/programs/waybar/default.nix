# Waybar configuration module - status bar for Wayland
# This module manages waybar configuration in a more structured way

{ pkgs, ... }:
{
  # Waybar is no longer the daily-driver bar — DankMaterialShell took over
  # (see users/bolt-with-de/home.nix). We keep the unit + config defined as a
  # fallback you can start by hand (`systemctl --user start waybar` or the
  # Mod+Shift+b bind), but it is NOT WantedBy the session, so it does not
  # autostart on login alongside DMS.
  #
  # The MPRIS/playerctl module has a recurring use-after-free against
  # disappearing D-Bus players that segfaults the bar, hence Restart=on-failure.
  systemd.user.services.waybar = {
    Unit = {
      Description = "Waybar status bar (manual fallback; DMS is the default)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
      # Cap restarts so a hard config error doesn't loop forever.
      StartLimitBurst = 5;
      StartLimitIntervalSec = 60;
    };
    Service = {
      ExecStart = "${pkgs.waybar}/bin/waybar";
      Restart = "on-failure";
      RestartSec = 1;
    };
    # No Install.WantedBy: do not autostart. Started on demand only.
  };

  # Copy configuration files to appropriate locations
  xdg.configFile = {
    "waybar/config" = {
      source = ./config;
      force = true;
      # Configuration file for waybar layout and modules
    };

    "waybar/style.css" = {
      source = ./style.css;
      force = true;
      # CSS styling for waybar appearance
    };

    "waybar/modules" = {
      source = ./modules;
      recursive = true;
      force = true;
      # Custom shell scripts for waybar modules
    };
  };

  # Waybar package is included in profiles/wayland.nix
  # This module only handles configuration files
}
