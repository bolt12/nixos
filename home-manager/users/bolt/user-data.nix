{ config, ... }:

# User-specific data for bolt
# Contains personal aliases, directory shortcuts, and Syncthing configuration

{
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

    settings = {
      # devices = {
      #   "x1-g8-laptop" = {
      #     id = "OZ4BCQS-3HVVW2H-RSOS7MV-EHDC2HY-I42ZTYP-K2EWHTS-PHPOHKK-7MZL6Q5"; # Fill with device ID from x1 laptop after first connection
      #   };
      # };

      # folders = {
      #   "x1-laptop-sync" = {
      #     path = "${config.userConfig.homeDirectory}/X1-G8-Laptop";
      #     devices = [ "x1-g8-laptop" ];
      #     versioning = {
      #       type = "simple";
      #       params = {
      #         keep = "10";  # Keep 10 versions of each file
      #       };
      #     };
      #   };
      # };

    };
  };
}
