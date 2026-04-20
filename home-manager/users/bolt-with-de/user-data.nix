{ pkgs, config, lib, constants, ... }:

# User-specific data for bolt-with-de (X1 Carbon laptop)
# Contains Syncthing configuration for syncing with ninho server
let
  docsIgnorePatterns = import ../../common/syncthing-ignores.nix { inherit pkgs; };
  projectAliases = import ../../common/project-aliases.nix {
    desktopPrefix = "Desktop";
    homeDirectory = config.userConfig.homeDirectory;
  };
in
{
  # This places the file at ~/Documents/.stignore
  # Syncthing will read this file to know what to skip.
  home.file."Desktop/.stignore" = {
    source = docsIgnorePatterns;
  };

  # mkForce because bolt/user-data.nix (imported via bolt/home.nix) sets this
  # with the ninho-side desktop prefix; the laptop needs the rooted prefix.
  userConfig.bash.extraAliases = lib.mkForce (projectAliases // {
    # WireGuard endpoint toggle — skip MEO hairpin NAT when on home LAN
    vpn-home = "sudo wg set ${constants.network.wireguard.interface} peer ${constants.network.wireguard.rpiServerPubKey} endpoint ${constants.network.rpi.lanIp}:${toString constants.network.wireguard.port}";
    vpn-away = "sudo wg set ${constants.network.wireguard.interface} peer ${constants.network.wireguard.rpiServerPubKey} endpoint ${constants.network.rpi.hostname}:${toString constants.network.wireguard.port}";
  });

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
