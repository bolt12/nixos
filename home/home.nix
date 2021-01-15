{ config, lib, stdenv, sources ? (import ./nix/sources.nix) , ... }:

let

  unstable = import sources.nixpkgs-unstable {
    overlays = [
      (import sources.nixpkgs-wayland)
    ];
  };

  sources = import ./nix/sources.nix;

  pkgs = import sources.nixpkgs {
    overlays = [
      (import sources.nixpkgs-wayland)
    ];
    config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) unfreePackages;
  };

  unfreePackages = [
    "discord"
    "skypeforlinux"
    "slack"
    "spotify"
    "spotify-unwrapped"
    "zoom-us"
    "faac" # part of zoom
  ];

  # Unstable branch packages
  unstablePkgs = [ unstable.manix ];

  # Extra packages from user repos
  extraPkgs = [
    (import sources.comma { inherit pkgs; })
  ];

  defaultPkgs = with pkgs; [
    alloy                       # model checker
    agda                        # dependently typed programming language
    bash                        # bash
    bc                          # gnu calculator
    betterlockscreen            # fast lockscreen based on i3lock
    blueman                     # bluetooth applet
    cachix                      # nix caching
    deluge                      # torrent client
    discord                     # discord client
    emacs                       # text editor
    evince                      # pdf reader
    flashfocus                  # focus wm
    gawk                        # text processing programming language
    glib                        # gsettings
    gsettings-desktop-schemas   # theming related
    gtk-engine-murrine          # theme engine
    gtk_engines                 # theme engines
    jq                          # JSON processor
    killall                     # kill processes by name
    konsole                     # terminal emulator
    libreoffice                 # office suite
    lxappearance                # edit themes
    lxmenu-data                 # desktop menus - enables "open with" options
    ncdu                        # disk space info (a better du)
    neofetch                    # command-line system information
    networkmanagerapplet        # nm-applet
    (import sources.niv {}).niv # dependency management for nix
    nix-doc                     # nix documentation search tool
    numix-icon-theme-circle     # icon theme
    numix-cursor-theme          # icon theme
    pamixer                     # pulseaudio cli mixer
    patchelf                    # dynamic linker and RPATH of ELF executables
    pavucontrol                 # pulseaudio volume control
    paprefs                     # pulseaudio preferences
    pasystray                   # pulseaudio systray
    pcmanfm                     # file manager
    playerctl                   # music player controller
    psensor                     # hardware monitoring
    pulsemixer                  # pulseaudio mixer
    python3                     # python3 programming language
    rnix-lsp                    # nix lsp server
    shared-mime-info            # database of common MIME types
    simplescreenrecorder        # self-explanatory
    skypeforlinux               # skype for linux
    slack                       # slack client
    spotify                     # spotify client
    tldr                        # summary of a man page
    tree                        # display files in a tree view
    vlc                         # media player
    xclip                       # clipboard support (also for neovim)
    xsettingsd                  # theming
    zoom-us                     # zoom client
  ];

  # Wayland Packages
  waylandPkgs = [
      pkgs.grim
      pkgs.slurp
      pkgs.pkgs.swaylock-fancy
      pkgs.wofi
      unstable.wlsunset
      pkgs.xdg-desktop-portal-wlr
      unstable.wlogout
      pkgs.brightnessctl
      pkgs.wl-clipboard
      unstable.waybar
  ];

  gitPkgs = with pkgs.gitAndTools; [
    git
    diff-so-fancy
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
      ++ unstablePkgs
      ++ extraPkgs;

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
    ./programs/bash/default.nix
    ./programs/firefox/default.nix
    ./programs/git/default.nix
    ./programs/neovim/default.nix
    ./programs/waybar/default.nix
    ./programs/wofi/default.nix
    ./services/networkmanager/default.nix
    ./services/redshift/default.nix
    ./xdg/sway/default.nix
  ];

  # notifications about home-manager news
  news.display = "silent";

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
  services.lorri.enable = true;

}
