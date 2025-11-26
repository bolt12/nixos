{ config, lib, pkgs, ... }:

# Syncthing configuration for file synchronization
# This module provides declarative Syncthing configuration at the user level

{
  services.syncthing = {
    enable = true;

    # Syncthing creates .stfolder markers and .stversions directories
    # in synced folders - these are expected and should not be removed

    # Device and folder configuration handled per-user in user-data.nix
    # Each user defines their own devices and folders based on their needs
  };
}
