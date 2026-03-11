{ pkgs, config, ... }:

# User-specific data for bolt
# Contains personal aliases, directory shortcuts, and Syncthing configuration

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
  home.file."x1-g8-laptop/Desktop/.stignore" = {
    source = docsIgnorePatterns;
  };

  userConfig.bash.extraAliases = {
    # Project directories
    uminho    = "cd ${config.userConfig.homeDirectory}/x1-g8-laptop/Desktop/Bolt/UMinho/";
    tese      = "cd ${config.userConfig.homeDirectory}/x1-g8-laptop/Desktop/Bolt/UMinho/5ºAno/Tese";
    haskell   = "cd ${config.userConfig.homeDirectory}/x1-g8-laptop/Desktop/Bolt/Playground/Haskell/";
    talks     = "cd ${config.userConfig.homeDirectory}/x1-g8-laptop/Desktop/Bolt/Playground/Talks/";
    agdacd    = "cd ${config.userConfig.homeDirectory}/x1-g8-laptop/Desktop/Bolt/Playground/Agda/";
    playg     = "cd ${config.userConfig.homeDirectory}/x1-g8-laptop/Desktop/Bolt/Playground/";

    # Work directories
    welltyped = "cd ${config.userConfig.homeDirectory}/x1-g8-laptop/Desktop/Bolt/UMinho/Profissional/Well-Typed/";
    iohk      = "cd ${config.userConfig.homeDirectory}/x1-g8-laptop/Desktop/Bolt/UMinho/Profissional/Well-Typed/Projects/IOHK";
    hsbindgen = "cd ${config.userConfig.homeDirectory}/x1-g8-laptop/Desktop/Bolt/UMinho/Profissional/Well-Typed/Projects/hs-bindgen";

    # Tool shortcuts
    doom = "${config.userConfig.homeDirectory}/.emacs.d/bin/doom";

    # NixOS rebuild
    nrs = "nixos-rebuild-safe";
  };

  # Syncthing configuration for ninho server
  # Note: This is only used when bolt/home.nix is loaded directly on ninho
  # When bolt-with-de imports this file, the laptop's user-data.nix overrides this
  services.syncthing = {
    overrideDevices = true;
    overrideFolders = true;

    guiAddress = "0.0.0.0:8384";

    settings = {
      devices = {
        "x1-g8-laptop" = {
          id = "OZ4BCQS-3HVVW2H-RSOS7MV-EHDC2HY-I42ZTYP-K2EWHTS-PHPOHKK-7MZL6Q5";
        };
      };

      folders = {
        "x1-laptop-desktop-folder" = {
          path = "${config.userConfig.homeDirectory}/x1-g8-laptop/Desktop";
          devices = [ "x1-g8-laptop" ];
        };
      };
    };
  };
}
