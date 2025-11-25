{ config, pkgs, lib, inputs, ... }:

# Steam Deck home-manager configuration (standalone)
# This runs on SteamOS (non-NixOS) using home-manager standalone mode

let
  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs) system;
    overlays = [];
  };

  agdaStdlibSrc = pkgs.fetchFromGitHub {
    owner = "agda";
    repo = "agda-stdlib";
    rev = "v2.0";
    sha256 = "sha256-TjGvY3eqpF+DDwatT7A78flyPcTkcLHQ1xcg+MKgCoE=";
  };

  nixops = inputs.nixops.defaultPackage.${pkgs.system};
in
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
    settings.experimental-features = [ "nix-command" "flakes" ];
  };

  home = {
    username = config.userConfig.username;
    homeDirectory = config.userConfig.homeDirectory;
    stateVersion = "23.11";

    keyboard = {
      layout = "us,pt";
      options = [
        "caps:escape"
        "grp:shifts_toggle"
      ];
    };

    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      BASH_ENV = "${config.userConfig.homeDirectory}/.bashrc";
    };

    sessionPath = [
      "${config.userConfig.homeDirectory}/.local/bin"
      "${config.userConfig.homeDirectory}/.cabal/bin"
      "${config.userConfig.homeDirectory}/.cargo/bin"
      "${config.userConfig.homeDirectory}/.nix-profile/bin"
    ];

    # Minimal packages for Steam Deck
    packages = [];
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
  services = {};

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
