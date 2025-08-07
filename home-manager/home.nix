{ lib, inputs, pkgs, system, ... }:

let

  unstable = import inputs.nixpkgs-unstable {
    inherit system;
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
    "steam-unwrapped"
    "unrar"
    "vscode"
  ];

  nixops = inputs.nixops.defaultPackage.${system};

  agdaStdlibSrc = pkgs.fetchFromGitHub {
      owner  = "agda";
      repo   = "agda-stdlib";
      rev    = "master";
      sha256 = "sha256-TjGvY3eqpF+DDwatT7A78flyPcTkcLHQ1xcg+MKgCoE = "; # Replace with the correct hash
    };

in
{
  nix = {
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
  };

  i18n = {
    inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5 = {
        addons = with pkgs;
          [ fcitx5-gtk
            fcitx5-configtool
            fcitx5-mozc
            fcitx5-nord
            fcitx5-rime
          ];
      };
    };
  };

  home = {
    enableNixpkgsReleaseCheck = true;

    username      = "bolt";
    homeDirectory = "/home/bolt";
    stateVersion  = "24.05";

    keyboard = {
      layout = "us,pt";
      options = [
        "caps:escape"
        "grp:shifts_toggle"
      ];
    };

    # All packages now managed through modular profiles in ./profiles/
    # This provides better organization and eliminates all redundancy
    packages = [];

    sessionPath = [
      "/home/bolt/.local/bin"
      "/home/bolt/.cabal/bin"
      "/home/bolt/.cargo/bin"
    ];
  };

  imports = [
    # Core modules
    ./modules/wayland.nix                # Centralized Wayland environment variables

    # Modular package profiles - mix and match as needed
    ./profiles/desktop.nix               # GUI applications and desktop tools
    ./profiles/development.nix           # Programming and development tools
    ./profiles/system-tools.nix          # Core utilities and system administration
    ./profiles/specialized.nix           # Domain-specific and specialized tools
    ./profiles/wayland.nix               # Wayland compositor and related packages

    # Program configurations
    ./programs/agda/default.nix
    ./programs/bash/default.nix
    ./programs/emacs/default.nix
    ./programs/git/default.nix
    ./programs/kimai-client/default.nix
    ./programs/neovim/default.nix
    ./programs/sway/default.nix
    ./programs/tmux/default.nix
    ./programs/waybar/default.nix
    ./programs/wofi/default.nix
    ./xdg/sway/default.nix
  ];

  # fonts
  fonts.fontconfig.enable = true;

  # notifications about home-manager news
  news.display = "silent";

  # If a program requires to many options or something custom it might be better to
  # extract it into a different file
  programs = {

    home-manager.enable = true;
    htop.enable         = true;
    ssh.enable          = true;
    autorandr.enable    = true;
    firefox.enable      = true;

    ssh = {
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

    gpg = {
      enable = true;
      settings = {
        use-agent = true;
        pinentry-mode = "loopback";
      };
    };

    atuin = {
      enable                = true;
      enableBashIntegration = true;
    };
  };

  services = {

    lorri.enable          = true;
    blueman-applet.enable = true;
    udiskie.enable        = true;
    swayidle.enable       = true;
    poweralertd.enable    = true;
    autorandr.enable      = true;
    safeeyes.enable       = true;

    wlsunset = {
      enable    = true;
      latitude  = "39" ;
      longitude = "-8" ;
    };
  };

}
