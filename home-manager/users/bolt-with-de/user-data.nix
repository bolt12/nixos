{ pkgs, config, lib, ... }:

# User-specific data for bolt-with-de (X1 Carbon laptop)
# Contains Syncthing configuration for syncing with ninho server
let
  # Define the ignore patterns in a "heredoc" string
  docsIgnorePatterns = pkgs.writeText "documents-stignore" ''
    // (?d) = allow Syncthing to delete ignored files when their parent
    // directory is removed on the remote side. Without this, directories
    // containing only ignored build artifacts can never be cleaned up,
    // causing perpetual "Failed to sync" warnings and a red tray icon.

    // --- Version control ---
    // Sync working trees only; use git push/pull for repo state
    (?d).git

    // --- General ---
    (?d).DS_Store
    (?d)Thumbs.db
    (?d)*~
    (?d)*.lock
    (?d).claude

    // --- C / C++ / CMake ---
    (?d)CMakeFiles
    (?d)CMakeCache.txt
    (?d)cmake_install.cmake
    (?d)Makefile
    (?d)*.a
    (?d)*.so
    (?d)*.dylib

    // --- Haskell (Cabal / Stack) ---
    (?d)dist-newstyle
    (?d).stack-work
    (?d)cabal.sandbox.config
    (?d).cabal-sandbox
    (?d)*.o
    (?d)*.hi
    (?d)*.chi
    (?d)*.chs.h
    (?d)*.dyn_o
    (?d)*.dyn_hi

    // --- Agda ---
    (?d)*.agdai
    (?d)MAlonzo

    // --- Lean ---
    (?d).lake
    (?d)lake-packages
    (?d)build/bin
    (?d)build/ir
    (?d)build/lib

    // --- Java ---
    (?d)*.class
    (?d).gradle
    (?d).settings
    (?d).classpath
    (?d).project
    (?d)target

    // --- JS / Node ---
    (?d)node_modules
    (?d).next
    (?d).nuxt
    (?d).parcel-cache
    (?d).turbo
    (?d).angular
    (?d)bower_components

    // --- Nix ---
    (?d)result
    (?d)result-*
    (?d).direnv

    // --- Chrome extensions ---
    (?d).chrome-profile

    // --- IDE / editor ---
    (?d).idea
    (?d).vscode
    (?d)*.swp
    (?d)*.swo

    // --- Generated output ---
    (?d)Bolt/Playground/Haskell/generative-art/showcases
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
