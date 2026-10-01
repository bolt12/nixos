# Miniflux RSS reader, backed by the shared PostgreSQL in databases.nix.
{
  config,
  pkgs,
  lib,
  constants,
  ...
}:
{
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

      # Allow fetching from LAN/Tailscale addresses (RSS-Bridge on this host)
      FETCHER_ALLOW_PRIVATE_NETWORKS = "1";

      # RSS-Bridge feeds can be large (full article HTML); default 15 MiB
      HTTP_CLIENT_MAX_BODY_SIZE = "50";
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
