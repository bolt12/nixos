{ config, lib, pkgs, inputs, ... }:

# Pollard's headless configuration for the ninho server
# Beginner-friendly setup with development tools and ZFS learning resources

{
  imports = [
    # Common base configuration
    ../../common/base.nix
    ../../common/user-options.nix

    # Package profiles (minimal for learning)
    ../../profiles/system-tools.nix
    ../../profiles/development.nix

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

    ssh = {
      enable = true;
      # Disable deprecated default config - explicitly set what we need
      enableDefaultConfig = false;

      matchBlocks = {
        # Default settings for all hosts (replaces deprecated defaults)
        "*" = {
          serverAliveInterval = 60;
          serverAliveCountMax = 3;
        };
      };
    };
  };

  # Reservation checker (user-level service for pollard only)
  systemd.user.services.reservation-checker = {
    Unit = {
      Description = "Online Reservations checker";
      After = [ "network.target" ];
    };

    Service = {
      Type = "simple";
      WorkingDirectory = "/home/pollard/projects/online-reservations";
      ExecStart = "/home/pollard/projects/online-reservations/reservation_checker.py";
      Restart = "always";
      RestartSec = "5";
      Environment = [
        "PYTHONUNBUFFERED=1"
        "NIX_PATH=nixpkgs=${pkgs.path}"
        "PATH=${pkgs.lib.makeBinPath [ pkgs.nix ]}"
      ];
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  # No desktop services for headless configuration
  services = {};
}
