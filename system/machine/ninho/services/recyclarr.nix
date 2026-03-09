{ config, pkgs, constants, ... }:

let
  inherit (constants) ports;

  recyclarrConfig = pkgs.writeText "recyclarr.yml" ''
    sonarr:
      main:
        base_url: http://host.docker.internal:${toString ports.sonarr}
        api_key: <SONARR_API_KEY>
        quality_definition:
          type: series
        quality_profiles:
          - name: WEB-1080p
            reset_unmatched_scores:
              enabled: true
        custom_formats:
          - trash_ids:
              # HDR Formats
              - 7878c33f1fca4bc0b1a202e22850e3ce  # DV HDR10Plus
              - 1f733af03141f068a540eec352589a89  # DV HLG
              - 27954b564a9a34a9ad73bf4a55271b2f  # DV SDR
              - 6d0d8de7b57e35518ac0308b0ddf404e  # DV
              - bb019e1cd00f304f80571c6c5cc7f4d3  # HDR10Plus
              - 3e2c4e748b64a1a1118e0ea3f4cf6875  # HDR
              - 3497f2e31f3c5f1cafab455ca56b8591  # HDR10
              - a3d82cbef5039f8d295478d28a887159  # HLG
              # Unwanted
              - 85c61753df5da1fb2aab6f2a47426b09  # BR-DISK
              - 9c11cd3f07101cdba90a2d81cf0e56b4  # LQ
              - 47435ece6b99a0b477caf360e79ba0bb  # x265 (HD)
              # Streaming Services
              - d660701077794679fd59e8bdf4ce3a29  # AMZN
              - f67c9ca88f463a48346062e8ad07713f  # ATVP
              - 36b72f59f4ea20aad9316f475f2d9fbb  # DCU
              - 89358767a60cc28783ab36b7f6716998  # DSNP
              - 7a235133c87f7da4c8571f0b3d3e2bb8  # HBO
              - a880d6abc21e7c16884f3ae393f84179  # HMAX
              - f6cce30f1733d5c8194222a7507f2571  # HULU
              - 0ac24a2a68a9700bcb7ece4e0c90f0ee  # iT
              - d34870697c9db575f17700212167be23  # NF
              - 1656adc6d7bb2c8cca6acfb6592db421  # PCOK
              - c67a75ae4a1715f2bb4d492571c9571f  # PMTP
              - 3ac5d84fce98bab1b531393e9c82f467  # QIBI
              - ae58039e1319178e6be73571571d6571  # SHO
              - 1efe8da11bfd74fbbcd4d8f11f1571e2  # STAN
              - 5d2317d99af813b6529c7ebf01c83533  # VDL
              - 77a7b25585c18af08f60b1547bb9b4fb  # CC
            assign_scores_to:
              - name: WEB-1080p

    radarr:
      main:
        base_url: http://host.docker.internal:${toString ports.radarr}
        api_key: <RADARR_API_KEY>
        quality_definition:
          type: movie
        quality_profiles:
          - name: Remux/WEB-1080p
            reset_unmatched_scores:
              enabled: true
        custom_formats:
          - trash_ids:
              # HDR Formats
              - e23edd2482476e595fb990b12e7c609c  # DV HDR10
              - 58d6a88f13e2db7f5059c41047876f00  # DV
              - 55d53828b9d81cbe20b02efd00aa0efd  # DV HLG
              - a3e19f8f627608af0211acd02bf89735  # DV SDR
              - b974a6cd08c1066250f1f177d7aa1225  # HDR10Plus
              - dfb86d5941bc9075d6af23b09c2c0571  # HDR10
              - e61e28db95d22bedcadf030b8f156571  # HDR
              - 2a4d9069cc1fe3ce07c52f634c81571f  # HLG
              # Movie Versions
              - 0f12c086e289cf966fa5948eac571f44  # Hybrid
              - 570bc9ebecd92723d2d21500f4be314c  # Remaster
              - eca37840c13c6ef2dd0262b141a5482f  # 4K Remaster
              - e0c07d59beb37348e975a930d5e50319  # Criterion Collection
              - 9d27d9d2181838f76dee150882bdc58c  # Masters of Cinema
              - db9b4c4b53d312a3ca5f1378f6440fc9  # Vinegar Syndrome
              # Unwanted
              - ed38b889b31be83fda192888e2286d83  # BR-DISK
              - 90a6f9a284dff5103f6346090e6280c8  # LQ
              - dc98083864ea246d05a42df0d05f81cc  # x265 (HD)
              - b8cd450cbfa689c0259a01d9e29ba3d6  # 3D
              # Streaming Services
              - b3b3a6ac74ecbd56bcdbefa4799fb9df  # AMZN
              - 40e9380490e748672c2522eaaeb692f7  # ATVP
              - cc5e51a9e85a6296ceefe097a77f12f4  # BCORE
              - 16622a6911d1ab5d5b8b713f3c3b0227  # CRiT
              - 84272245b2988854bfb76a16e60baea5  # DSNP
              - 509e5f41146e278f9eab1f8f7e71a370  # HBO
              - 5763d1b0ce84aff3b21038c4c9f60f0e  # HMAX
              - 526d445d4c16214309f7c0f25b1f1465  # HULU
              - 2a6039655313bf5dab1e43523b62c374  # MA
              - 170b1d363bd8516fbf3a3eb05d4faff6  # NF
              - c9fd353f8f5f1baf56dc601c4cb29920  # PCOK
              - e36a0ba1bc902b26ee40818a1d331b3b  # PMTP
              - bf7e73dd1d85b12cc527dc619761c840  # Pathe
              - fb1a91cdc0f26f7c0b4ae2cc2d8b2d1f  # SC
            assign_scores_to:
              - name: Remux/WEB-1080p
  '';
in
{
  virtualisation.oci-containers.containers.recyclarr = {
    image = "ghcr.io/recyclarr/recyclarr:7.4.1";
    environment = {
      TZ = config.time.timeZone;
      RECYCLARR_CREATE_CONFIG = "false";
    };
    volumes = [
      "${recyclarrConfig}:/config/recyclarr.yml:ro"
    ];
    extraOptions = [
      "--add-host=host.docker.internal:host-gateway"
      "--network=host"
    ];
    # No entrypoint override — the container's default runs `sync` on a schedule
    # Use CRON_SCHEDULE env var for scheduling, or run manually:
    #   docker exec recyclarr recyclarr sync
  };

  # Daily sync timer using a systemd service that triggers the container's sync
  systemd.services.recyclarr-sync = {
    description = "Recyclarr TRaSH Guide sync";
    after = [ "docker-recyclarr.service" ];
    requires = [ "docker-recyclarr.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.docker}/bin/docker exec recyclarr recyclarr sync";
    };
  };

  systemd.timers.recyclarr-sync = {
    description = "Daily Recyclarr sync timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };
}
