{ pkgs, lib, inputs, ... }:

let

  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs) system;
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

  agdaStdlibSrc = pkgs.fetchFromGitHub {
      owner = "agda";
      repo = "agda-stdlib";
      rev = "v2.0";
      sha256 = "sha256-TjGvY3eqpF+DDwatT7A78flyPcTkcLHQ1xcg+MKgCoE="; # Replace with the correct hash
    };

  nixops = inputs.nixops.defaultPackage.${pkgs.system};

  # Unstable branch packages
  unstablePkgs = [
    (unstable.agda.withPackages (p: [
      (p.standard-library.overrideAttrs (oldAttrs: {
        version = "v2.0";
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
    chromium                     # google chrome
    deluge                       # torrent client
    dig                          # dns tool
    discord                      # discord client
    evince                       # pdf reader
    fd                           # file finder
    feh                          # image viewer
    ffmpeg_5-full                # A complete, cross-platform solution to record, convert and stream audio and video
    findutils                    # find files utilities
    fzf                          # fuzzy finder
    gawk                         # text processing programming language
    gh                           # Github CLI
    git-absorb                   # git commit --fixup, but automatic
    git-annex                    # git annex
    git-extras                   # git extra commands like 'git sed'
    glib                         # gsettings
    google-chrome                # A freeware web browser developed by Google
    gsettings-desktop-schemas    # theming related
    gtk3                         # gtk3 lib
    gtk-engine-murrine           # theme engine
    gtk_engines                  # theme engines
    helvum                       # sound
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
    silicon                      # create beautiful code imgs
    simplescreenrecorder         # self-explanatory
    skypeforlinux                # skype for linux
    slack                        # slack client
    sof-firmware                 # Sound Open Firmware
    spotify                      # spotify client
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

  gitPkgs = with pkgs.gitAndTools; [
    diff-so-fancy
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

    packages =
      defaultPkgs
      ++ extraPkgs
      ++ fontsPkgs
      ++ gitPkgs
      ++ haskellPkgs
      ++ unstablePkgs;

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

