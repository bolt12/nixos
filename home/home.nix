{ config, lib, pkgs, stdenv, ... }:

let
  unstable = import (import ./unstable.nix) {};

  pkgs-wayland = import (import ./nixpkgs-wayland.nix) {};

  unstablePkgs = [ unstable.manix ];

  defaultPkgs = with pkgs; [
    act                   # run github actions locally
    agda                  # dependently typed programming language
    betterlockscreen      # fast lockscreen based on i3lock
    cachix                # nix caching
    dmenu                 # application launcher
    emacs                 # text editor
    evince                # pdf reader
    killall               # kill processes by name
    konsole               # terminal emulator
    libreoffice           # office suite
    libnotify             # notify-send command
    material-design-icons # icon pack
    ncdu                  # disk space info (a better du)
    neofetch              # command-line system information
    nix-doc               # nix documentation search tool
    patchelf              # dynamic linker and RPATH of ELF executables
    pavucontrol           # pulseaudio volume control
    paprefs               # pulseaudio preferences
    pasystray             # pulseaudio systray
    pcmanfm               # file manager
    playerctl             # music player controller
    pulsemixer            # pulseaudio mixer
    rnix-lsp              # nix lsp server
    simplescreenrecorder  # self-explanatory
    slack                 # messaging client
    spotify               # music source
    tldr                  # summary of a man page
    tree                  # display files in a tree view
    vlc                   # media player
    xclip                 # clipboard support (also for neovim)
    zoom-us               # video conference
  ];

  waylandPkgs = with pkgs-wayland; [
    pkgs.firefox-wayland
    grim
    slurp
    pkgs.swaylock-fancy
    wofi
    wlsunset
    xdg-desktop-portal-wlr
  ]

  gitPkgs = with pkgs.gitAndTools; [
    git
  ];

  gnomePkgs = with pkgs.gnome3; [
    gnome-calendar # calendar
    zenity         # display dialogs
    # themes
    adwaita-icon-theme
  ];

  haskellPkgs = with pkgs.haskellPackages; [
    fourmolu                # code formatter
    cabal2nix               # convert cabal projects to nix
    cabal-install           # package manager
    stack                   # package manager
    ghc                     # compiler
    haskell-language-server # haskell IDE (ships with ghcide)
    hoogle                  # documentation
    nix-tree                # visualize nix dependencies
  ];

  emacsPkgs = with pkgs.emacs26Packages; [
    doom
    doom-themes
  ]

in
{
  nixpkgs.overlays = [
  ];

  home = {
    username      = "bolt";
    homeDirectory = "/home/bolt";
    stateVersion  = "20.09";

    packages =
      defaultPkgs
      ++ waylandPkgs
      ++ gitPkgs
      ++ gnomePkgs
      ++ haskellPkgs
      ++ emacsPkgs
      ++ unstablePkgs;

    sessionVariables = {
      DISPLAY = ":0";
      EDITOR = "nvim";
      VISUAL = "nvim";
      SSHCOPY='DISPLAY=:0.0 xsel -i -b'
    } // (lib.optionalAttrs isLinux {
      XDG_CURRENT_DESKTOP = "sway";
    });

    sessionPath = [
      "/home/bolt/.local/bin"
      "/home/bolt/.cabal/bin"
      "/home/bolt/.cargo/bin"
    ];

    keyboard = {
      layout = "pt-latin1";
      options = [
        "caps:escape"
      ];
    }
  };

  imports = [
    ./programs/git/default.nix
    ./programs/neovim/default.nix
    ./programs/bash/default.nix
    ./services/networkmanager/default.nix
  ];

  programs = {
    broot = {
      enable = true;
    };

    direnv = {
      enable = true;
      enableBashIntegration = true;
    };

    git = {
    };

    gpg.enable = true;

    home-manager.enable = true;

    htop = {
      enable = true;
      sortDescending = true;
      sortKey = "PERCENT_CPU";
    };

    ssh.enable = true;
  };

  services = {
    flameshot.enable = true;
  };

}
