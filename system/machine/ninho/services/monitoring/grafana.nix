# Grafana — datasources, dashboards, unified alerting + ntfy webhook routing.
# All alert rules are inline; see grafana-dashboards/ for the JSON dashboards.
{ pkgs, ... }:
{
  # Ensure /etc/secrets/grafana/secret_key exists and is readable by the grafana
  # user (it reads it via the settings file provider). Generates one on first
  # boot if missing; otherwise just fixes ownership/permissions.
  systemd.services.grafana-secret-key = {
    wantedBy = [ "multi-user.target" ];
    before = [ "grafana.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      install -d -m 0750 -o grafana -g grafana /etc/secrets/grafana
      if [ ! -s /etc/secrets/grafana/secret_key ]; then
        ${pkgs.openssl}/bin/openssl rand -base64 32 > /etc/secrets/grafana/secret_key
      fi
      chown grafana:grafana /etc/secrets/grafana/secret_key
      chmod 0400 /etc/secrets/grafana/secret_key
    '';
  };

  systemd.services.grafana = {
    after = [ "grafana-secret-key.service" ];
    requires = [ "grafana-secret-key.service" ];
  };

  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "0.0.0.0";
        http_port = 3000;
        domain = "grafana.ninho.local";
      };
      # 26.05 removed the default for security.secret_key (signs auth cookies).
      # Read it at runtime via Grafana's file provider (keeps it out of the store);
      # generate once: openssl rand -base64 32 > /etc/secrets/grafana/secret_key
      security.secret_key = "$__file{/etc/secrets/grafana/secret_key}";
      unified_alerting.enabled = true;
    };

    provision = {
      enable = true;

      datasources.settings.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          url = "http://localhost:9090";
          isDefault = true;
          uid = "prometheus";
        }
      ];

      dashboards.settings.providers = [
        {
          name = "ninho";
          options.path = ../grafana-dashboards;
          options.foldersFromFilesStructure = false;
        }
      ];

      alerting = {
        contactPoints.settings = {
          apiVersion = 1;
          contactPoints = [
            {
              orgId = 1;
              name = "ntfy";
              receivers = [
                {
                  uid = "ntfy-webhook";
                  type = "webhook";
                  settings = {
                    url = "http://localhost:8106/grafana-alerts";
                    httpMethod = "POST";
                  };
                }
              ];
            }
          ];
        };

        policies.settings = {
          apiVersion = 1;
          policies = [
            {
              orgId = 1;
              receiver = "ntfy";
              group_by = [
                "grafana_folder"
                "alertname"
              ];
              group_wait = "30s";
              group_interval = "5m";
              repeat_interval = "4h";
            }
          ];
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
                    {
                      refId = "A";
                      datasourceUid = "prometheus";
                      relativeTimeRange = {
                        from = 300;
                        to = 0;
                      };
                      model = {
                        expr = "zfs_pool_health != 0";
                        instant = true;
                      };
                    }
                    {
                      refId = "C";
                      datasourceUid = "__expr__";
                      model = {
                        type = "threshold";
                        expression = "A";
                        conditions = [
                          {
                            evaluator = {
                              type = "gt";
                              params = [ 0 ];
                            };
                          }
                        ];
                      };
                    }
                  ];
                  for = "0s";
                  labels.severity = "critical";
                  annotations = {
                    summary = "ZFS pool {{ $labels.pool }} is degraded";
                  };
                }
                {
                  uid = "smart-failed";
                  title = "SMART Health Failed";
                  condition = "C";
                  data = [
                    {
                      refId = "A";
                      datasourceUid = "prometheus";
                      relativeTimeRange = {
                        from = 300;
                        to = 0;
                      };
                      model = {
                        expr = "smartctl_device_smart_status";
                        instant = true;
                      };
                    }
                    {
                      refId = "C";
                      datasourceUid = "__expr__";
                      model = {
                        type = "threshold";
                        expression = "A";
                        conditions = [
                          {
                            evaluator = {
                              type = "lt";
                              params = [ 1 ];
                            };
                          }
                        ];
                      };
                    }
                  ];
                  for = "0s";
                  labels.severity = "critical";
                  annotations = {
                    summary = "Drive {{ $labels.device }} SMART health check failed";
                  };
                }
                {
                  uid = "drive-temp-critical";
                  title = "Drive Temperature Critical";
                  condition = "C";
                  data = [
                    {
                      refId = "A";
                      datasourceUid = "prometheus";
                      relativeTimeRange = {
                        from = 300;
                        to = 0;
                      };
                      model = {
                        expr = "smartctl_device_temperature{temperature_type=\"current\"}";
                        instant = true;
                      };
                    }
                    {
                      refId = "C";
                      datasourceUid = "__expr__";
                      model = {
                        type = "threshold";
                        expression = "A";
                        conditions = [
                          {
                            evaluator = {
                              type = "gt";
                              params = [ 55 ];
                            };
                          }
                        ];
                      };
                    }
                  ];
                  for = "0s";
                  labels.severity = "critical";
                  annotations = {
                    summary = "Drive {{ $labels.device }} temperature {{ $value }}°C exceeds 55°C";
                  };
                }
                {
                  uid = "gpu-temp-critical";
                  title = "GPU Temperature Critical";
                  condition = "C";
                  data = [
                    {
                      refId = "A";
                      datasourceUid = "prometheus";
                      relativeTimeRange = {
                        from = 300;
                        to = 0;
                      };
                      model = {
                        expr = "nvidia_smi_temperature_gpu";
                        instant = true;
                      };
                    }
                    {
                      refId = "C";
                      datasourceUid = "__expr__";
                      model = {
                        type = "threshold";
                        expression = "A";
                        conditions = [
                          {
                            evaluator = {
                              type = "gt";
                              params = [ 90 ];
                            };
                          }
                        ];
                      };
                    }
                  ];
                  for = "0s";
                  labels.severity = "critical";
                  annotations = {
                    summary = "GPU temperature {{ $value }}°C exceeds 90°C";
                  };
                }
                {
                  uid = "root-fs-full";
                  title = "Root Filesystem Full";
                  condition = "C";
                  data = [
                    {
                      refId = "A";
                      datasourceUid = "prometheus";
                      relativeTimeRange = {
                        from = 300;
                        to = 0;
                      };
                      model = {
                        expr = ''node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"} * 100'';
                        instant = true;
                      };
                    }
                    {
                      refId = "C";
                      datasourceUid = "__expr__";
                      model = {
                        type = "threshold";
                        expression = "A";
                        conditions = [
                          {
                            evaluator = {
                              type = "lt";
                              params = [ 10 ];
                            };
                          }
                        ];
                      };
                    }
                  ];
                  for = "0s";
                  labels.severity = "critical";
                  annotations = {
                    summary = "Root filesystem {{ $value | printf \"%.1f\" }}% free";
                  };
                }
                {
                  uid = "storage-fs-full";
                  title = "Storage Filesystem Full";
                  condition = "C";
                  data = [
                    {
                      refId = "A";
                      datasourceUid = "prometheus";
                      relativeTimeRange = {
                        from = 300;
                        to = 0;
                      };
                      model = {
                        expr = ''node_filesystem_avail_bytes{mountpoint=~"/storage.*"} / node_filesystem_size_bytes{mountpoint=~"/storage.*"} * 100'';
                        instant = true;
                      };
                    }
                    {
                      refId = "C";
                      datasourceUid = "__expr__";
                      model = {
                        type = "threshold";
                        expression = "A";
                        conditions = [
                          {
                            evaluator = {
                              type = "lt";
                              params = [ 15 ];
                            };
                          }
                        ];
                      };
                    }
                  ];
                  for = "0s";
                  labels.severity = "critical";
                  annotations = {
                    summary = "Storage {{ $labels.mountpoint }} {{ $value | printf \"%.1f\" }}% free";
                  };
                }
                {
                  uid = "postgresql-down";
                  title = "PostgreSQL Down";
                  condition = "C";
                  data = [
                    {
                      refId = "A";
                      datasourceUid = "prometheus";
                      relativeTimeRange = {
                        from = 300;
                        to = 0;
                      };
                      model = {
                        expr = "pg_up";
                        instant = true;
                      };
                    }
                    {
                      refId = "C";
                      datasourceUid = "__expr__";
                      model = {
                        type = "threshold";
                        expression = "A";
                        conditions = [
                          {
                            evaluator = {
                              type = "lt";
                              params = [ 1 ];
                            };
                          }
                        ];
                      };
                    }
                  ];
                  for = "0s";
                  labels.severity = "critical";
                  annotations = {
                    summary = "PostgreSQL is down";
                  };
                }
                {
                  uid = "service-failed";
                  title = "Critical Service Failed";
                  condition = "C";
                  data = [
                    {
                      refId = "A";
                      datasourceUid = "prometheus";
                      relativeTimeRange = {
                        from = 300;
                        to = 0;
                      };
                      model = {
                        expr = ''node_systemd_unit_state{state="failed",name=~"(grafana|prometheus|postgresql|nginx|ntfy-sh|sonarr|radarr|lidarr|readarr|prowlarr|deluge).*"}'';
                        instant = true;
                      };
                    }
                    {
                      refId = "C";
                      datasourceUid = "__expr__";
                      model = {
                        type = "threshold";
                        expression = "A";
                        conditions = [
                          {
                            evaluator = {
                              type = "gt";
                              params = [ 0 ];
                            };
                          }
                        ];
                      };
                    }
                  ];
                  for = "0s";
                  labels.severity = "critical";
                  annotations = {
                    summary = "Service {{ $labels.name }} has failed";
                  };
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
                    {
                      refId = "A";
                      datasourceUid = "prometheus";
                      relativeTimeRange = {
                        from = 600;
                        to = 0;
                      };
                      model = {
                        expr = ''100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)'';
                        instant = true;
                      };
                    }
                    {
                      refId = "C";
                      datasourceUid = "__expr__";
                      model = {
                        type = "threshold";
                        expression = "A";
                        conditions = [
                          {
                            evaluator = {
                              type = "gt";
                              params = [ 80 ];
                            };
                          }
                        ];
                      };
                    }
                  ];
                  for = "5m";
                  labels.severity = "warning";
                  annotations = {
                    summary = "CPU usage {{ $value | printf \"%.1f\" }}% (>80% for 5m)";
                  };
                }
                {
                  uid = "ram-usage-high";
                  title = "RAM Usage High";
                  condition = "C";
                  data = [
                    {
                      refId = "A";
                      datasourceUid = "prometheus";
                      relativeTimeRange = {
                        from = 600;
                        to = 0;
                      };
                      model = {
                        expr = "(node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100";
                        instant = true;
                      };
                    }
                    {
                      refId = "C";
                      datasourceUid = "__expr__";
                      model = {
                        type = "threshold";
                        expression = "A";
                        conditions = [
                          {
                            evaluator = {
                              type = "lt";
                              params = [ 10 ];
                            };
                          }
                        ];
                      };
                    }
                  ];
                  for = "5m";
                  labels.severity = "warning";
                  annotations = {
                    summary = "RAM available {{ $value | printf \"%.1f\" }}% (<10% for 5m)";
                  };
                }
                {
                  uid = "swap-usage-high";
                  title = "Swap Usage High";
                  condition = "C";
                  data = [
                    {
                      refId = "A";
                      datasourceUid = "prometheus";
                      relativeTimeRange = {
                        from = 600;
                        to = 0;
                      };
                      model = {
                        expr = "(node_memory_SwapTotal_bytes - node_memory_SwapFree_bytes) / node_memory_SwapTotal_bytes * 100";
                        instant = true;
                      };
                    }
                    {
                      refId = "C";
                      datasourceUid = "__expr__";
                      model = {
                        type = "threshold";
                        expression = "A";
                        conditions = [
                          {
                            evaluator = {
                              type = "gt";
                              params = [ 50 ];
                            };
                          }
                        ];
                      };
                    }
                  ];
                  for = "5m";
                  labels.severity = "warning";
                  annotations = {
                    summary = "Swap usage {{ $value | printf \"%.1f\" }}% (>50% for 5m)";
                  };
                }
                {
                  uid = "gpu-vram-high";
                  title = "GPU VRAM High";
                  condition = "C";
                  data = [
                    {
                      refId = "A";
                      datasourceUid = "prometheus";
                      relativeTimeRange = {
                        from = 300;
                        to = 0;
                      };
                      model = {
                        expr = "nvidia_smi_memory_used_bytes / nvidia_smi_memory_total_bytes * 100";
                        instant = true;
                      };
                    }
                    {
                      refId = "C";
                      datasourceUid = "__expr__";
                      model = {
                        type = "threshold";
                        expression = "A";
                        conditions = [
                          {
                            evaluator = {
                              type = "gt";
                              params = [ 95 ];
                            };
                          }
                        ];
                      };
                    }
                  ];
                  for = "2m";
                  labels.severity = "warning";
                  annotations = {
                    summary = "GPU VRAM usage {{ $value | printf \"%.1f\" }}% (>95% for 2m)";
                  };
                }
                {
                  uid = "nvme-wear-high";
                  title = "NVMe Wear High";
                  condition = "C";
                  data = [
                    {
                      refId = "A";
                      datasourceUid = "prometheus";
                      relativeTimeRange = {
                        from = 300;
                        to = 0;
                      };
                      model = {
                        expr = "smartctl_device_percentage_used{device=~\"nvme.*\"}";
                        instant = true;
                      };
                    }
                    {
                      refId = "C";
                      datasourceUid = "__expr__";
                      model = {
                        type = "threshold";
                        expression = "A";
                        conditions = [
                          {
                            evaluator = {
                              type = "gt";
                              params = [ 80 ];
                            };
                          }
                        ];
                      };
                    }
                  ];
                  for = "0s";
                  labels.severity = "warning";
                  annotations = {
                    summary = "NVMe {{ $labels.device }} wear {{ $value }}% (>80%)";
                  };
                }
                {
                  uid = "pg-deadlocks";
                  title = "PostgreSQL Deadlocks";
                  condition = "C";
                  data = [
                    {
                      refId = "A";
                      datasourceUid = "prometheus";
                      relativeTimeRange = {
                        from = 600;
                        to = 0;
                      };
                      model = {
                        expr = "rate(pg_stat_database_deadlocks[5m])";
                        instant = true;
                      };
                    }
                    {
                      refId = "C";
                      datasourceUid = "__expr__";
                      model = {
                        type = "threshold";
                        expression = "A";
                        conditions = [
                          {
                            evaluator = {
                              type = "gt";
                              params = [ 0 ];
                            };
                          }
                        ];
                      };
                    }
                  ];
                  for = "5m";
                  labels.severity = "warning";
                  annotations = {
                    summary = "PostgreSQL deadlocks detected in {{ $labels.datname }}";
                  };
                }
                {
                  uid = "power-high";
                  title = "Power Consumption High";
                  condition = "C";
                  data = [
                    {
                      refId = "A";
                      datasourceUid = "prometheus";
                      relativeTimeRange = {
                        from = 600;
                        to = 0;
                      };
                      model = {
                        expr = "scaph_host_power_microwatts / 1000000";
                        instant = true;
                      };
                    }
                    {
                      refId = "C";
                      datasourceUid = "__expr__";
                      model = {
                        type = "threshold";
                        expression = "A";
                        conditions = [
                          {
                            evaluator = {
                              type = "gt";
                              params = [ 500 ];
                            };
                          }
                        ];
                      };
                    }
                  ];
                  for = "5m";
                  labels.severity = "warning";
                  annotations = {
                    summary = "System power {{ $value | printf \"%.0f\" }}W (>500W for 5m)";
                  };
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
                    {
                      refId = "A";
                      datasourceUid = "prometheus";
                      relativeTimeRange = {
                        from = 600;
                        to = 0;
                      };
                      model = {
                        expr = "node_time_seconds - node_boot_time_seconds";
                        instant = true;
                      };
                    }
                    {
                      refId = "C";
                      datasourceUid = "__expr__";
                      model = {
                        type = "threshold";
                        expression = "A";
                        conditions = [
                          {
                            evaluator = {
                              type = "lt";
                              params = [ 300 ];
                            };
                          }
                        ];
                      };
                    }
                  ];
                  for = "0s";
                  labels.severity = "info";
                  annotations = {
                    summary = "System was rebooted (uptime < 5 minutes)";
                  };
                }
              ];
            }
          ];
        };
      };
    };
  };
}
