{ lib, pkgs, ... }:

# Base configuration shared across all home-manager users
# This file contains minimal common settings that every user needs

let
  unfreePackages = [
    "claude-code"
    "cuda_cudart"
    "cuda12.8-cuda_cudart-12.8.90"
    "discord"
    "google-chrome"
    "slack"
    "spotify"
    "spotify-unwrapped"
    "steam"
    "steam-original"
    "steam-unwrapped"
    "unrar"
    "vscode"
  ];
in
{
  # Enable experimental Nix features
  nix = {
    settings.experimental-features = [ "nix-command" "flakes" ];
  };

  # Nixpkgs configuration
  nixpkgs = {
    # Allow only whitelisted unfree packages (security best practice)
    config.allowUnfreePredicate = pkg:
      builtins.elem (lib.getName pkg) unfreePackages;

    # Permit specific insecure packages (needed for some legacy dependencies)
    config.permittedInsecurePackages = [
      "python2.7-pyjwt-1.7.1"
      "python2.7-certifi-2021.10.8"
      "python-2.7.18.6"
      "openssl-1.1.1u"
      "openssl-1.1.1v"
      "openssl-1.1.1w"
      "electron-13.6.9"
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
    };
  };

  # Font configuration
  fonts.fontconfig.enable = true;

  # Suppress home-manager news notifications
  news.display = "silent";

  # Enable nixpkgs release check
  home.enableNixpkgsReleaseCheck = true;
}
