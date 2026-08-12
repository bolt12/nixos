{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

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
    # username, homeDirectory, keyboard and EDITOR/VISUAL come from common/base.nix.
    stateVersion = "25.05";

    sessionPath = [
      "${config.userConfig.homeDirectory}/.local/bin"
    ];

    # Beginner-friendly packages for learning NixOS and ZFS
    packages = with pkgs; [
      # Learning resources
      tldr # Simplified man pages
      cheat # Command cheatsheets
    ];
  };

  # Additional programs
  programs = {
    man = {
      enable = true;
      generateCaches = true; # Better man page search
    };

    ssh = {
      enable = true;
      # 26.05 home-manager: matchBlocks is a deprecated alias for `settings`,
      # keyed by host pattern with upstream OpenSSH directive names.
      enableDefaultConfig = false;

      settings = {
        # Default settings for all hosts
        "*" = {
          ServerAliveInterval = 60;
          ServerAliveCountMax = 3;
        };
      };
    };
  };

  # No desktop services for headless configuration
  services = { };
}
