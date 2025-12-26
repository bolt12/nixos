{ config, pkgs, lib, constants, ... }:

let
  inherit (constants) storage;
  # Data directory for Supernote
  dataDir = "${storage.data}/supernote";

  # Generate random passwords (change these in production!)
  mysqlRootPassword = "changeme_mysql_root";
  mysqlPassword = "changeme_mysql_user";
  redisPassword = "changeme_redis";

  # Environment file for docker-compose
  envFile = pkgs.writeText "supernote.env" ''
    DB_HOSTNAME=supernote-mariadb
    MYSQL_ROOT_PASSWORD=${mysqlRootPassword}
    MYSQL_DATABASE=supernotedb
    MYSQL_USER=supernote
    MYSQL_PASSWORD=${mysqlPassword}
    REDIS_HOST=supernote-redis
    REDIS_PASSWORD=${redisPassword}
    REDIS_PORT=6379
    HTTP_PORT=19072
    HTTPS_PORT=19443
  '';

  # Docker compose file for Supernote private cloud
  composeFile = pkgs.writeText "docker-compose.yml" ''
    version: '3.8'

    networks:
      supernote-net:
        driver: bridge

    services:
      supernote-mariadb:
        image: supernote/mariadb:10.6.19
        container_name: supernote-mariadb
        restart: unless-stopped
        environment:
          MYSQL_ROOT_PASSWORD: ''${MYSQL_ROOT_PASSWORD}
          MYSQL_DATABASE: ''${MYSQL_DATABASE}
          MYSQL_USER: ''${MYSQL_USER}
          MYSQL_PASSWORD: ''${MYSQL_PASSWORD}
        volumes:
          - ${dataDir}/db_data:/var/lib/mysql
          - ${dataDir}/supernotedb.sql:/docker-entrypoint-initdb.d/supernotedb.sql:ro
        networks:
          - supernote-net
        healthcheck:
          test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p''${MYSQL_ROOT_PASSWORD}"]
          interval: 10s
          timeout: 5s
          retries: 5
        logging:
          driver: "json-file"
          options:
            max-size: "10m"
            max-file: "3"

      supernote-redis:
        image: supernote/redis:7.0.12
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
        image: supernote/supernote-service:25.12.17
        container_name: supernote-service
        restart: unless-stopped
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
          - "''${HTTP_PORT:-19072}:8080"
          - "18072:18072"
          - "''${HTTPS_PORT:-19443}:443"
        volumes:
          - ${dataDir}/supernote_data:/home/supernote/data
          - ${dataDir}/logs:/home/supernote/logs
          - ${dataDir}/recycle:/home/supernote/recycle
          - ${dataDir}/file_conversion:/home/supernote/file_conversion
          - ${dataDir}/certs:/home/supernote/certs
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
  # Create required directories
  systemd.tmpfiles.rules = [
    "d ${dataDir} 0755 root root - -"
    "d ${dataDir}/db_data 0755 root root - -"
    "d ${dataDir}/redis_data 0755 root root - -"
    "d ${dataDir}/supernote_data 0755 root root - -"
    "d ${dataDir}/logs 0755 root root - -"
    "d ${dataDir}/recycle 0755 root root - -"
    "d ${dataDir}/file_conversion 0755 root root - -"
    "d ${dataDir}/certs 0755 root root - -"
  ];

  # Systemd service to manage docker-compose
  systemd.services.supernote-cloud = {
    description = "Supernote Private Cloud";
    after = [ "docker.service" "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    preStart = ''
      # Download database initialization SQL if not present
      if [ ! -f ${dataDir}/supernotedb.sql ]; then
        echo "Downloading supernotedb.sql..."
        ${pkgs.curl}/bin/curl -L -o ${dataDir}/supernotedb.sql \
          https://supernote-private-cloud.supernote.com/docker-deploy/supernotedb.sql || \
          echo "WARNING: Failed to download supernotedb.sql. You'll need to download it manually."
      fi

      # Copy compose files to data directory
      cp ${composeFile} ${dataDir}/docker-compose.yml
      cp ${envFile} ${dataDir}/.env
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
    19072  # HTTP access
    19443  # HTTPS access
    18072  # WebSocket sync (optional)
  ];

  # Add docker-compose to system packages
  environment.systemPackages = with pkgs; [
    docker-compose
  ];
}
