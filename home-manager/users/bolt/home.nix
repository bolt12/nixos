{ config, lib, pkgs, inputs, system, ... }:

# Bolt's headless configuration for the ninho server
# This configuration includes development tools and specialized packages
# but excludes desktop environment components

let
  unstable = import inputs.nixpkgs-unstable {
    inherit system;
    overlays = [];
  };
in
{
  imports = [
    # Common base configuration
    ../../common/base.nix
    ../../common/user-options.nix

    # Package profiles (headless - no desktop/wayland)
    ../../profiles/system-tools.nix
    ../../profiles/development.nix
    ../../profiles/specialized.nix   # Agda, Lean, Arduino, etc.

    # Program configurations
    ../../programs/agda/default.nix
    ../../programs/bash/default.nix
    ../../programs/emacs/default.nix
    ../../programs/git/default.nix
    ../../programs/kimai-client/default.nix
    ../../programs/neovim/default.nix
    ../../programs/syncthing/default.nix
    ../../programs/tmux/default.nix

    # User-specific data (git email, bash aliases, Syncthing config, etc.)
    ./user-data.nix
  ];

  # User configuration via options module
  userConfig = {
    username = "bolt";
    homeDirectory = "/home/bolt";
    git = {
      userName = "Armando Santos";
      userEmail = "armandoifsantos@gmail.com";
      signingKey = null;
    };
  };

  home = {
    username = config.userConfig.username;
    homeDirectory = config.userConfig.homeDirectory;
    stateVersion = "25.05";

    keyboard = {
      layout = "us,pt";
      options = [
        "caps:escape"
        "grp:shifts_toggle"
      ];
    };

    sessionPath = [
      "${config.userConfig.homeDirectory}/.local/bin"
      "${config.userConfig.homeDirectory}/.cabal/bin"
      "${config.userConfig.homeDirectory}/.cargo/bin"
    ];

    # All packages managed through profiles
    packages = [];
  };

  # Additional programs (headless - no firefox, no autorandr)
  programs = {
    ssh = {
      matchBlocks = {
        "rpi" = {
          hostname = "10.100.1.1";
          user = "bolt";
        };
        "ninho" = {
          hostname = "10.100.1.100";
          user = "bolt";
        };
      };
    };
  };

  # No desktop services for headless configuration
  services = {};
}
