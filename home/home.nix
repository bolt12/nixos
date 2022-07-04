{ config, lib, stdenv, sources ? (import ./nix/sources.nix), ... }:

let

  unstable = import sources.nixpkgs-unstable {
    overlays = [
      (import sources.nixpkgs-wayland)
    ];
  };

  sources = import ./nix/sources.nix;

  pkgs = import sources.nixpkgs {
    overlays = [
      (import sources.neovim-nightly-overlay)
    ];
    config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) unfreePackages;
  };

  easy-hls-nix = pkgs.callPackage sources.easy-hls-nix {
    ghcVersions = [
      "8.6.5"
      "8.8.4"
      "8.10.7"
      "9.0.2"
    ];
  };

  unfreePackages = [
    "discord"
    "skypeforlinux"
    "slack"
    "spotify"
    "spotify-unwrapped"
    "zoom-us"
    "unrar"
    "faac" # part of zoom
  ];

  # Unstable branch packages
  unstablePkgs = [
    unstable.manix
  ];

  # Extra packages from user repos
  extraPkgs = [
    # (import sources.comma { inherit pkgs; })
  ];

  defaultPkgs = with pkgs; [
    alloy                       # model checker
    (agda.withPackages (p: [ p.standard-library ]))
    awscli2                     # aws cli v2
    bash                        # bash
    bc                          # gnu calculator
    betterlockscreen            # fast lockscreen based on i3lock
    blueman                     # bluetooth applet
    cachix                      # nix caching
    chromium                    # google chrome
    deluge                      # torrent client
    unstable.discord            # discord client
    evince                      # pdf reader
    feh                         # image viewer
    ferdi                       # bundle apps together
    flashfocus                  # focus wm
    gawk                        # text processing programming language
    glib                        # gsettings
    gsettings-desktop-schemas   # theming related
    gtk-engine-murrine          # theme engine
    gtk_engines                 # theme engines
    jdk                         # java development kit
    jq                          # JSON processor
    jre                         # java runtime environment
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
    nodejs                      # nodejs
    noip                        # noip
    numix-icon-theme-circle     # icon theme
    numix-cursor-theme          # icon theme
    obs-studio                  # obs-studio
    obs-studio-plugins.wlrobs   # obs wayland protocol
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
    ripgrep                     # ripgrep
    rnix-lsp                    # nix lsp server
    silicon                     # create beautiful code imgs
    simplescreenrecorder        # self-explanatory
    skypeforlinux               # skype for linux
    slack                       # slack client
    spotify                     # spotify client
    tldr                        # summary of a man page
    tree                        # display files in a tree view
    unzip                       # unzip
    vlc                         # media player
    xarchiver                   # xarchiver gtk frontend
    xclip                       # clipboard support (also for neovim)
    xorg.xmodmap                # Keyboard
    xsettingsd                  # theming
    weechat                     # weechat irc client
    wget                        # cli wget
    zip                         # zip
    zoom                        # video conferencing
  ];

  # Wayland Packages
  waylandPkgs = [
    unstable.grim
    unstable.slurp
    pkgs.swaylock-fancy
    unstable.wofi
    unstable.wlsunset
    unstable.xdg-desktop-portal
    unstable.xdg-desktop-portal-wlr
    unstable.wlogout
    unstable.pipewire
    unstable.wl-gammactl
    pkgs.brightnessctl
    unstable.wl-clipboard
    unstable.mako
    unstable.swayidle
    pkgs.wayland-protocols
    unstable.wdisplays
    unstable.waybar
  ];

  gitPkgs = with pkgs.gitAndTools; [
    diff-so-fancy
  ];

  gnomePkgs = with pkgs.gnome3; [
    gnome-power-manager
    gnome-control-center
    gnome-weather
    gnome-calendar # calendar
    zenity         # display dialogs
  ];

  haskellPkgs = [
    pkgs.haskellPackages.stylish-haskell         # code formatter
    pkgs.haskellPackages.fourmolu                # code formatter
    pkgs.haskellPackages.cabal2nix               # convert cabal projects to nix
    pkgs.haskellPackages.cabal-install           # package manager
    pkgs.haskellPackages.stack                   # package manager
    pkgs.haskellPackages.ghc                     # compiler
    pkgs.haskellPackages.hoogle                  # documentation
    pkgs.haskellPackages.nix-tree                # visualize nix dependencies
    easy-hls-nix                                 # haskell IDE (ships with ghcide)
  ];

in
{
  home = {
    username      = "bolt";
    homeDirectory = "/home/bolt";
    stateVersion  = "21.11";

    packages =
      defaultPkgs
      ++ waylandPkgs
      ++ gitPkgs
      ++ gnomePkgs
      ++ haskellPkgs
      ++ unstablePkgs
      ++ extraPkgs;

    sessionVariables = {
      MOZ_DISABLE_RDD_SANDBOX = "1";
      MOZ_ENABLE_WAYLAND = "1";
      XDG_CURRENT_DESKTOP = "sway";
      XDG_SESSION_TYPE = "wayland";
      SDL_VIDEODRIVER = "wayland";
      QT_QPA_PLATFORM = "wayland";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
      ECORE_EVAS_ENGINE = "wayland_egl";
      ELM_ENGINE = "wayland_egl";
      DISPLAY = ":0";
      EDITOR = "nvim";
      VISUAL = "nvim";
      SSHCOPY = "DISPLAY=:0.0 xsel -i -b";
    };

    sessionPath = [
      "/home/bolt/.local/bin"
      "/home/bolt/.cabal/bin"
      "/home/bolt/.cargo/bin"
    ];

    keyboard = {
      layout = "us,pt";
      options = [
        "caps:escape"
        "grp:shifts_toggle"
      ];
    };
  };

  imports = [
    ./programs/agda/default.nix
    ./programs/bash/default.nix
    ./programs/emacs/default.nix
    ./programs/firefox/default.nix
    ./programs/git/default.nix
    ./programs/neovim/default.nix
    ./programs/waybar/default.nix
    ./programs/wofi/default.nix
    ./programs/sway/default.nix
    ./services/networkmanager/default.nix
    ./xdg/sway/default.nix
  ];

  # fonts
  fonts.fontconfig.enable = true;

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
      # sortDescending = true;
      # sortKey = "PERCENT_CPU";
    };

    ssh.enable = true;
  };

  services.lorri.enable = true;

}
