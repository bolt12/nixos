{ config, lib, pkgs, stdenv, ... }:

let
  unstable = import (import ./unstable.nix) {};

  unstablePkgs = [ unstable.manix ];

  defaultPkgs = with pkgs; [
    firefox              # browser
    act                  # run github actions locally
    betterlockscreen     # fast lockscreen based on i3lock
    cachix               # nix caching
    dmenu                # application launcher
    emacs                # text editor
    killall              # kill processes by name
    konsole              # terminal emulator
    libreoffice          # office suite
    libnotify            # notify-send command
    ncdu                 # disk space info (a better du)
    neofetch             # command-line system information
    nix-doc              # nix documentation search tool
    patchelf             # TODO
    pavucontrol          # pulseaudio volume control
    paprefs              # pulseaudio preferences
    pasystray            # pulseaudio systray
    playerctl            # music player controller
    pulsemixer           # pulseaudio mixer
    rnix-lsp             # nix lsp server
    simplescreenrecorder # self-explanatory
    slack                # messaging client
    spotify              # music source
    tldr                 # summary of a man page
    tree                 # display files in a tree view
    vlc                  # media player
    xclip                # clipboard support (also for neovim)

    # fixes the `ar` error required by cabal
    # binutils-unwrapped
  ];

  waylandPckgs = with pkgs; [
    firefox-wayland
    grim
    slurp
    swaylock-fancy
    wofi
    xdg-desktop-portal-wlr
  ]

  gitPkgs = with pkgs.gitAndTools; [
  ];

  gnomePkgs = with pkgs.gnome3; [
    evince         # pdf reader
    gnome-calendar # calendar
    nautilus       # file manager
    zenity         # display dialogs
    # themes
    adwaita-icon-theme
    pkgs.material-design-icons
  ];

  haskellPkgs = with pkgs.haskellPackages; [
    ormolu                 # code formatter
    cabal2nix               # convert cabal projects to nix
    cabal-install           # package manager
    ghc                     # compiler
    haskell-language-server # haskell IDE (ships with ghcide)
    hoogle                  # documentation
    nix-tree                # visualize nix dependencies
  ];

  polybarPkgs = with pkgs; [
    font-awesome-ttf      # awesome fonts
    material-design-icons # fonts with glyphs
  ];

  taffybarPkgs = with unstable; [
    pkgs.hicolor-icon-theme              # theme needed for taffybar systray
    taffybar                             # status bar written in Haskell
    haskellPackages.gtk-sni-tray         # gtk-sni-tray-standalone
    haskellPackages.status-notifier-item # status-notifier-watcher for taffybar
  ];

  xmonadPkgs = with pkgs; [
    haskellPackages.libmpd # music player daemon
    haskellPackages.xmobar # status bar
    networkmanager_dmenu   # networkmanager on dmenu
    networkmanagerapplet   # networkmanager applet
    nitrogen               # wallpaper manager
    xcape                  # keymaps modifier
    xorg.xkbcomp           # keymaps modifier
    xorg.xmodmap           # keymaps modifier
    xorg.xrandr            # display manager (X Resize and Rotate protocol)
  ];

in
{
  programs.home-manager.enable = true;

  nixpkgs.overlays = [
    (import ./overlays/act.nix)
  ];

  imports = [
    ./programs/git/default.nix
    ./programs/neovim/default.nix
    ./programs/rofi/default.nix
    ./programs/xmonad/default.nix
    ./services/dunst/default.nix
    ./services/gpg-agent/default.nix
    ./services/networkmanager/default.nix
    ./services/picom/default.nix
    ./services/screenlocker/default.nix
    ./services/udiskie/default.nix
  ];

  xdg.enable = true;

  home = {
    username      = "bolt";
    homeDirectory = "/home/bolt";
    stateVersion  = "20.09";

    packages = defaultPkgs ++ gitPkgs ++ gnomePkgs ++ haskellPkgs ++ polybarPkgs ++ xmonadPkgs ++ unstablePkgs;

    sessionVariables = {
      DISPLAY = ":0";
      EDITOR = "nvim";
    };
  };

  manual = {
    json.enable = false;
    html.enable = false;
    manpages.enable = false;
  };

  # notifications about home-manager news
  news.display = "silent";

  gtk = {
    enable = true;
    iconTheme = {
      name = "Adwaita-dark";
      package = pkgs.gnome3.adwaita-icon-theme;
    };
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome3.adwaita-icon-theme;
    };
  };

  programs = {
    bat.enable = true;

    broot = {
      enable = true;
    };

    direnv = {
      enable = true;
      enableNixDirenvIntegration = true;
    };

    fzf = {
      enable = true;
    };

    gpg.enable = true;

    htop = {
      enable = true;
      sortDescending = true;
      sortKey = "PERCENT_CPU";
    };

    jq.enable = true;
    ssh.enable = true;
  };

  services = {
    flameshot.enable = true;
  };

}
