{ config, lib, stdenv, sources ? (import ./nix/sources.nix), ... }:

let

  unstable = import sources.nixpkgs-unstable {
    overlays = [
    ];
  };

  sources = import ./nix/sources.nix;

  pkgs = import sources.nixpkgs {
    overlays = [
      (import sources.neovim-nightly-overlay)
    ];
    config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) unfreePackages;
    config.permittedInsecurePackages = [ "python2.7-pyjwt-1.7.1"
                                         "python2.7-certifi-2021.10.8"
                                         "python-2.7.18.6"
                                         "openssl-1.1.1u"
                                       ];
  };

  unfreePackages = [
    "vscode"
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
    (unstable.agda.withPackages (p: [
      (p.standard-library.overrideAttrs (oldAttrs: {
        version = "local version";
        src = /home/bolt/Desktop/Bolt/Playground/Agda/agda-stdlib;
      }))
    ]))
  ];

  # Extra packages from user repos
  extraPkgs = [
  ];

  defaultPkgs = with pkgs; [
    alloy                        # model checker
    alsa-utils                   # sound utils
    awscli2                      # aws cli v2
    bash                         # bash
    bc                           # gnu calculator
    blueman                      # bluetooth applet
    cachix                       # nix caching
    cage                         # Wayland kiosk compositor
    chromium                     # google chrome
    deluge                       # torrent client
    discord                      # discord client
    evince                       # pdf reader
    fd                           # file finder
    feh                          # image viewer
    firefox                      # internet browser
    flashfocus                   # focus wm
    fzf                          # fuzzy finder
    gawk                         # text processing programming language
    git-extras                   # git extra commands like 'git sed'
    git-annex                    # git annex
    glib                         # gsettings
    gsettings-desktop-schemas    # theming related
    gtk3                         # gtk3 lib
    gtk-engine-murrine           # theme engine
    gtk_engines                  # theme engines
    greetd.gtkgreet              # a gtk based greeter for greetd
    jdk                          # java development kit
    jq                           # JSON processor
    jre                          # java runtime environment
    imv                          # image viewer
    killall                      # kill processes by name
    konsole                      # terminal emulator
    libreoffice                  # office suite
    lsof                         # A tool to list open files
    lxappearance                 # edit themes
    lxmenu-data                  # desktop menus - enables "open with" options
    manix                        # nix manual
    mpv                          # video player
    ncdu                         # disk space info (a better du)
    neofetch                     # command-line system information
    networkmanagerapplet         # nm-applet
    (import sources.niv {}).niv  # dependency management for nix
    nix-doc                      # nix documentation search tool
    nix-index                    # nix locate files
    nixops                       # nixops
    nodejs                       # nodejs
    noip                         # noip
    numix-icon-theme-circle      # icon theme
    numix-cursor-theme           # icon theme
    obs-studio                   # obs-studio
    obs-studio-plugins.wlrobs    # obs wayland protocol
    pamixer                      # pulseaudio cli mixer
    patchelf                     # dynamic linker and RPATH of ELF executables
    pavucontrol                  # pulseaudio volume control
    paprefs                      # pulseaudio preferences
    pasystray                    # pulseaudio systray
    pcmanfm                      # file manager
    playerctl                    # music player controller
    psensor                      # hardware monitoring
    pulsemixer                   # pulseaudio mixer
    python3                      # python3 programming language
    ripgrep                      # ripgrep
    rnix-lsp                     # nix lsp server
    silicon                      # create beautiful code imgs
    simplescreenrecorder         # self-explanatory
    shared-mime-info             # A database of common MIME types
    skypeforlinux                # skype for linux
    slack                        # slack client
    spotify                      # spotify client
    thunderbird-wayland          # mail client
    tldr                         # summary of a man page
    tree                         # display files in a tree view
    texlive.combined.scheme-full # latex
    unzip                        # unzip
    vlc                          # media player
    vscode                       # visual studio code
    xarchiver                    # xarchiver gtk frontend
    xclip                        # clipboard support (also for neovim)
    xorg.xmodmap                 # Keyboard
    xsettingsd                   # theming
    weechat                      # weechat irc client
    wireguard-tools              # wireguard
    wget                         # cli wget
    zip                          # zip
    zlib                         # zlib
    zk                           # zettelkasten note taking
    zoom                         # video conferencing
  ];

  # Wayland Packages
  waylandPkgs = [
    unstable.grim
    unstable.slurp
    unstable.swaylock-fancy
    unstable.wofi
    unstable.wlsunset
    unstable.xdg-desktop-portal
    unstable.xdg-desktop-portal-wlr
    unstable.xdg-desktop-portal-gtk
    unstable.wlogout
    unstable.pipewire
    unstable.wireplumber
    unstable.wl-gammactl
    unstable.brightnessctl
    unstable.wl-clipboard
    unstable.mako
    unstable.swayidle
    unstable.wlroots
    unstable.wayland-protocols
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
    (pkgs.haskell-language-server.override
      { supportedGhcVersions =
        [ "8107"
          "902"
        ];
      })
  ];

  fontsPkgs = [
    (pkgs.nerdfonts.override {
      fonts = [
        "JetBrainsMono"
        "FiraCode"
      ];
    })
    pkgs.font-awesome
    pkgs.ubuntu_font_family
    pkgs.emojione
    pkgs.noto-fonts
    pkgs.noto-fonts-cjk
    pkgs.noto-fonts-extra
    pkgs.hack-font
    pkgs.inconsolata
    pkgs.material-icons
    pkgs.liberation_ttf
    pkgs.dejavu_fonts
    pkgs.terminus_font
    pkgs.siji
    pkgs.unifont
    pkgs.open-sans
    pkgs.open-dyslexic
    pkgs.xits-math
  ];

in
{
  home = {
    enableNixpkgsReleaseCheck = true;

    username      = "bolt";
    homeDirectory = "/home/bolt";
    stateVersion  = "23.05";

    keyboard = {
      layout = "us,pt";
      options = [
        "caps:escape"
        "grp:shifts_toggle"
      ];
    };

    packages =
      defaultPkgs
      ++ waylandPkgs
      ++ gitPkgs
      ++ gnomePkgs
      ++ haskellPkgs
      ++ fontsPkgs
      ++ unstablePkgs
      ++ extraPkgs;

    sessionVariables = {
      MOZ_DISABLE_RDD_SANDBOX="1";
      MOZ_ENABLE_WAYLAND="1";
      XDG_CURRENT_DESKTOP="sway";
      XDG_SESSION_TYPE="wayland";
      SDL_VIDEODRIVER="wayland";
      QT_QPA_PLATFORM="wayland";
      QT_WAYLAND_DISABLE_WINDOWDECORATION="1";
      ECORE_EVAS_ENGINE="wayland_egl";
      ELM_ENGINE="wayland_egl";
      EDITOR="nvim";
      VISUAL="nvim";
      NIXOS_OZONE_WL="1";
    };

    sessionPath = [
      "/home/bolt/.local/bin"
      "/home/bolt/.cabal/bin"
      "/home/bolt/.cargo/bin"
    ];

  };

  imports = [
    ./programs/agda/default.nix
    ./programs/bash/default.nix
    ./programs/emacs/default.nix
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

  # If a program requires to many options or something custom it might be better to
  # extract it into a different file
  programs = {

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

    gpg.enable = true;

    home-manager.enable = true;

    htop = {
      enable = true;
      # sortDescending = true;
      # sortKey = "PERCENT_CPU";
    };

    ssh.enable = true;

    atuin = {
      enable = true;
      enableBashIntegration = true;
    };

    autorandr.enable = true;
  };

  services = {
    lorri.enable = true;
    blueman-applet.enable = true;
    udiskie.enable = true;
    wlsunset = {
      enable = true;
      latitude = "39" ;
      longitude = "-8" ;
    };
    swayidle.enable = true;
    poweralertd.enable = true;
    autorandr.enable = true;
  };

}
