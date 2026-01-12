{ config, pkgs, lib, ... }:
let
  constants = import ../../../common/constants.nix { inherit lib; };
in
{
  # Miniflux RSS reader
  services.miniflux = {
    enable = true;

    # Admin credentials - create this file with:
    # echo "ADMIN_USERNAME=admin" > /var/lib/miniflux/admin-credentials
    # echo "ADMIN_PASSWORD=your-password-here" >> /var/lib/miniflux/admin-credentials
    # chmod 600 /var/lib/miniflux/admin-credentials
    adminCredentialsFile = "/var/lib/miniflux/admin-credentials";

    config = {
      # Listen on all interfaces
      LISTEN_ADDR = "0.0.0.0:${toString constants.ports.miniflux}";

      # Database will be created automatically
      DATABASE_URL = "user=miniflux host=/run/postgresql dbname=miniflux";

      # Optional: Cleanup old entries after 60 days
      CLEANUP_ARCHIVE_READ_DAYS = "60";
    };
  };

  # PostgreSQL setup for miniflux
  services.postgresql = {
    ensureDatabases = [ "miniflux" ];
    ensureUsers = [
      {
        name = "miniflux";
        ensureDBOwnership = true;
      }
    ];
  };

  # Open firewall for miniflux
  networking.firewall.allowedTCPPorts = [ constants.ports.miniflux ];
}
