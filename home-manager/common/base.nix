{ lib, pkgs, ... }:

# Base configuration shared across all home-manager users
# This file contains minimal common settings that every user needs
# Note: nixpkgs.config is managed at the system level (allowUnfree = true)
# and in the flake's pkgsFor for standalone homeConfigurations.

{
  # Enable experimental Nix features
  nix = {
    settings.experimental-features = [ "nix-command" "flakes" ];
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
        sync_address = "http://10.100.0.100:8888";
        auto_sync = true;
        sync_frequency = "5m";
      };
    };
  };

  # Font configuration
  fonts.fontconfig.enable = true;

  # Suppress home-manager news notifications
  news.display = "silent";

  # Enable nixpkgs release check
  home.enableNixpkgsReleaseCheck = true;
}
