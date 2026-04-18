{ pkgs, config, ... }:

# User-specific data for bolt
# Contains personal aliases, directory shortcuts, and Syncthing configuration

let
  docsIgnorePatterns = import ../../common/syncthing-ignores.nix { inherit pkgs; };
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

    # Run commands as pollard with access to her user session
    run-as-pollard = "sudo XDG_RUNTIME_DIR=/run/user/$(id -u pollard) -u pollard";
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
