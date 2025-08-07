# Waybar configuration module - status bar for Wayland
# This module manages waybar configuration in a more structured way

{ pkgs, ... }: {
  # Copy configuration files to appropriate locations
  xdg.configFile = {
    "waybar/config" = {
      source = ./config;
      # Configuration file for waybar layout and modules
    };
    
    "waybar/style.css" = {
      source = ./style.css; 
      # CSS styling for waybar appearance
    };
    
    "waybar/modules" = {
      source = ./modules;
      recursive = true;
      # Custom shell scripts for waybar modules
    };
  };
  
  # Waybar package is included in profiles/wayland.nix
  # This module only handles configuration files
}
