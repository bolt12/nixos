# Supernote private cloud (constants.storage.data/supernote).
# Ratta publishes it only as Docker images. Deployment manual:
# https://ib.supernote.com/private-cloud/Supernote-Private-Cloud-Manual-Deployment-Method-Using-Docker-Containers.pdf
#
# To bump, take the new supernote-service and notelib tags from
# https://hub.docker.com/u/supernote and refresh the hash of `initSql`. MariaDB
# loads that script only into an empty db_data, so an existing database is
# upgraded by hand, the way the manual describes:
#   docker exec supernote-mariadb sh -c \
#     'mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" < /docker-entrypoint-initdb.d/supernotedb.sql'
# Read the new script first: it truncates f_recycle_file and f_file_convert.
{
  config,
  pkgs,
  lib,
  constants,
  ...
}:

let
  inherit (constants) storage ports;
  # Data directory for Supernote
  dataDir = "${storage.data}/supernote";

  # Schema for a fresh database. The URL carries no version, so the hash is
  # what pins it; `nix store prefetch-file <url>` prints the current one.
  initSql = pkgs.fetchurl {
    url = "https://supernote-private-cloud.supernote.com/cloud/supernotedb.sql";
    hash = "sha256-kY6lmwUtHK7TiPQ/v2aXy21O2epoyfUaizM6bn/mbkw=";
  };

  # Settings for docker-compose. The three passwords are not here: preStart
  # generates them into secrets.env and joins the two files into .env.
  envFile = pkgs.writeText "supernote.env" ''
    DB_HOSTNAME=supernote-mariadb
    MYSQL_DATABASE=supernotedb
    MYSQL_USER=supernote
    REDIS_HOST=supernote-redis
    REDIS_PORT=6379
  '';

  # Docker compose file for Supernote private cloud
  composeFile = pkgs.writeText "docker-compose.yml" ''
    version: '3.8'

    networks:
      supernote-net:
        driver: bridge

    services:
      supernote-mariadb:
        image: mariadb:10.6.24
        container_name: supernote-mariadb
        restart: unless-stopped
        environment:
          MYSQL_ROOT_PASSWORD: ''${MYSQL_ROOT_PASSWORD}
          MYSQL_DATABASE: ''${MYSQL_DATABASE}
          MYSQL_USER: ''${MYSQL_USER}
          MYSQL_PASSWORD: ''${MYSQL_PASSWORD}
        volumes:
          - ${dataDir}/db_data:/var/lib/mysql
          - ${initSql}:/docker-entrypoint-initdb.d/supernotedb.sql:ro
        networks:
          - supernote-net
        healthcheck:
          # Has to fail while the entrypoint initialises an empty db_data. That
          # phase runs a temporary server on the socket only, and
          # supernote-service does not recover from finding port 3306 closed
          # when it starts. A socket `mysqladmin ping` passes during it.
          test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
          interval: 10s
          timeout: 5s
          retries: 5
          start_period: 60s
        logging:
          driver: "json-file"
          options:
            max-size: "10m"
            max-file: "3"

      supernote-redis:
        image: redis:7.4.7
        container_name: supernote-redis
        restart: unless-stopped
        command: redis-server --requirepass ''${REDIS_PASSWORD} --appendonly yes
        volumes:
          - ${dataDir}/redis_data:/data
        networks:
          - supernote-net
        healthcheck:
          test: ["CMD", "redis-cli", "--raw", "incr", "ping"]
          interval: 10s
          timeout: 5s
          retries: 5
        logging:
          driver: "json-file"
          options:
            max-size: "10m"
            max-file: "3"

      notelib:
        image: supernote/notelib:6.9.3
        container_name: supernote-notelib
        restart: unless-stopped
        networks:
          - supernote-net
        logging:
          driver: "json-file"
          options:
            max-size: "10m"
            max-file: "3"

      supernote-service:
        image: supernote/supernote-service:26.10.09
        container_name: supernote-service
        # Not unless-stopped. After an unclean shutdown dockerd would start this
        # alongside MariaDB, skipping depends_on, and the backend gives up for
        # good on a closed port 3306 while the container stays Up. on-failure
        # is not applied when the daemon starts, so supernote-cloud's
        # `up -d` starts it once MariaDB is healthy.
        restart: on-failure
        depends_on:
          supernote-mariadb:
            condition: service_healthy
          supernote-redis:
            condition: service_healthy
        environment:
          DB_HOSTNAME: ''${DB_HOSTNAME}
          MYSQL_DATABASE: ''${MYSQL_DATABASE}
          MYSQL_USER: ''${MYSQL_USER}
          MYSQL_PASSWORD: ''${MYSQL_PASSWORD}
          REDIS_HOST: ''${REDIS_HOST}
          REDIS_PASSWORD: ''${REDIS_PASSWORD}
          REDIS_PORT: ''${REDIS_PORT}
        ports:
          - "${toString ports.supernote}:8080"
          - "${toString ports.supernote-sync}:18072"
          - "${toString ports.supernote-https}:443"
        volumes:
          - ${dataDir}/supernote_data:/home/supernote/data
          - ${dataDir}/logs:/home/supernote/logs
          # The entrypoint redirects the web UI's output into this directory,
          # and the UI does not start when it is missing.
          - ${dataDir}/cloud_logs:/home/supernote/cloud/logs
          - ${dataDir}/recycle:/home/supernote/recycle
          - ${dataDir}/convert:/home/supernote/convert
          - /etc/localtime:/etc/localtime:ro
          # Nothing at /etc/nginx/cert: an empty mount there hides the
          # certificate the image ships and nginx does not start.
        networks:
          - supernote-net
        logging:
          driver: "json-file"
          options:
            max-size: "10m"
            max-file: "3"
  '';

in
{
  # Create required directories. tmpfiles also resets the owner of an existing
  # directory on every switch. MariaDB and Redis run as uid 999 and stop
  # writing when their data directory goes back to root (Redis then refuses
  # every write with MISCONF, and login fails).
  systemd.tmpfiles.rules = [
    "d ${dataDir} 0755 root root - -"
    "d ${dataDir}/db_data 0755 999 999 - -"
    "d ${dataDir}/redis_data 0755 999 999 - -"
    "d ${dataDir}/supernote_data 0755 root root - -"
    "d ${dataDir}/logs 0755 root root - -"
    "d ${dataDir}/cloud_logs 0755 root root - -"
    "d ${dataDir}/recycle 0755 root root - -"
    "d ${dataDir}/convert 0755 root root - -"
  ];

  # Systemd service to manage docker-compose
  systemd.services.supernote-cloud = {
    description = "Supernote Private Cloud";
    after = [
      "docker.service"
      "network-online.target"
    ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    # A dockerd restart leaves supernote-service stopped (restart: on-failure),
    # so restart along with it and let compose bring it back.
    partOf = [ "docker.service" ];

    preStart = ''
      set -e
      umask 077

      # The passwords are generated once and stay out of the Nix store.
      # MariaDB writes them into db_data on its first start, so secrets.env
      # and db_data are reset together or not at all.
      if [ ! -f ${dataDir}/secrets.env ]; then
        for var in MYSQL_ROOT_PASSWORD MYSQL_PASSWORD REDIS_PASSWORD; do
          value=$(${pkgs.openssl}/bin/openssl rand -hex 24)
          printf '%s=%s\n' "$var" "$value"
        done > ${dataDir}/secrets.env.tmp
        mv ${dataDir}/secrets.env.tmp ${dataDir}/secrets.env
      fi

      # Copy compose files to data directory
      cp ${composeFile} ${dataDir}/docker-compose.yml
      cat ${envFile} ${dataDir}/secrets.env > ${dataDir}/.env
      chmod 600 ${dataDir}/.env
    '';

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      WorkingDirectory = dataDir;
      ExecStart = "${pkgs.docker-compose}/bin/docker-compose up -d";
      ExecStop = "${pkgs.docker-compose}/bin/docker-compose down";
      ExecReload = "${pkgs.docker-compose}/bin/docker-compose restart";
    };

    # Enable this service
    enable = true;
  };

  # Open firewall ports
  networking.firewall.allowedTCPPorts = [
    ports.supernote
    ports.supernote-https
    ports.supernote-sync
  ];

  # Add docker-compose to system packages
  environment.systemPackages = with pkgs; [
    docker-compose
  ];
}
