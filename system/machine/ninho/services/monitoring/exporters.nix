# Prometheus exporters: system, GPU, DB, ZFS, SMART, systemd, energy, *arr.
# Pure data; merged into services.prometheus.exporters by the module system.
{ ... }:
{
  services.prometheus.exporters = {
    # System metrics (CPU, RAM, Disk, Network)
    node = {
      enable = true;
      enabledCollectors = [
        "wifi"
        "systemd"
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
      # (the role is created in databases.nix).
      dataSourceName = "user=postgres-exporter host=/run/postgresql database=postgres sslmode=disable";
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
    };

    # Energy consumption
    scaphandre = {
      enable = true;
      port = 9606;
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
      delugePasswordFile = "/var/lib/deluge/.config/deluge/auth";
    };
  };

  # Create API key files for exportarr and deluge auth
  # Also enable RAPL power monitoring for scaphandre (AMD Ryzen 9 9950X3D)
  # The kernel loads intel_rapl_common for AMD but leaves domains disabled by default
  systemd.tmpfiles.rules = [
    # Enable RAPL domains (w = write to file)
    "w /sys/class/powercap/intel-rapl:0/enabled - - - - 1"
    "w /sys/class/powercap/intel-rapl:0:0/enabled - - - - 1"
    # Make energy counters world-readable so scaphandre can read them (z = set permissions)
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
