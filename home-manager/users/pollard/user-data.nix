{ config, ... }:

# User-specific data for pollard
# Contains ZFS learning aliases and helpful shortcuts
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
  home.file."x1-g8-laptop/Desktop/.stignore" = {
    source = docsIgnorePatterns;
  };

  userConfig.bash.extraAliases = {
    # NixOS help shortcuts
    nix-help = "man configuration.nix";
    nix-search = "nix search nixpkgs";
    nix-info = "nix-shell -p nix-info --run nix-info";
    hm-help = "man home-configuration.nix";
  };

  # Syncthing configuration for ninho server
  # services.syncthing = {
  #   overrideDevices = true;
  #   overrideFolders = true;

  #   guiAddress = "0.0.0.0:8384";

  #   settings = {
  #     devices = {
  #       "pollard-laptop" = {
  #         id = ""; # Need to fetch the ID from the GUI
  #       };
  #     };

  #     folders = {
  #       "folder-id" = {
  #         path = "${config.userConfig.homeDirectory}/Documents";
  #         devices = [ "pollard-laptop" ];
  #       };
  #     };
  #   };
  # };
}
