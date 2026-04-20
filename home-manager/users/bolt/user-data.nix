{ pkgs, config, ... }:

# User-specific data for bolt
# Contains personal aliases, directory shortcuts, and Syncthing configuration

let
  docsIgnorePatterns = import ../../common/syncthing-ignores.nix { inherit pkgs; };
  projectAliases = import ../../common/project-aliases.nix {
    desktopPrefix = "x1-g8-laptop/Desktop";
    homeDirectory = config.userConfig.homeDirectory;
  };
in
{
  # This places the file at ~/Documents/.stignore
  # Syncthing will read this file to know what to skip.
  home.file."x1-g8-laptop/Desktop/.stignore" = {
    source = docsIgnorePatterns;
  };

  userConfig.bash.extraAliases = projectAliases // {
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
