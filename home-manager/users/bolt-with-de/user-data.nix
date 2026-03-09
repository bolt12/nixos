{ pkgs, config, lib, ... }:

# User-specific data for bolt-with-de (X1 Carbon laptop)
# Contains Syncthing configuration for syncing with ninho server
let
  # Define the ignore patterns in a "heredoc" string
  docsIgnorePatterns = pkgs.writeText "documents-stignore" ''
    // --- Version control ---
    // Sync working trees only; use git push/pull for repo state
    .git

    // --- General ---
    .DS_Store
    Thumbs.db
    *~
    *.lock
    .claude

    // --- Haskell (Cabal / Stack) ---
    dist-newstyle
    .stack-work
    cabal.sandbox.config
    .cabal-sandbox
    *.o
    *.hi
    *.chi
    *.chs.h
    *.dyn_o
    *.dyn_hi

    // --- Agda ---
    *.agdai
    MAlonzo

    // --- Lean ---
    .lake
    lake-packages
    build/bin
    build/ir
    build/lib

    // --- Java ---
    *.class
    .gradle
    .settings
    .classpath
    .project
    target

    // --- JS / Node ---
    node_modules
    .next
    .nuxt
    .parcel-cache
    .turbo
    .angular
    bower_components

    // --- Nix ---
    result
    result-*
    .direnv

    // --- Chrome extensions ---
    .chrome-profile

    // --- IDE / editor ---
    .idea
    .vscode
    *.swp
    *.swo

    // --- Generated output ---
    Bolt/Playground/Haskell/generative-art/showcases
  '';
in
{
  # This places the file at ~/Documents/.stignore
  # Syncthing will read this file to know what to skip.
  home.file."Desktop/.stignore" = {
    source = docsIgnorePatterns;
  };

  userConfig.bash.extraAliases = lib.mkForce {
    # Project directories
    uminho    = "cd ${config.userConfig.homeDirectory}/Desktop/Bolt/UMinho/";
    tese      = "cd ${config.userConfig.homeDirectory}/Desktop/Bolt/UMinho/5ºAno/Tese";
    haskell   = "cd ${config.userConfig.homeDirectory}/Desktop/Bolt/Playground/Haskell/";
    talks     = "cd ${config.userConfig.homeDirectory}/Desktop/Bolt/Playground/Talks/";
    agdacd    = "cd ${config.userConfig.homeDirectory}/Desktop/Bolt/Playground/Agda/";
    playg     = "cd ${config.userConfig.homeDirectory}/Desktop/Bolt/Playground/";

    # Work directories
    welltyped = "cd ${config.userConfig.homeDirectory}/Desktop/Bolt/UMinho/Profissional/Well-Typed/";
    iohk      = "cd ${config.userConfig.homeDirectory}/Desktop/Bolt/UMinho/Profissional/Well-Typed/Projects/IOHK";
    hsbindgen = "cd ${config.userConfig.homeDirectory}/Desktop/Bolt/UMinho/Profissional/Well-Typed/Projects/hs-bindgen";

    # Tool shortcuts
    doom = "${config.userConfig.homeDirectory}/.emacs.d/bin/doom";
  };

  # Syncthing configuration for X1 laptop
  # This overrides the base bolt configuration from bolt/user-data.nix
  services.syncthing = {
    overrideDevices = true;
    overrideFolders = true;

    tray.enable = true;

    settings = {
      devices = lib.mkForce {
        "ninho-server" = {
          id = "REX7TVF-RYLC5YI-HS23IDX-XIXTH7Y-5ETUCHQ-4PHPOC4-RIUYV75-L4UXFAN";
          autoAcceptFolders = true;
        };
      };

      folders = lib.mkForce {
        "x1-laptop-desktop-folder" = {
          path = "${config.userConfig.homeDirectory}/Desktop";
          devices = [ "ninho-server" ];
        };
      };
    };
  };
}
