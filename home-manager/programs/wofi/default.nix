# Wofi configuration module - application launcher for Wayland
# This module manages wofi configuration files and settings

{ pkgs, ... }: {
  # Copy configuration files to appropriate locations  
  xdg.configFile = {
    "wofi/config" = {
      source = ./config;
      # Main configuration file defining wofi behavior and appearance
    };
    
    "wofi/style.css" = {
      source = ./style.css;
      # CSS styling for wofi's visual appearance and theming
    };
  };
  
  # Wofi package is included in profiles/wayland.nix
  # This module only handles configuration files
}
