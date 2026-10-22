# OwnTracks: location history posted by the phone app, kept on ninho.
# https://github.com/owntracks/recorder and https://github.com/owntracks/frontend
#
# The Android app runs in HTTP mode and posts every fix to /pub. nginx checks
# basic auth and hands the post to ot-recorder, which appends it under
# store/rec/<user>/<device>/. The same vhost serves owntracks-frontend, a map
# that reads the recorder's /api and /ws on the same origin.
#
# The recorder has no authentication of its own, and it takes the user name
# from `?u=` or the X-Limit-U header, both of which the client sets. So it binds
# to loopback, and nginx overwrites X-Limit-U on /pub with the user that logged
# in: a valid login cannot write into someone else's history.
#
# Unlike most services here, the port stays closed in the firewall. The vhost
# answers over the tailnet (tailscale0 is trusted) and on localhost for the
# blackbox probe, and the LAN gets nothing. The phone needs Tailscale up to
# post; the app queues fixes until it is.
#
# --norevgeo: no addresses. Without a geocoder key the recorder would still
# cache an empty answer for each new ~150 m cell, and those entries never
# expire, so adding a key later would leave every visited place unresolved.
# To turn geocoding on, drop the flag and pass --geokey together.
#
# owntracks-init generates the password for `bolt` on first start. To add a
# user, append `name:$(openssl passwd -6)` to the htpasswd file.
{
  config,
  lib,
  pkgs,
  constants,
  ...
}:
let
  inherit (constants) storage ports;
  dataDir = "${storage.data}/owntracks";
  storeDir = "${dataDir}/store";
  htpasswd = "${dataDir}/htpasswd";
  nginxGroup = config.services.nginx.group;
  recorderUrl = "http://127.0.0.1:${toString ports.owntracks-recorder}";
  otRecorder = "${pkgs.owntracks-recorder}/bin/ot-recorder";
in
{
  users.users.owntracks = {
    isSystemUser = true;
    group = "owntracks";
  };
  users.groups.owntracks = { };

  # Traverse-only, so that nginx (the htpasswd) and the recorder (the store)
  # can both get through to their own files. Group-owning this by nginx would
  # lock the recorder out of its store; the files keep their own modes.
  systemd.tmpfiles.rules = [
    "d ${dataDir} 0711 root root - -"
    "d ${storeDir} 0700 owntracks owntracks - -"
  ];

  # The plaintext copy is for typing into the app once; `sudo cat` it.
  # The hash goes through a temporary file so that a run cut short leaves no
  # htpasswd behind, and the next start tries again.
  systemd.services.owntracks-init = {
    description = "OwnTracks: basic-auth password for the phone";
    wantedBy = [ "multi-user.target" ];
    before = [ "nginx.service" ];
    path = [ pkgs.openssl ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      if [ ! -f ${htpasswd} ]; then
        umask 077
        password=$(openssl rand -hex 16)
        printf '%s\n' "$password" > ${dataDir}/bolt.password
        printf 'bolt:%s\n' "$(printf '%s' "$password" | openssl passwd -6 -stdin)" > ${htpasswd}.tmp
        chgrp ${nginxGroup} ${htpasswd}.tmp
        chmod 0640 ${htpasswd}.tmp
        mv ${htpasswd}.tmp ${htpasswd}
      fi
    '';
  };

  systemd.services.owntracks-recorder = {
    description = "OwnTracks recorder (HTTP mode)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      User = "owntracks";
      Group = "owntracks";
      # Creates the LMDB databases when missing; existing data is left alone.
      ExecStartPre = "${otRecorder} --storage ${storeDir} --initialize";
      ExecStart = lib.concatStringsSep " " [
        otRecorder
        "--storage ${storeDir}"
        "--port 0" # no MQTT
        "--http-host 127.0.0.1"
        "--http-port ${toString ports.owntracks-recorder}"
        "--norevgeo"
        "--quiet" # otherwise every fix is echoed into the journal
      ];
      Restart = "on-failure";
      ProtectSystem = "strict";
      ReadWritePaths = [ storeDir ];
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };

  services.nginx = {
    enable = true;
    virtualHosts.owntracks = {
      listen = [
        {
          addr = "0.0.0.0";
          port = ports.owntracks;
        }
      ];
      root = "${pkgs.owntracks-frontend}/share/owntracks-frontend";
      basicAuthFile = htpasswd;
      locations = {
        "/api/".proxyPass = recorderUrl;
        "/ws" = {
          proxyPass = recorderUrl;
          proxyWebsockets = true;
        };
        "= /pub" = {
          proxyPass = recorderUrl;
          extraConfig = ''
            proxy_set_header X-Limit-U $remote_user;
          '';
        };
      };
    };
  };
}
