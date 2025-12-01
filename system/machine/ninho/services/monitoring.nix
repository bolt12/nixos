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

  # Create API key files for exportarr and deluge auth
  systemd.tmpfiles.rules = [
    "d /var/lib/grafana/dashboards 0755 grafana grafana -"
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
