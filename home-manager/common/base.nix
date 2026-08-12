{
  config,
  lib,
  pkgs,
  constants,
  ...
}:

# Base configuration shared across all home-manager users
# This file contains minimal common settings that every user needs
# Note: nixpkgs.config is managed at the system level (allowUnfree = true)
# and in the flake's pkgsFor for standalone homeConfigurations.

{
  # Enable experimental Nix features
  nix = {
    # HM 26.05 requires nix.package whenever nix.settings is set (it writes
    # a versioned nix.conf). mkDefault lets users pin their own (steam-deck).
    package = lib.mkDefault pkgs.nix;
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  # Common programs that every user should have
  programs = {
    home-manager.enable = true;
    htop.enable = true;
    ssh.enable = true;

    direnv = {
      enable = true;
      enableBashIntegration = true;
    };

    gpg = {
      enable = true;
      settings = {
        use-agent = true;
        pinentry-mode = "loopback";
      };
    };

    atuin = {
      enable = true;
      enableBashIntegration = true;
      settings = {
        sync_address = "http://${constants.network.ninho.vpnIp}:${toString constants.ports.atuin}";
        auto_sync = true;
        sync_frequency = "5m";
      };
    };
  };

  # Font configuration
  fonts.fontconfig.enable = true;

  # Suppress home-manager news notifications
  news.display = "silent";

  home = {
    enableNixpkgsReleaseCheck = true;

    # Identity is declared once via userConfig (common/user-options.nix) and
    # bridged to the home-manager builtins here, so each user file only sets
    # userConfig.{username,homeDirectory} rather than repeating both pairs.
    # mkDefault so a NixOS-integrated HM run defers to the system user's
    # name/home (home-manager's nixos module sets those); standalone
    # activations, which have no system user, still get them from userConfig.
    username = lib.mkDefault config.userConfig.username;
    homeDirectory = lib.mkDefault config.userConfig.homeDirectory;

    # Shared keyboard layout (US/PT, caps->escape, shift+shift layout toggle);
    # mkDefault so a user can diverge.
    keyboard = {
      layout = lib.mkDefault "us,pt";
      options = lib.mkDefault [
        "caps:escape"
        "grp:shifts_toggle"
      ];
    };

    # Default editor for every user; mkDefault so a user can override.
    sessionVariables = {
      EDITOR = lib.mkDefault "nvim";
      VISUAL = lib.mkDefault "nvim";
    };
  };
}
