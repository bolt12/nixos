# Prometheus exporters: system, GPU, DB, ZFS, SMART, systemd, *arr, cAdvisor.
# Merged into services.prometheus.exporters by the module system.
{
  config,
  constants,
  lib,
  pkgs,
  ...
}:
{
  services.prometheus.exporters = {
    # System metrics (CPU, RAM, Disk, Network)
    node = {
      enable = true;
      # Unit state comes from the systemd exporter below, which also has
      # timers, sockets and restart counts.
      enabledCollectors = [
        "processes"
        "zfs"
      ];
      port = 9100;
    };

    # GPU metrics (RTX 5090)
    nvidia-gpu = {
      enable = true;
      port = 9835;
    };

    # PostgreSQL database metrics
    postgres = {
      enable = true;
      port = 9187;
      # Connect as the exporter's own OS user so local peer auth succeeds
      # (the role and its pg_monitor grant are in databases.nix).
      dataSourceName = "user=postgres-exporter host=/run/postgresql database=postgres sslmode=disable";
      # Off by default.
      extraFlags = [
        "--collector.long_running_transactions"
        "--collector.database_wraparound"
        "--collector.postmaster"
      ];
    };

    # ZFS pool health & performance
    zfs = {
      enable = true;
      port = 9134;
    };

    # HDD health monitoring (SMART data)
    smartctl = {
      enable = true;
      port = 9633;
      # Monitor all physical drives
      devices = [
        "/dev/nvme0n1" # NVMe SSD 1
        "/dev/nvme1n1" # NVMe SSD 2
        "/dev/sda" # HDD 1 (storage pool)
        "/dev/sdb" # HDD 2 (storage pool)
        "/dev/sdc" # HDD 3 (storage pool)
      ];
    };

    # Systemd service status & health
    systemd = {
      enable = true;
      port = 9558;
      extraFlags = [ "--systemd.collector.enable-restart-count" ];
    };

    # Servarr
    exportarr-prowlarr = {
      enable = true;
      port = 9708;
      url = "http://localhost:8097";
      apiKeyFile = "/var/lib/secrets/prowlarr-api-key";
      environment.LOG_LEVEL = "warn";
    };

    exportarr-radarr = {
      enable = true;
      port = 9709;
      url = "http://localhost:8098";
      apiKeyFile = "/var/lib/secrets/radarr-api-key";
      environment.LOG_LEVEL = "warn";
    };

    exportarr-sonarr = {
      enable = true;
      port = 9710;
      url = "http://localhost:8099";
      apiKeyFile = "/var/lib/secrets/sonarr-api-key";
      environment.LOG_LEVEL = "warn";
    };

    exportarr-lidarr = {
      enable = true;
      port = 9711;
      url = "http://localhost:8100";
      apiKeyFile = "/var/lib/secrets/lidarr-api-key";
      environment.LOG_LEVEL = "warn";
    };

    exportarr-readarr = {
      enable = true;
      port = 9712;
      url = "http://localhost:8101";
      apiKeyFile = "/var/lib/secrets/readarr-api-key";
      environment.LOG_LEVEL = "warn";
    };

    deluge = {
      enable = true;
      port = 9713;
      delugeHost = "localhost";
      delugePort = 58846;
      # The whole auth file goes in as a credential; the start script below
      # picks the localclient password out of it.
      delugePasswordFile = config.services.deluge.authFile;
    };
  };

  # Deluge's auth file is `user:password:level` lines, and the module's start
  # script exports the entire file as the password. deluged always keeps a
  # `localclient` entry for local connections, so use that one.
  systemd.services.prometheus-deluge-exporter.script = lib.mkForce ''
    DELUGE_PASSWORD=$(${pkgs.gawk}/bin/awk -F: \
      '$1 == "localclient" { print $2; exit }' "$CREDENTIALS_DIRECTORY/password-file")
    export DELUGE_PASSWORD
    exec ${pkgs.prometheus-deluge-exporter}/bin/deluge-exporter
  '';

  # Per-service and per-container CPU, memory, IO and pressure, read from the
  # cgroup tree. Loopback only.
  services.cadvisor = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = constants.ports.cadvisor;
    extraOptions = [
      "-enable_metrics=cpu,memory,diskIO,oom_event,pressure"
      "-housekeeping_interval=30s"
      "-store_container_labels=false"
    ];
  };

  # API key files for exportarr, and RAPL access for the node exporter's
  # power metrics (AMD Ryzen 9 9950X3D).
  # The kernel loads intel_rapl_common for AMD but leaves domains disabled by default
  systemd.tmpfiles.rules = [
    # Enable RAPL domains (w = write to file)
    "w /sys/class/powercap/intel-rapl:0/enabled - - - - 1"
    "w /sys/class/powercap/intel-rapl:0:0/enabled - - - - 1"
    # The counters are root-only by default and the node exporter is not root
    # (z = set permissions).
    "z /sys/class/powercap/intel-rapl:0/energy_uj 0444 - - -"
    "z /sys/class/powercap/intel-rapl:0:0/energy_uj 0444 - - -"
    "d /var/lib/secrets 0755 root root -"
    "f /var/lib/secrets/prowlarr-api-key 0600 prometheus prometheus - dd35049b7bfa4e5390483a6e3fddb47b"
    "f /var/lib/secrets/radarr-api-key 0600 prometheus prometheus - 150535e0e27d457f91b8f5c9082c0e78"
    "f /var/lib/secrets/sonarr-api-key 0600 prometheus prometheus - 482ae55fc7f94b2386c5b8c883d817c5"
    "f /var/lib/secrets/lidarr-api-key 0600 prometheus prometheus - 4753f76dd50740dfab278af99c60e5ae"
    "f /var/lib/secrets/readarr-api-key 0600 prometheus prometheus - f322453d3b4f464dbb585bb4d83a9a9f"
  ];

  # User that owns the api-key files used by exportarr exporters
  users.users.prometheus = {
    isSystemUser = true;
    group = "prometheus";
  };
  users.groups.prometheus = { };
}
