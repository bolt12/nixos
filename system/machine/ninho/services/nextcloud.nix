{ config, pkgs, ... }:
{
  services.nextcloud = {
    enable = true;
    hostName = "nextcloud.ninho.local";  # Domain for Nextcloud
    home = "/storage/data/nextcloud";
    package = pkgs.nextcloud32;

    database.createLocally = true;
    configureRedis = true;

    # Increase the maximum file upload size to avoid problems uploading videos.
    maxUploadSize = "16G";
    https = true;
    enableBrokenCiphersForSSE = false;

    appstoreEnable = true;
    extraAppsEnable = true;
    extraApps = with config.services.nextcloud.package.packages.apps; {
      # List of apps we want to install and are already packaged in
      # https://github.com/NixOS/nixpkgs/blob/master/pkgs/servers/nextcloud/packages/nextcloud-apps.json
      inherit
        bookmarks
        calendar
        collectives
        contacts
        deck
        forms
        groupfolders
        mail
        notes
        notify_push
        polls
        richdocuments
        tasks
        whiteboard

        # Custom app installation example.
        # cookbook = pkgs.fetchNextcloudApp rec {
        #   url =
        #     "https://github.com/nextcloud/cookbook/releases/download/v0.10.2/Cookbook-0.10.2.tar.gz";
        #   sha256 = "sha256-XgBwUr26qW6wvqhrnhhhhcN4wkI+eXDHnNSm1HDbP6M=";
        # };
        ;
    };

    config = {
      dbtype = "pgsql";  # Auto-creates database
      overwriteProtocol = "https";
      defaultPhoneRegion = "PT";
      adminuser = "admin";
      adminpassFile = "/storage/data/nextcloud/admin-password";
    };

    settings = {
      overwriteprotocol = "https";
      trusted_proxies = [ "127.0.0.1" ];  # Trust Caddy
    };
  };

  services.onlyoffice = {
    enable = true;
    hostname = "onlyoffice.ninho.local";
  };

  # Create admin password file
  systemd.tmpfiles.rules = [
    "f /storage/data/nextcloud/admin-password 0600 nextcloud nextcloud - 'ChangeMe123!'"
  ];

  # Allow reading Immich photos (for integration)
  users.users.nextcloud.extraGroups = [ "media" ];
}
