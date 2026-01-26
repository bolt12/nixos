{ config, pkgs, lib, constants, ... }:
let
  inherit (constants) ports storage;
  kavitaHome = "${storage.data}/kavita";
in
{
  services.kavita = {
    enable = true;
    package = pkgs.unstable.kavita;
    dataDir = kavitaHome;

    # TokenKey is required - must be 512+ bits (64+ characters)
    # Generate with: head -c 64 /dev/urandom | base64 | head -c 64
    tokenKeyFile = "${kavitaHome}/token-key";

    settings = {
      # Port configuration
      Port = ports.kavita;

      # IP binding
      IpAddresses = "0.0.0.0";
    };
  };

  # Create data directories
  systemd.tmpfiles.rules = [
    "d ${kavitaHome} 0750 kavita kavita - -"
    "d ${kavitaHome}/config 0750 kavita kavita - -"
  ];

  # Grant read access to media folder (for ebooks)
  users.users.kavita.extraGroups = [ "media" "storage-users" ];

  # Open firewall
  networking.firewall.allowedTCPPorts = [ ports.kavita ];
}
