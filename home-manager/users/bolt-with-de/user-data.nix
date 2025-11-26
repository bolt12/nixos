{ pkgs, config, lib, ... }:

# User-specific data for bolt-with-de (X1 Carbon laptop)
# Contains Syncthing configuration for syncing with ninho server
let
  # Define the ignore patterns in a "heredoc" string
  docsIgnorePatterns = pkgs.writeText "documents-stignore" ''
    // --- Ignore the dedicated directories ---
    Bolt/Playground
    Bolt/UMinho/Profissional/Well-Typed/Projects

    // --- General ---
    .DS_Store
    Thumbs.db
    *~
    *.lock

    // --- Haskell (Cabal / Stack) ---
    dist/
    dist-newstyle/
    .stack-work/
    cabal.sandbox.config
    .cabal-sandbox/
    *.o
    *.hi
    *.chi
    *.dyn_o
    *.dyn_hi

    // --- Nix ---
    // 'result' symlinks created by nix build
    result
    result-*
    // Environment variables managed by direnv
    .direnv/
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
