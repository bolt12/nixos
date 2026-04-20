{ config, pkgs, constants, ... }:
let
  inherit (constants) network ports storage;
  nextcloudHostname = "nextcloud.${network.ninho.hostname}";
  nextcloudHome = "${storage.data}/nextcloud";
in
{
  # Configure Nginx to listen on all interfaces
  services.nginx.virtualHosts."${nextcloudHostname}" = {
    # Listen on all interfaces (0.0.0.0)
    listen = [
      { addr = "0.0.0.0"; port = ports.nextcloud; }
      { addr = "[::]"; port = ports.nextcloud; }  # IPv6 support
    ];

    # Disable SSL (internal network access only)
    forceSSL = false;
    enableACME = false;
  };

  services.nextcloud = {
    enable = true;
    hostName = nextcloudHostname;
    home = nextcloudHome;
    package = pkgs.nextcloud32;

    database.createLocally = true;
    configureRedis = true;

    # Increase the maximum file upload size to avoid problems uploading videos.
    maxUploadSize = "16G";
    https = false;

    autoUpdateApps.enable = true;
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
        notes
        notify_push
        polls
        richdocuments
        tasks
        cospend
        ;
    };

    config = {
      dbtype = "pgsql";  # Auto-creates database
      adminuser = "admin";
      adminpassFile = "${nextcloudHome}/admin-password";
    };

    settings = {
      overwriteprotocol = "http";
      default_phone_region = "PT";
      trusted_proxies = [ "127.0.0.1" ];
      trusted_domains = [ network.ninho.vpnIp ];
    };
  };

  # Create admin password file
  # TODO: Move to secret management (user will handle separately)
  systemd.tmpfiles.rules = [
    "f ${nextcloudHome}/admin-password 0600 nextcloud nextcloud - 'ChangeMe123!'"
  ];
}
