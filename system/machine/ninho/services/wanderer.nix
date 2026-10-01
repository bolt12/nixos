# Wanderer: self-hosted trail database (GPX tracks, lists, summit logs).
# https://github.com/open-wanderer/wanderer
#
# Three containers on a private docker network, following upstream's
# docker-compose.yml at v0.21.0:
#   - wanderer-search: Meilisearch. The index is rebuilt from PocketBase on
#     every start, so its data dir is disposable (wipe it on a Meili bump).
#   - wanderer-db: PocketBase. pb_data is the only state worth backing up.
#   - wanderer-web: the SvelteKit UI. The browser only ever talks to this one;
#     it reaches PocketBase over the docker network.
# PocketBase is published on loopback only, for its admin UI
# (`ssh -L 8122:127.0.0.1:8122 ninho`, then http://localhost:8122/_/). Its
# `users` collection allows open creation, so it must never be reachable from
# the network. Meilisearch is not published at all.
#
# Images are pinned by tag and digest for the reason given in trek.nix. Keep
# db and web on the same release; backups only restore within a minor version.
#
# Route drawing and the elevation correction done on GPX upload call the
# public FOSSGIS Valhalla, Nominatim and Overpass servers (upstream defaults),
# so the coordinates of uploaded or drawn routes leave this host.
{
  config,
  pkgs,
  constants,
  ...
}:
let
  inherit (constants) storage ports network;
  dataDir = "${storage.data}/wanderer";
  origin = "http://${network.ninho.vpnIp}:${toString ports.wanderer}";
  containerUnits = map (name: "docker-${name}.service") [
    "wanderer-search"
    "wanderer-db"
    "wanderer-web"
  ];

  shared = {
    autoStart = true;
    networks = [ "wanderer" ];
    # MEILI_MASTER_KEY, POCKETBASE_ENCRYPTION_KEY, POCKETBASE_PROXY_SECRET,
    # generated once by wanderer-init below.
    environmentFiles = [ "${dataDir}/.env" ];
  };
  sharedEnv = {
    TZ = "Europe/Lisbon";
    MEILI_URL = "http://wanderer-search:7700";
  };
  localtime = "/etc/localtime:/etc/localtime:ro";

  # Komoot provider plugin. The images ship without plugins: each release
  # attaches them as WASM bundles, and PocketBase discovers them from
  # /data/plugins/<id>/plugin.json. Keep `release` in step with the image tags
  # above; the hash comes from that release's SHA256SUMS.
  release = "v0.21.0";
  komootPlugin =
    pkgs.runCommand "wanderer-plugin-komoot-${release}"
      {
        src = pkgs.fetchurl {
          url = "https://github.com/open-wanderer/wanderer/releases/download/${release}/wanderer-plugin-komoot.tar.gz";
          hash = "sha256-68ckJBEY2pwiWqCMo4Lz92umJPk0GmnlsrO01/tJI74=";
        };
      }
      ''
        mkdir -p $out
        tar -xzf $src -C $out
      '';
in
{
  systemd.tmpfiles.rules = [
    "d ${dataDir} 0750 root root - -"
    "d ${dataDir}/meili 0750 root root - -"
    "d ${dataDir}/pb_data 0750 root root - -"
    "d ${dataDir}/plugins 0750 root root - -"
    "d ${dataDir}/uploads 0750 root root - -"
  ];

  virtualisation.oci-containers.containers = {
    wanderer-search = shared // {
      image = "getmeili/meilisearch:v1.36.0@sha256:203a0854738be101bfdada825ac3cbf95e5681bc849757b6bc199e4cfae98faa";
      volumes = [
        "${dataDir}/meili:/meili_data/data.ms"
        localtime
      ];
      environment = sharedEnv // {
        MEILI_NO_ANALYTICS = "true";
      };
    };

    wanderer-db = shared // {
      image = "flomp/wanderer-db:v0.21.0@sha256:ba7bd45b8177fec7a31d297ecaf3c98e94aabb4fc043f167df35aeba8b93468c";
      dependsOn = [ "wanderer-search" ];
      ports = [ "127.0.0.1:${toString ports.wanderer-db}:8090" ];
      volumes = [
        "${dataDir}/pb_data:/pb_data"
        "${dataDir}/plugins:/data/plugins"
        localtime
      ];
      environment = sharedEnv // {
        ORIGIN = origin;
      };
    };

    wanderer-web = shared // {
      image = "flomp/wanderer-web:v0.21.0@sha256:af721ffac56fd33243043211fc49e4d5c5651f784551ae7b5b05d845c7c41147";
      dependsOn = [
        "wanderer-search"
        "wanderer-db"
      ];
      ports = [ "${toString ports.wanderer}:3000" ];
      volumes = [
        # Auto-import inbox: GPX files dropped in uploads/<api-token>/ are
        # imported as trails for that token's user, then deleted.
        "${dataDir}/uploads:/app/uploads"
        localtime
      ];
      environment = sharedEnv // {
        ORIGIN = origin;
        PUBLIC_POCKETBASE_URL = "http://wanderer-db:8090";
        # Signup is closed: /register redirects and the signup endpoint
        # refuses new users. Set to "false" briefly to let someone register.
        PUBLIC_DISABLE_SIGNUP = "true";
        BODY_SIZE_LIMIT = "Infinity";
        UPLOAD_FOLDER = "/app/uploads";
        VALHALLA_URL = "https://valhalla1.openstreetmap.de";
        NOMINATIM_URL = "https://nominatim.openstreetmap.org";
        OVERPASS_API_URL = "https://overpass-api.de";
      };
    };
  };

  # The oci-containers module attaches containers to a network but never
  # creates one, and the secrets must exist before the first container reads
  # its environment file. Both are idempotent, so this runs before every start.
  systemd.services.wanderer-init = {
    description = "Wanderer: docker network and generated secrets";
    requires = [ "docker.service" ];
    after = [ "docker.service" ];
    before = containerUnits;
    requiredBy = containerUnits;
    path = [
      config.virtualisation.docker.package
      pkgs.openssl
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      docker network inspect wanderer >/dev/null 2>&1 || docker network create wanderer
      if [ ! -f ${dataDir}/.env ]; then
        umask 077
        {
          printf 'MEILI_MASTER_KEY=%s\n' "$(openssl rand -hex 32)"
          # PocketBase requires exactly 32 characters: 16 random bytes as hex.
          printf 'POCKETBASE_ENCRYPTION_KEY=%s\n' "$(openssl rand -hex 16)"
          printf 'POCKETBASE_PROXY_SECRET=%s\n' "$(openssl rand -hex 32)"
        } > ${dataDir}/.env
      fi
    '';
  };

  # `dependsOn` only orders unit starts; it does not wait for Meilisearch to
  # listen, and both units start in the same instant. PocketBase's first-run
  # migration creates the search indexes, and when Meili is not up yet it logs
  # the error and exits 0, so the unit ends "successfully" and
  # Restart=on-failure never retries. Upstream's compose avoids this with a
  # `service_healthy` condition; this waits for the same /health endpoint.
  # Before that, the plugin bundle is copied in on every start (the container
  # cannot follow symlinks into the Nix store), so Nix stays its source.
  systemd.services.docker-wanderer-db.preStart = ''
    install -Dm644 -t ${dataDir}/plugins/komoot ${komootPlugin}/komoot/*

    for _ in $(seq 60); do
      if ${config.virtualisation.docker.package}/bin/docker exec wanderer-search \
        curl -sf http://localhost:7700/health >/dev/null 2>&1; then
        exit 0
      fi
      sleep 1
    done
    echo "wanderer-search did not become healthy within 60s" >&2
    exit 1
  '';

  networking.firewall.allowedTCPPorts = [ ports.wanderer ];
}
