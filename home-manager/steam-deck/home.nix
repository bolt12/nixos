{ pkgs, lib, inputs, ... }:

let

  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs) system;
    overlays = [
    ];
  };

  unfreePackages = [
    "discord"
    "google-chrome"
    "slack"
    "spotify"
    "spotify-unwrapped"
    "steam"
    "steam-original"
    "unrar"
    "vscode"
  ];

  agdaStdlibSrc = pkgs.fetchFromGitHub {
      owner = "agda";
      repo = "agda-stdlib";
      rev = "v2.0";
      sha256 = "sha256-TjGvY3eqpF+DDwatT7A78flyPcTkcLHQ1xcg+MKgCoE="; # Replace with the correct hash
    };

  nixops = inputs.nixops.defaultPackage.${pkgs.system};

  # Unstable branch packages
  # Package lists moved to profiles for better organization

  # Package lists removed - use profiles for organization

  # Git packages moved to profiles

  # Haskell packages moved to profiles

  # Font packages moved to profiles

in
{
  nix = {
    package = pkgs.nix;
    settings.experimental-features = [ "nix-command" "flakes" ];
  };

  nixpkgs = {
    config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) unfreePackages;
    config.permittedInsecurePackages = [ "python2.7-pyjwt-1.7.1"
                                         "python2.7-certifi-2021.10.8"
                                         "python-2.7.18.6"
                                         "openssl-1.1.1u"
                                         "openssl-1.1.1v"
                                         "openssl-1.1.1w"
                                         "electron-13.6.9"
                                       ];
    overlays = [ inputs.nixgl.overlay ];
  };

  home = {
    enableNixpkgsReleaseCheck = true;

    username      = "deck";
    homeDirectory = "/home/deck";
    stateVersion  = "23.11";

    keyboard = {
      layout = "us,pt";
      options = [
        "caps:escape"
        "grp:shifts_toggle"
      ];
    };

    # Package management handled by profiles - import as needed:
    # ../profiles/desktop.nix, ../profiles/development.nix, ../profiles/system-tools.nix etc.
    packages = [];

    sessionVariables = {
      EDITOR="nvim";
      VISUAL="nvim";
      BASH_ENV="/home/deck/.bashrc";
    };

    sessionPath = [
      "/home/deck/.local/bin"
      "/home/deck/.cabal/bin"
      "/home/deck/.cargo/bin"
      "/home/deck/.nix-profile/bin"
    ];

  };

  imports = [
    ../programs/agda/default.nix
    ../programs/bash/default.nix
    ../programs/emacs/default.nix
    ../programs/git/default.nix
    ../programs/neovim/default.nix
  ];

  # fonts
  fonts.fontconfig.enable = true;

  # notifications about home-manager news
  news.display = "silent";

  # If a program requires to many options or something custom it might be better to
  # extract it into a different file
  programs = {

    ssh = {
      enable = true;
      matchBlocks = {
        "rpi" = {
          hostname = "192.168.1.73";
          user = "bolt";
        };
      };
    };

    direnv = {
      enable = true;
      enableBashIntegration = true;
    };

    gpg.enable = true;

    home-manager.enable = true;

    htop.enable = true;

    atuin = {
      enable = true;
      enableBashIntegration = true;
    };

    autorandr.enable = true;

    firefox.enable = true;
  };

  services = {
  };

  xdg = {
    mime.enable = true;
    systemDirs.data = [
      "/home/deck/.nix-profile/share"
      "/nix/var/nix/profiles/default/share"
      "/home/deck/.local/share/flatpak/exports/share"
      "/var/lib/flatpak/exports/share"
      "/usr/local/share"
      "/usr/share"
      ];
  };

}

