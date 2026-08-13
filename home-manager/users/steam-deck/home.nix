{
  config,
  pkgs,
  lib,
  inputs,
  constants,
  ...
}:

# Steam Deck home-manager configuration (standalone)
# This runs on SteamOS (non-NixOS) using home-manager standalone mode

{
  imports = [
    # Common base configuration
    ../../common/base.nix
    ../../common/user-options.nix

    # Program configurations
    ../../programs/agda/default.nix
    ../../programs/bash/default.nix
    ../../programs/emacs/default.nix
    ../../programs/git/default.nix
    ../../programs/neovim/default.nix

    # User-specific data
    ./user-data.nix
  ];

  # User configuration via options module
  userConfig = {
    username = "deck";
    homeDirectory = "/home/deck";
    git = {
      userName = "Armando Santos (Steam Deck)";
      userEmail = "armandoifsantos@gmail.com";
      signingKey = null;
    };
  };

  # nixGL overlay for OpenGL support on non-NixOS
  nixpkgs.overlays = [ inputs.nixgl.overlay ];

  # Nix package manager settings (Steam Deck specific)
  nix = {
    package = pkgs.nix;
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  home = {
    # username, homeDirectory, keyboard and EDITOR/VISUAL come from common/base.nix.
    stateVersion = "23.11";

    sessionVariables = {
      BASH_ENV = "${config.userConfig.homeDirectory}/.bashrc";
    };

    sessionPath = [
      "${config.userConfig.homeDirectory}/.local/bin"
      "${config.userConfig.homeDirectory}/.cabal/bin"
      "${config.userConfig.homeDirectory}/.cargo/bin"
      "${config.userConfig.homeDirectory}/.nix-profile/bin"
    ];

    # Minimal packages for Steam Deck
    packages = with pkgs; [
      tailscale # tailnet client for the Deck
    ];

    # The Deck joins the tailnet with the Tailscale client (SteamOS ships it):
    #   tailscale up --login-server=https://hetzner-nixos.ddns.net
  };

  # Additional programs
  programs = {
    ssh = {
      matchBlocks = {
        "rpi" = {
          hostname = "192.168.1.73";
          user = "bolt";
        };
      };
    };

    autorandr.enable = true;
    firefox.enable = true;
  };

  # No services for Steam Deck
  services = { };

  # XDG configuration for Flatpak integration
  xdg = {
    mime.enable = true;
    systemDirs.data = [
      "${config.userConfig.homeDirectory}/.nix-profile/share"
      "/nix/var/nix/profiles/default/share"
      "${config.userConfig.homeDirectory}/.local/share/flatpak/exports/share"
      "/var/lib/flatpak/exports/share"
      "/usr/local/share"
      "/usr/share"
    ];
  };
}
