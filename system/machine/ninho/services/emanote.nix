{ config, pkgs, inputs, ... }:
let
  emanotePackage = inputs.emanote.packages.${pkgs.system}.default;
in
{
  systemd.services.emanote = {
    enable = true;
    description = "Emanote web server";
    after = [ "network.target" ];
    wantedBy = [ "default.target" ];

    serviceConfig = {
      Type = "simple";
      User = "bolt";
      Group = "users";

      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /home/bolt/journal";
      ExecStart = ''
        ${emanotePackage}/bin/emanote \
          --layers "/home/bolt/journal" \
          run --no-ws --host=127.0.0.1 --port=7000
      '';

      Restart = "always";
      RestartSec = "10";

      # Security hardening
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = "tmpfs";
      ReadWritePaths = [ "/home/bolt/journal" ];
      BindReadOnlyPaths = [ "/home/bolt/journal" ];
    };
  };
}
