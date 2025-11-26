{ config, ... }:

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

    // --- Git ---
    // Only ignore the .git folder at the root of a repo, not the files inside
    .git/

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

  # Syncthing configuration for X1 laptop
  services.syncthing = {
    overrideDevices = true;
    overrideFolders = true;

    tray.enable = true;

    settings = {
      devices = {
        "ninho-server" = {
          id = "REX7TVF-RYLC5YI-HS23IDX-XIXTH7Y-5ETUCHQ-4PHPOC4-RIUYV75-L4UXFAN"; # Fill with device ID from ninho server after first connection
          autoAcceptFolders = true; # Optional: auto-accept new folders from this device
        };
      };

      folders = {
        "x1-laptop-desktop-folder" = {
          path = "${config.userConfig.homeDirectory}/Desktop";
          devices = [ "ninho-server" ];
          };
        # TODO: Figure out what to do with this folder and immich.
        # "x1-laptop-documents-folder" = {
        #   path = "${config.userConfig.homeDirectory}/Documents/OsmoAction";
        #   devices = [ "ninho-server" ];
        #   };
        # };
      };
    };
  };
}
