{ config, pkgs, lib, ... }:
let
  constants = import ../../../common/constants.nix { inherit lib; };
in
{
  # Anki Sync Server - self-hosted flashcard syncing
  #
  # SETUP INSTRUCTIONS:
  # 1. After enabling this service, create users by running:
  #    anki-sync-server --add-user <username>
  #    (This will prompt for password)
  #
  # 2. On Anki clients, configure sync settings:
  #    - Open Anki preferences
  #    - Go to Syncing tab
  #    - Set custom sync server to: http://ninho.local:27701
  #    - Use the username/password created in step 1

  services.anki-sync-server = {
    enable = true;

    # Listen address and port
    address = "0.0.0.0";
    port = constants.ports.anki-sync-server;

    users = [
      { username = "bolt";
        password = "tlob";
      }
    ];

    # Open firewall
    openFirewall = true;
  };

  # Firewall configuration (redundant but explicit)
  networking.firewall.allowedTCPPorts = [ constants.ports.anki-sync-server ];
}
