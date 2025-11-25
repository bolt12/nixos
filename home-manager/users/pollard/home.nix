{ config, lib, pkgs, inputs, system, ... }:

# Pollard's headless configuration for the ninho server
# Beginner-friendly setup with development tools and ZFS learning resources

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

    # Package profiles (minimal for learning)
    ../../profiles/system-tools.nix

    # Development programs (she's a software engineer)
    ../../programs/neovim/default.nix
    ../../programs/git/default.nix
    ../../programs/tmux/default.nix
    ../../programs/bash/default.nix

    # User-specific data (git email, ZFS learning aliases, etc.)
    ./user-data.nix
  ];

  # User configuration via options module
  userConfig = {
    username = "pollard";
    homeDirectory = "/home/pollard";
    git = {
      userName = "Claudia Pollard";
      userEmail = "claudiacorreiaa7@gmail.com";
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
    ];

    # Beginner-friendly packages for learning NixOS and ZFS
    packages = with pkgs; [
      # Learning resources
      tldr          # Simplified man pages
      cheat         # Command cheatsheets
    ];
  };

  # Additional programs
  programs = {
    man = {
      enable = true;
      generateCaches = true;  # Better man page search
    };
  };

  # No desktop services for headless configuration
  services = {};
}
