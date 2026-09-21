# TREK: self-hosted collaborative travel/trip planner (Docker).
# Single container: NestJS + React + SQLite, no external DB needed.
# https://github.com/liketrek/TREK
{
  pkgs,
  constants,
  ...
}:
let
  inherit (constants) storage ports;
  dataDir = "${storage.data}/trek";
in
{
  systemd.tmpfiles.rules = [
    "d ${dataDir} 0750 root root - -"
    "d ${dataDir}/data 0750 root root - -"
    "d ${dataDir}/uploads 0750 root root - -"
  ];

  virtualisation.oci-containers.containers.trek = {
    image = "mauriceboe/trek:latest";
    autoStart = true;
    ports = [
      "${toString ports.trek}:3000"
    ];
    volumes = [
      "${dataDir}/data:/app/data"
      "${dataDir}/uploads:/app/uploads"
      "/etc/localtime:/etc/localtime:ro"
    ];
    environmentFiles = [
      "${dataDir}/.env"
    ];
    environment = {
      NODE_ENV = "production";
      TZ = "Europe/Lisbon";
      COOKIE_SECURE = "false";
      ALLOW_LOCAL_NETWORK = "true";
      ALLOW_INTERNAL_NETWORK = "true";
    };
    extraOptions = [
      "--read-only"
      "--tmpfs=/tmp:noexec,nosuid,size=128m"
      "--cap-drop=ALL"
      "--cap-add=CHOWN"
      "--cap-add=SETUID"
      "--cap-add=SETGID"
      "--security-opt=no-new-privileges"
    ];
  };

  # Generate ENCRYPTION_KEY on first start if absent.
  systemd.services.docker-trek.preStart = ''
    if [ ! -f ${dataDir}/.env ]; then
      key=$(${pkgs.openssl}/bin/openssl rand -hex 32)
      printf 'ENCRYPTION_KEY=%s\n' "$key" > ${dataDir}/.env
      chmod 600 ${dataDir}/.env
    fi
  '';

  networking.firewall.allowedTCPPorts = [ ports.trek ];
}
