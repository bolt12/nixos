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
        onlyoffice
        cospend

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

  services.onlyoffice = {
    enable = true;
    # OnlyOffice needs a proper hostname internally (not an IP)
    # The nginx proxy below will handle IP-based access
    hostname = "onlyoffice.${network.ninho.hostname}";
    port = 8001;  # Internal port (not exposed)
    securityNonceFile = "${pkgs.writeText "nixos-test-onlyoffice-nonce.conf" ''
      set $secure_link_secret "ninho-nixos";
    ''}";
  };

  # Nginx reverse proxy for OnlyOffice IP-based access
  # Listens on port 8000 and proxies to OnlyOffice's internal port 8001
  services.nginx.virtualHosts."onlyoffice-ip-access" = {
    listen = [
      { addr = "0.0.0.0"; port = ports.onlyoffice; }
      { addr = "[::]"; port = ports.onlyoffice; }
    ];
    serverName = "_";  # Match any hostname (catch-all)

    locations."/" = {
      proxyPass = "http://127.0.0.1:8001";
      extraConfig = ''
        proxy_set_header Host onlyoffice.${network.ninho.hostname};
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
      '';
    };
  };

  # Create admin password file
  # TODO: Move to secret management (user will handle separately)
  systemd.tmpfiles.rules = [
    "f ${nextcloudHome}/admin-password 0600 nextcloud nextcloud - 'ChangeMe123!'"
  ];
}
