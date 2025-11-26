{ config, ... }:

# User-specific data for bolt
# Contains personal aliases, directory shortcuts, and Syncthing configuration

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

    // --- Git ---
    // Only ignore the .git folder at the root of a repo, not the files inside
    .git/

    // --- Claude ---
    // Only ignore the .git folder at the root of a repo, not the files inside
    .claude

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
  home.file."Documents/.stignore" = {
    source = docsIgnorePatterns;
  };

  userConfig.bash.extraAliases = {
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

  # Syncthing configuration for ninho server
  services.syncthing = {
    overrideDevices = true;
    overrideFolders = true;

    guiAddress = "0.0.0.0:8384"

    settings = {
      devices = {
        "x1-g8-laptop" = {
          id = "OZ4BCQS-3HVVW2H-RSOS7MV-EHDC2HY-I42ZTYP-K2EWHTS-PHPOHKK-7MZL6Q5"; # Fill with device ID from x1 laptop after first connection
        };
      };

      folders = {
        "x1-laptop-desktop-folder" = {
          path = "${config.userConfig.homeDirectory}/x1-g8-laptop/Desktop";
          devices = [ "x1-g8-laptop" ];
          };

        # TODO: Figure out what to do with this folder and immich.
        # "x1-laptop-documents-folder" = {
        #   path = "/storage/media/bolt/x1-g8-laptop";
        #   devices = [ "x1-g8-laptop" ];
        #   };
        # };
      };

    };
  };
}
