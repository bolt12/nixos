{ config, lib, pkgs, stdenv, ... }:

let
  unstable = import (import ./unstable.nix) {};

  # url = "https://github.com/colemickens/nixpkgs-wayland/archive/master.tar.gz";
  # pkgs-wayland = import (builtins.fetchTarball url);

  unstablePkgs = [ unstable.manix ];

  defaultPkgs = with pkgs; [
    alloy                   # model checker
    agda                    # dependently typed programming language
    bash                    # bash
    betterlockscreen        # fast lockscreen based on i3lock
    blueman                 # bluetooth applet
    cachix                  # nix caching
    emacs                   # text editor
    evince                  # pdf reader
    flashfocus              # focus wm
    gawk                    # text processing programming language
    killall                 # kill processes by name
    konsole                 # terminal emulator
    libreoffice             # office suite
    lxappearance            # edit themes
    ncdu                    # disk space info (a better du)
    neofetch                # command-line system information
    networkmanagerapplet    # nm-applet
    nix-doc                 # nix documentation search tool
    numix-icon-theme-circle # icon theme
    numix-cursor-theme      # icon theme
    pamixer                 # pulseaudio cli mixer
    patchelf                # dynamic linker and RPATH of ELF executables
    pavucontrol             # pulseaudio volume control
    paprefs                 # pulseaudio preferences
    pasystray               # pulseaudio systray
    pcmanfm                 # file manager
    playerctl               # music player controller
    psensor                 # hardware monitoring
    pulsemixer              # pulseaudio mixer
    python3                 # python3 programming language
    rnix-lsp                # nix lsp server
    simplescreenrecorder    # self-explanatory
    slack                   # messaging client
    spotify                 # music source
    tldr                    # summary of a man page
    tree                    # display files in a tree view
    vlc                     # media player
    xclip                   # clipboard support (also for neovim)
    zoom-us                 # video conference
  ];

  gitPkgs = with pkgs.gitAndTools; [
    git
  ];

  gnomePkgs = with pkgs.gnome3; [
    gnome-power-manager
    gnome-control-center
    gnome-weather
    gnome-calendar # calendar
    zenity         # display dialogs
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
  ];

in
{
  nixpkgs.overlays = [
    # pkgs-wayland
  ];

  home = {
    username      = "bolt";
    homeDirectory = "/home/bolt";
    stateVersion  = "20.09";

    packages =
      defaultPkgs
      ++
      # Wayland Packages
      [ pkgs.firefox-wayland
        pkgs.grim
        pkgs.slurp
        pkgs.pkgs.swaylock-fancy
        pkgs.wofi
        # pkgs.wlsunset
        pkgs.xdg-desktop-portal-wlr
        # pkgs.wlogout
        pkgs.brightnessctl
        pkgs.wl-clipboard
        pkgs.waybar
      ]
      ++ gitPkgs
      ++ gnomePkgs
      ++ haskellPkgs
      ++ emacsPkgs
      ++ unstablePkgs;

    sessionVariables = {
      DISPLAY = ":0";
      EDITOR = "nvim";
      VISUAL = "nvim";
      SSHCOPY="DISPLAY=:0.0 xsel -i -b";
    };

    sessionPath = [
      "/home/bolt/.local/bin"
      "/home/bolt/.cabal/bin"
      "/home/bolt/.cargo/bin"
    ];

    keyboard = {
      layout = "pt";
      options = [
        "caps:escape"
      ];
    };
  };

  imports = [
    ./programs/git/default.nix
    ./programs/neovim/default.nix
    ./programs/bash/default.nix
    ./programs/waybar/default.nix
    ./programs/wofi/default.nix
    ./services/networkmanager/default.nix
    ./xdg/sway/default.nix
  ];

  programs = {

    direnv = {
      enable = true;
      enableBashIntegration = true;
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

  services.flameshot.enable = true;

}
