{ config, pkgs, ... }:
{
  services.prometheus = {
    enable = true;
    port = 9090;

    exporters = {
      # System metrics (CPU, RAM, Disk, Network)
      node = {
        enable = true;
        enabledCollectors = [ "wifi" "systemd" "processes" "zfs" ];
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
        dataSourceName = "user=prometheus host=/run/postgresql database=postgres sslmode=disable";
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
          "/dev/nvme0n1"  # NVMe SSD 1
          "/dev/nvme1n1"  # NVMe SSD 2
          "/dev/sda"      # HDD 1 (storage pool)
          "/dev/sdb"      # HDD 2 (storage pool)
          "/dev/sdc"      # HDD 3 (storage pool)
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
      };

      exportarr-radarr = {
        enable = true;
        port = 9709;
        url = "http://localhost:8098";
        apiKeyFile = "/var/lib/secrets/radarr-api-key";
      };

      exportarr-sonarr = {
        enable = true;
        port = 9710;
        url = "http://localhost:8099";
        apiKeyFile = "/var/lib/secrets/sonarr-api-key";
      };

      exportarr-lidarr = {
        enable = true;
        port = 9711;
        url = "http://localhost:8100";
        apiKeyFile = "/var/lib/secrets/lidarr-api-key";
      };

      exportarr-readarr = {
        enable = true;
        port = 9712;
        url = "http://localhost:8101";
        apiKeyFile = "/var/lib/secrets/readarr-api-key";
      };

      deluge = {
        enable = true;
        port = 9713;
        delugeHost = "localhost";
        delugePort = 58846;
        delugePasswordFile = "/var/lib/deluge/.config/deluge/auth";
      };
    };

    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [{
          targets = [ "localhost:9100" ];
        }];
      }
      {
        job_name = "nvidia";
        static_configs = [{
          targets = [ "localhost:9835" ];
        }];
      }
      {
        job_name = "postgresql";
        static_configs = [{
          targets = [ "localhost:9187" ];
        }];
      }
      {
        job_name = "zfs";
        static_configs = [{
          targets = [ "localhost:9134" ];
        }];
      }
      {
        job_name = "smartctl";
        static_configs = [{
          targets = [ "localhost:9633" ];
        }];
      }
      {
        job_name = "systemd";
        static_configs = [{
          targets = [ "localhost:9558" ];
        }];
      }
      {
        job_name = "scaphandre";
        metrics_path = "//metrics";
        fallback_scrape_protocol = "PrometheusText0.0.4";
        static_configs = [{
          targets = [ "localhost:9606" ];
        }];
      }
      {
        job_name = "prowlarr";
        static_configs = [{
          targets = [ "localhost:9708" ];
        }];
      }
      {
        job_name = "radarr";
        static_configs = [{
          targets = [ "localhost:9709" ];
        }];
      }
      {
        job_name = "sonarr";
        static_configs = [{
          targets = [ "localhost:9710" ];
        }];
      }
      {
        job_name = "lidarr";
        static_configs = [{
          targets = [ "localhost:9711" ];
        }];
      }
      {
        job_name = "readarr";
        static_configs = [{
          targets = [ "localhost:9712" ];
        }];
      }
      {
        job_name = "deluge";
        static_configs = [{
          targets = [ "localhost:9713" ];
        }];
      }
    ];
  };

  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "0.0.0.0";
        http_port = 3000;
        domain = "grafana.ninho.local";
      };
      unified_alerting.enabled = true;
    };

    provision = {
      enable = true;

      datasources.settings.datasources = [{
        name = "Prometheus";
        type = "prometheus";
        url = "http://localhost:9090";
        isDefault = true;
        uid = "prometheus";
      }];

      dashboards.settings.providers = [{
        name = "ninho";
        options.path = ./grafana-dashboards;
        options.foldersFromFilesStructure = false;
      }];

      alerting = {
        contactPoints.settings = {
          apiVersion = 1;
          contactPoints = [{
            orgId = 1;
            name = "ntfy";
            receivers = [{
              uid = "ntfy-webhook";
              type = "webhook";
              settings = {
                url = "http://localhost:8106/grafana-alerts";
                httpMethod = "POST";
              };
            }];
          }];
        };

        policies.settings = {
          apiVersion = 1;
          policies = [{
            orgId = 1;
            receiver = "ntfy";
            group_by = [ "grafana_folder" "alertname" ];
            group_wait = "30s";
            group_interval = "5m";
            repeat_interval = "4h";
          }];
        };

        rules.settings = {
          apiVersion = 1;
          groups = [
            {
              orgId = 1;
              name = "critical";
              folder = "Alerts";
              interval = "1m";
              rules = [
                {
                  uid = "zfs-degraded";
                  title = "ZFS Pool Degraded";
                  condition = "C";
                  data = [
                    { refId = "A"; datasourceUid = "prometheus"; relativeTimeRange = { from = 300; to = 0; }; model = { expr = "zfs_pool_health != 0"; instant = true; }; }
                    { refId = "C"; datasourceUid = "__expr__"; model = { type = "threshold"; expression = "A"; conditions = [{ evaluator = { type = "gt"; params = [ 0 ]; }; }]; }; }
                  ];
                  for = "0s";
                  labels.severity = "critical";
                  annotations = { summary = "ZFS pool {{ $labels.pool }} is degraded"; };
                }
                {
                  uid = "smart-failed";
                  title = "SMART Health Failed";
                  condition = "C";
                  data = [
                    { refId = "A"; datasourceUid = "prometheus"; relativeTimeRange = { from = 300; to = 0; }; model = { expr = "smartctl_device_smart_status"; instant = true; }; }
                    { refId = "C"; datasourceUid = "__expr__"; model = { type = "threshold"; expression = "A"; conditions = [{ evaluator = { type = "lt"; params = [ 1 ]; }; }]; }; }
                  ];
                  for = "0s";
                  labels.severity = "critical";
                  annotations = { summary = "Drive {{ $labels.device }} SMART health check failed"; };
                }
                {
                  uid = "drive-temp-critical";
                  title = "Drive Temperature Critical";
                  condition = "C";
                  data = [
                    { refId = "A"; datasourceUid = "prometheus"; relativeTimeRange = { from = 300; to = 0; }; model = { expr = "smartctl_device_temperature{temperature_type=\"current\"}"; instant = true; }; }
                    { refId = "C"; datasourceUid = "__expr__"; model = { type = "threshold"; expression = "A"; conditions = [{ evaluator = { type = "gt"; params = [ 55 ]; }; }]; }; }
                  ];
                  for = "0s";
                  labels.severity = "critical";
                  annotations = { summary = "Drive {{ $labels.device }} temperature {{ $value }}°C exceeds 55°C"; };
                }
                {
                  uid = "gpu-temp-critical";
                  title = "GPU Temperature Critical";
                  condition = "C";
                  data = [
                    { refId = "A"; datasourceUid = "prometheus"; relativeTimeRange = { from = 300; to = 0; }; model = { expr = "nvidia_smi_temperature_gpu"; instant = true; }; }
                    { refId = "C"; datasourceUid = "__expr__"; model = { type = "threshold"; expression = "A"; conditions = [{ evaluator = { type = "gt"; params = [ 90 ]; }; }]; }; }
                  ];
                  for = "0s";
                  labels.severity = "critical";
                  annotations = { summary = "GPU temperature {{ $value }}°C exceeds 90°C"; };
                }
                {
                  uid = "root-fs-full";
                  title = "Root Filesystem Full";
                  condition = "C";
                  data = [
                    { refId = "A"; datasourceUid = "prometheus"; relativeTimeRange = { from = 300; to = 0; }; model = { expr = ''node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"} * 100''; instant = true; }; }
                    { refId = "C"; datasourceUid = "__expr__"; model = { type = "threshold"; expression = "A"; conditions = [{ evaluator = { type = "lt"; params = [ 10 ]; }; }]; }; }
                  ];
                  for = "0s";
                  labels.severity = "critical";
                  annotations = { summary = "Root filesystem {{ $value | printf \"%.1f\" }}% free"; };
                }
                {
                  uid = "storage-fs-full";
                  title = "Storage Filesystem Full";
                  condition = "C";
                  data = [
                    { refId = "A"; datasourceUid = "prometheus"; relativeTimeRange = { from = 300; to = 0; }; model = { expr = ''node_filesystem_avail_bytes{mountpoint=~"/storage.*"} / node_filesystem_size_bytes{mountpoint=~"/storage.*"} * 100''; instant = true; }; }
                    { refId = "C"; datasourceUid = "__expr__"; model = { type = "threshold"; expression = "A"; conditions = [{ evaluator = { type = "lt"; params = [ 15 ]; }; }]; }; }
                  ];
                  for = "0s";
                  labels.severity = "critical";
                  annotations = { summary = "Storage {{ $labels.mountpoint }} {{ $value | printf \"%.1f\" }}% free"; };
                }
                {
                  uid = "postgresql-down";
                  title = "PostgreSQL Down";
                  condition = "C";
                  data = [
                    { refId = "A"; datasourceUid = "prometheus"; relativeTimeRange = { from = 300; to = 0; }; model = { expr = "pg_up"; instant = true; }; }
                    { refId = "C"; datasourceUid = "__expr__"; model = { type = "threshold"; expression = "A"; conditions = [{ evaluator = { type = "lt"; params = [ 1 ]; }; }]; }; }
                  ];
                  for = "0s";
                  labels.severity = "critical";
                  annotations = { summary = "PostgreSQL is down"; };
                }
                {
                  uid = "service-failed";
                  title = "Critical Service Failed";
                  condition = "C";
                  data = [
                    { refId = "A"; datasourceUid = "prometheus"; relativeTimeRange = { from = 300; to = 0; }; model = { expr = ''node_systemd_unit_state{state="failed",name=~"(grafana|prometheus|postgresql|nginx|ntfy-sh|sonarr|radarr|lidarr|readarr|prowlarr|deluge).*"}''; instant = true; }; }
                    { refId = "C"; datasourceUid = "__expr__"; model = { type = "threshold"; expression = "A"; conditions = [{ evaluator = { type = "gt"; params = [ 0 ]; }; }]; }; }
                  ];
                  for = "0s";
                  labels.severity = "critical";
                  annotations = { summary = "Service {{ $labels.name }} has failed"; };
                }
              ];
            }
            {
              orgId = 1;
              name = "warning";
              folder = "Alerts";
              interval = "2m";
              rules = [
                {
                  uid = "cpu-load-high";
                  title = "CPU Load High";
                  condition = "C";
                  data = [
                    { refId = "A"; datasourceUid = "prometheus"; relativeTimeRange = { from = 600; to = 0; }; model = { expr = ''100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)''; instant = true; }; }
                    { refId = "C"; datasourceUid = "__expr__"; model = { type = "threshold"; expression = "A"; conditions = [{ evaluator = { type = "gt"; params = [ 80 ]; }; }]; }; }
                  ];
                  for = "5m";
                  labels.severity = "warning";
                  annotations = { summary = "CPU usage {{ $value | printf \"%.1f\" }}% (>80% for 5m)"; };
                }
                {
                  uid = "ram-usage-high";
                  title = "RAM Usage High";
                  condition = "C";
                  data = [
                    { refId = "A"; datasourceUid = "prometheus"; relativeTimeRange = { from = 600; to = 0; }; model = { expr = "(node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100"; instant = true; }; }
                    { refId = "C"; datasourceUid = "__expr__"; model = { type = "threshold"; expression = "A"; conditions = [{ evaluator = { type = "lt"; params = [ 10 ]; }; }]; }; }
                  ];
                  for = "5m";
                  labels.severity = "warning";
                  annotations = { summary = "RAM available {{ $value | printf \"%.1f\" }}% (<10% for 5m)"; };
                }
                {
                  uid = "swap-usage-high";
                  title = "Swap Usage High";
                  condition = "C";
                  data = [
                    { refId = "A"; datasourceUid = "prometheus"; relativeTimeRange = { from = 600; to = 0; }; model = { expr = "(node_memory_SwapTotal_bytes - node_memory_SwapFree_bytes) / node_memory_SwapTotal_bytes * 100"; instant = true; }; }
                    { refId = "C"; datasourceUid = "__expr__"; model = { type = "threshold"; expression = "A"; conditions = [{ evaluator = { type = "gt"; params = [ 50 ]; }; }]; }; }
                  ];
                  for = "5m";
                  labels.severity = "warning";
                  annotations = { summary = "Swap usage {{ $value | printf \"%.1f\" }}% (>50% for 5m)"; };
                }
                {
                  uid = "gpu-vram-high";
                  title = "GPU VRAM High";
                  condition = "C";
                  data = [
                    { refId = "A"; datasourceUid = "prometheus"; relativeTimeRange = { from = 300; to = 0; }; model = { expr = "nvidia_smi_memory_used_bytes / nvidia_smi_memory_total_bytes * 100"; instant = true; }; }
                    { refId = "C"; datasourceUid = "__expr__"; model = { type = "threshold"; expression = "A"; conditions = [{ evaluator = { type = "gt"; params = [ 95 ]; }; }]; }; }
                  ];
                  for = "2m";
                  labels.severity = "warning";
                  annotations = { summary = "GPU VRAM usage {{ $value | printf \"%.1f\" }}% (>95% for 2m)"; };
                }
                {
                  uid = "nvme-wear-high";
                  title = "NVMe Wear High";
                  condition = "C";
                  data = [
                    { refId = "A"; datasourceUid = "prometheus"; relativeTimeRange = { from = 300; to = 0; }; model = { expr = "smartctl_device_percentage_used{device=~\"nvme.*\"}"; instant = true; }; }
                    { refId = "C"; datasourceUid = "__expr__"; model = { type = "threshold"; expression = "A"; conditions = [{ evaluator = { type = "gt"; params = [ 80 ]; }; }]; }; }
                  ];
                  for = "0s";
                  labels.severity = "warning";
                  annotations = { summary = "NVMe {{ $labels.device }} wear {{ $value }}% (>80%)"; };
                }
                {
                  uid = "pg-deadlocks";
                  title = "PostgreSQL Deadlocks";
                  condition = "C";
                  data = [
                    { refId = "A"; datasourceUid = "prometheus"; relativeTimeRange = { from = 600; to = 0; }; model = { expr = "rate(pg_stat_database_deadlocks[5m])"; instant = true; }; }
                    { refId = "C"; datasourceUid = "__expr__"; model = { type = "threshold"; expression = "A"; conditions = [{ evaluator = { type = "gt"; params = [ 0 ]; }; }]; }; }
                  ];
                  for = "5m";
                  labels.severity = "warning";
                  annotations = { summary = "PostgreSQL deadlocks detected in {{ $labels.datname }}"; };
                }
                {
                  uid = "power-high";
                  title = "Power Consumption High";
                  condition = "C";
                  data = [
                    { refId = "A"; datasourceUid = "prometheus"; relativeTimeRange = { from = 600; to = 0; }; model = { expr = "scaph_host_power_microwatts / 1000000"; instant = true; }; }
                    { refId = "C"; datasourceUid = "__expr__"; model = { type = "threshold"; expression = "A"; conditions = [{ evaluator = { type = "gt"; params = [ 500 ]; }; }]; }; }
                  ];
                  for = "5m";
                  labels.severity = "warning";
                  annotations = { summary = "System power {{ $value | printf \"%.0f\" }}W (>500W for 5m)"; };
                }
              ];
            }
            {
              orgId = 1;
              name = "info";
              folder = "Alerts";
              interval = "5m";
              rules = [
                {
                  uid = "system-rebooted";
                  title = "System Rebooted";
                  condition = "C";
                  data = [
                    { refId = "A"; datasourceUid = "prometheus"; relativeTimeRange = { from = 600; to = 0; }; model = { expr = "node_time_seconds - node_boot_time_seconds"; instant = true; }; }
                    { refId = "C"; datasourceUid = "__expr__"; model = { type = "threshold"; expression = "A"; conditions = [{ evaluator = { type = "lt"; params = [ 300 ]; }; }]; }; }
                  ];
                  for = "0s";
                  labels.severity = "info";
                  annotations = { summary = "System was rebooted (uptime < 5 minutes)"; };
                }
              ];
            }
          ];
        };
      };
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

  # Ensure postgres user exists for exporter
  users.users.prometheus = {
    isSystemUser = true;
    group = "prometheus";
  };
  users.groups.prometheus = {};
}
