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
        static_configs = [{
          targets = [ "localhost:9606" ];
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
    };

    provision = {
      enable = true;
      datasources.settings.datasources = [{
        name = "Prometheus";
        type = "prometheus";
        url = "http://localhost:9090";
        isDefault = true;
        uid = "prometheus";  # Set a fixed UID for dashboard references
      }];
    };
  };

  # Download popular Grafana dashboards
  systemd.tmpfiles.rules = [
    "d /var/lib/grafana/dashboards 0755 grafana grafana -"
  ];

  # Ensure postgres user exists for exporter
  users.users.prometheus = {
    isSystemUser = true;
    group = "prometheus";
  };
  users.groups.prometheus = {};
}
