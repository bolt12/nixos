{ config, ... }:

# User-specific data for bolt-with-de (X1 Carbon laptop)
# Contains Syncthing configuration for syncing with ninho server

{
  # Syncthing configuration for X1 laptop
  services.syncthing = {
    overrideDevices = true;
    overrideFolders = true;

    tray.enable = true;

    settings = {
      # devices = {
      #   "ninho-server" = {
      #     id = ""; # Fill with device ID from ninho server after first connection
      #   };
      # };

      # folders = {
      #   "laptop-to-ninho" = {
      #     path = "${config.userConfig.homeDirectory}/Documents";
      #     devices = [ "ninho-server" ];
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
