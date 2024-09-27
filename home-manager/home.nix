{ lib, inputs, pkgs, system, ... }:

let

  unstable = import inputs.nixpkgs-unstable {
    inherit system;
    overlays = [
    ];
  };

  unfreePackages = [
    "discord"
    "faac" # part of zoom
    "google-chrome"
    "skypeforlinux"
    "slack"
    "spotify"
    "spotify-unwrapped"
    "steam"
    "steam-original"
    "unrar"
    "vscode"
    "zoom-us"
  ];

  nixops = inputs.nixops.defaultPackage.${system};

  agdaStdlibSrc = pkgs.fetchFromGitHub {
      owner = "agda";
      repo = "agda-stdlib";
      rev = "v2.1.1";
      sha256 = "sha256-TjGvY3eqpF+DDwatT7A78flyPcTkcLHQ1xcg+MKgCoE="; # Replace with the correct hash
    };

    luaWithPackages = pkgs.lua.withPackages (ps:
      with ps; [
        cjson
        luasocket
      ]);

  # Unstable branch packages
  unstablePkgs = [
    (pkgs.agda.withPackages (p: [
      (p.standard-library.overrideAttrs (oldAttrs: {
        version = "v2.1.1";
        src = agdaStdlibSrc;
      }))
    ]))

    unstable.nixd
  ];

  # Extra packages from user repos
  extraPkgs = [
  ];

  defaultPkgs = with pkgs; [
    alloy                        # model checker
    alsa-utils                   # sound utils
    anki                         # anki flashcards
    arduino                      # arduino toolkit
    awscli2                      # aws cli v2
    bash                         # bash
    bc                           # gnu calculator
    blueman                      # bluetooth applet
    cachix                       # nix caching
    cage                         # Wayland kiosk compositor
    chromium                     # google chrome
    deluge                       # torrent client
    dig                          # dns tool
    discord                      # discord client
    evince                       # pdf reader
    fd                           # file finder
    feh                          # image viewer
    ffmpeg_5-full                # A complete, cross-platform solution to record, convert and stream audio and video
    findutils                    # find files utilities
    flashfocus                   # focus wm
    fzf                          # fuzzy finder
    gawk                         # text processing programming language
    gh                           # Github CLI
    git-absorb                   # git commit --fixup, but automatic
    git-annex                    # git annex
    git-extras                   # git extra commands like 'git sed'
    glib                         # gsettings
    google-chrome                # A freeware web browser developed by Google
    greetd.gtkgreet              # a gtk based greeter for greetd
    gsettings-desktop-schemas    # theming related
    gtk3                         # gtk3 lib
    gtk-engine-murrine           # theme engine
    gtk_engines                  # theme engines
    helvum                       # sound
    home-manager                 # home-manager
    imv                          # image viewer
    jdk                          # java development kit
    jq                           # JSON processor
    jre                          # java runtime environment
    jujutsu                      # A Git-compatible DVCS that is both simple and powerful
    killall                      # kill processes by name
    konsole                      # terminal emulator
    libcamera                    # open source camera stack for linux
    libreoffice                  # office suite
    lm_sensors                   # CPU sensors
    lsof                         # A tool to list open files
    luaWithPackages              # Lua with packages
    lxappearance                 # edit themes
    lxmenu-data                  # desktop menus - enables "open with" options
    manix                        # nix manual
    mpv                          # video player
    ncdu                         # disk space info (a better du)
    neofetch                     # command-line system information
    networkmanagerapplet         # nm-applet
    nix-bash-completions         # nix bash completions
    nix-doc                      # nix documentation search tool
    nix-index                    # nix locate files
    nixops                       # nixops
    nix-tree                     # interactively browse a Nix store paths dependencies
    nmap                         # network map
    nodejs                       # nodejs
    noip                         # noip
    numix-cursor-theme           # icon theme
    numix-icon-theme-circle      # icon theme
    obs-studio                   # obs-studio
    obs-studio-plugins.wlrobs    # obs wayland protocol
    pamixer                      # pulseaudio cli mixer
    paprefs                      # pulseaudio preferences
    pasystray                    # pulseaudio systray
    patchelf                     # dynamic linker and RPATH of ELF executables
    pavucontrol                  # pulseaudio volume control
    pcmanfm                      # file manager
    playerctl                    # music player controller
    psensor                      # hardware monitoring
    pulsemixer                   # pulseaudio mixer
    python3                      # python3 programming language
    ripgrep                      # ripgrep
    # rnix-lsp                     # nix lsp server
    silicon                      # create beautiful code imgs
    simplescreenrecorder         # self-explanatory
    skypeforlinux                # skype for linux
    slack                        # slack client
    sof-firmware                 # Sound Open Firmware
    spotify                      # spotify client
    steam                        # game library
    thunderbird                  # mail client
    tldr                         # summary of a man page
    tree                         # display files in a tree view
    unzip                        # unzip
    vlc                          # media player
    vscode                       # visual studio code
    weechat                      # weechat irc client
    wget                         # cli wget
    wireguard-tools              # wireguard
    xarchiver                    # xarchiver gtk frontend
    xclip                        # clipboard support (also for neovim)
    xorg.xmodmap                 # Keyboard
    xsettingsd                   # theming
    zip                          # zip
    zk                           # zettelkasten note taking
    zlib                         # zlib
    zoom                         # video conferencing
  ];

  # Wayland Packages
  waylandPkgs = [
    unstable.brightnessctl
    unstable.grim
    unstable.mako
    unstable.pipewire
    unstable.slurp
    unstable.swayidle
    unstable.swaylock-fancy
    unstable.waybar
    unstable.wayland-protocols
    unstable.wdisplays
    unstable.wireplumber
    unstable.wl-clipboard
    unstable.wl-gammactl
    unstable.wlogout
    unstable.wlroots
    unstable.wlsunset
    unstable.wofi
    unstable.xdg-desktop-portal
    unstable.xdg-desktop-portal-gtk
    unstable.xdg-desktop-portal-wlr
    unstable.xdg-desktop-portal-gnome
  ];

  gitPkgs = with pkgs.gitAndTools; [
    diff-so-fancy
  ];

  gnomePkgs = with pkgs.gnome3; [
    gnome-calendar # calendar
    gnome-control-center
    gnome-power-manager
    gnome-weather
    zenity         # display dialogs
  ];

  haskellPkgs = [
    pkgs.cabal2nix                # convert cabal projects to nix
    pkgs.cabal-install            # package manager
    pkgs.haskellPackages.eventlog2html
    pkgs.haskellPackages.fast-tags
    pkgs.haskellPackages.fourmolu # code formatter
    pkgs.haskellPackages.ghc      # compiler
    pkgs.haskellPackages.ghcide   # compiler
    pkgs.haskellPackages.haskell-language-server
    pkgs.haskellPackages.hoogle   # documentation
    pkgs.stack                    # package manager
    pkgs.stylish-haskell          # code formatter
  ];

  fontsPkgs = [
    (pkgs.nerdfonts.override {
      fonts = [
        "JetBrainsMono"
        "FiraCode"
      ];
    })
    pkgs.dejavu_fonts
    pkgs.emojione
    pkgs.font-awesome
    pkgs.hack-font
    pkgs.inconsolata
    pkgs.liberation_ttf
    pkgs.material-icons
    pkgs.noto-fonts
    pkgs.noto-fonts-cjk
    pkgs.noto-fonts-extra
    pkgs.open-dyslexic
    pkgs.open-sans
    pkgs.siji
    pkgs.terminus_font
    pkgs.ubuntu_font_family
    pkgs.unifont
    pkgs.xits-math
  ];

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

    packages =
      defaultPkgs
      ++ extraPkgs
      ++ fontsPkgs
      ++ gitPkgs
      ++ gnomePkgs
      ++ haskellPkgs
      ++ unstablePkgs
      ++ waylandPkgs;

    sessionVariables = {
      ECORE_EVAS_ENGINE="wayland_egl";
      EDITOR="nvim";
      ELM_ENGINE="wayland_egl";
      MOZ_DISABLE_RDD_SANDBOX="1";
      MOZ_ENABLE_WAYLAND="1";
      NIXOS_OZONE_WL="1";
      QT_QPA_PLATFORM="wayland";
      QT_WAYLAND_DISABLE_WINDOWDECORATION="1";
      SDL_VIDEODRIVER="wayland";
      VISUAL="nvim";
      XDG_CURRENT_DESKTOP="sway";
      XDG_SESSION_TYPE="wayland";
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
    ./programs/sway/default.nix
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

    firefox.enable = true;

    jujutsu = {
      enable = true;
    };
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
