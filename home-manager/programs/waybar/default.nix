# Waybar configuration module - status bar for Wayland
# This module manages waybar configuration in a more structured way

{ pkgs, lib, ... }:
{
  # Run waybar as a user service so it auto-restarts when it crashes.
  # The MPRIS/playerctl module has a recurring use-after-free against
  # disappearing D-Bus players that segfaults the whole bar.
  systemd.user.services.waybar = {
    Unit = {
      Description = "Waybar status bar";
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
    Install.WantedBy = [ "graphical-session.target" ];
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
