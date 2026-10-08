# Grafana alert rules and their routing to ntfy.
#
# A rule is a PromQL expression compared against one threshold. Missing data
# is not an alert here: when an exporter dies, `target-down` and the
# `*-blind` rules say so once, where NoData on every rule would say it thirty
# times.
{ constants, ... }:
let
  inherit (constants) ports;

  rule =
    severity: uid: title:
    {
      expr,
      op ? "gt",
      threshold ? 0,
      for ? "5m",
      summary,
    }:
    {
      inherit uid title for;
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
            inherit expr;
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
                  type = op;
                  params = [ threshold ];
                };
              }
            ];
          };
        }
      ];
      noDataState = "OK";
      execErrState = "Error";
      labels = { inherit severity; };
      annotations = { inherit summary; };
    };

  critical = rule "critical";
  warning = rule "warning";
  info = rule "info";

  # The measured value, for summaries.
  value = fmt: ''{{ printf "${fmt}" $values.A.Value }}'';

  hddTemperature = ''smartctl_device_temperature{temperature_type="current",device!~"nvme.*"}'';
  smartRaw =
    name: ''smartctl_device_attribute{attribute_value_type="raw",attribute_name=~"${name}"}'';
  hoursSince = metric: "(time() - ${metric}) / 3600";

  group = name: interval: rules: {
    orgId = 1;
    inherit name interval rules;
    folder = "Alerts";
  };

  # One ntfy topic, three urgencies.
  #
  # Grafana's default webhook payload is a JSON document, which ntfy delivers
  # as an attachment. `payload.template` replaces it with plain text. Title,
  # priority and tags go in ntfy's headers, and Grafana sends header values
  # as written, without templating, so each severity needs its own receiver.
  receiver = name: uid: severity: priority: tags: extra: {
    orgId = 1;
    inherit name;
    receivers = [
      {
        inherit uid;
        type = "webhook";
        settings = {
          url = "http://localhost:${toString ports.ntfy}/grafana-alerts";
          httpMethod = "POST";
          payload.template = ''
            {{ range .Alerts }}{{ .Labels.alertname }} [{{ .Status }}]{{ with .Annotations.summary }}: {{ . }}{{ end }}
            {{ end }}'';
          headers = {
            Title = "ninho: ${severity}";
            Priority = toString priority;
            Tags = tags;
            "Content-Type" = "text/plain";
          };
        }
        // extra;
      }
    ];
  };
in
{
  services.grafana.provision.alerting = {
    contactPoints.settings = {
      apiVersion = 1;
      contactPoints = [
        # `ntfy` keeps the name and uid it had as the only receiver. Critical
        # is "high" and not "max": a resolved alert arrives at the same
        # priority as the alert itself.
        (receiver "ntfy" "ntfy-webhook" "warning" 3 "warning" { })
        (receiver "ntfy-critical" "ntfy-critical" "critical" 4 "rotating_light" { })
        (receiver "ntfy-info" "ntfy-info" "info" 2 "information_source" { disableResolveMessage = true; })
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
          # 24h so a persistently-firing alert nags once a day, not 6×.
          repeat_interval = "24h";
          routes = [
            {
              receiver = "ntfy-critical";
              object_matchers = [
                [
                  "severity"
                  "="
                  "critical"
                ]
              ];
            }
            {
              receiver = "ntfy-info";
              object_matchers = [
                [
                  "severity"
                  "="
                  "info"
                ]
              ];
            }
          ];
        }
      ];
    };

    rules.settings = {
      apiVersion = 1;
      # There is no swap on this machine; the rule divided zero by zero.
      deleteRules = [
        {
          orgId = 1;
          uid = "swap-usage-high";
        }
      ];
      groups = [
        (group "critical" "1m" [
          (critical "zfs-degraded" "ZFS Pool Degraded" {
            expr = "zfs_pool_health";
            for = "0s";
            summary = "ZFS pool {{ $labels.pool }} is not ONLINE";
          })
          (critical "smart-failed" "SMART Health Failed" {
            expr = "smartctl_device_smart_status";
            op = "lt";
            threshold = 1;
            for = "0s";
            summary = "Drive {{ $labels.device }} failed its SMART health check";
          })
          (critical "smart-bad-sectors" "Drive Has Bad Sectors" {
            expr = "sum by (device) (${smartRaw "Reallocated_Sector_Ct|Current_Pending_Sector|Offline_Uncorrectable|Reported_Uncorrect"})";
            for = "0s";
            summary = "Drive {{ $labels.device }} reports ${value "%.0f"} reallocated, pending or uncorrectable sectors";
          })
          (critical "nvme-critical-warning" "NVMe Critical Warning" {
            expr = "smartctl_device_critical_warning";
            for = "0s";
            summary = "NVMe {{ $labels.device }} raised a critical warning flag";
          })
          (critical "drive-temp-critical" "Drive Temperature Critical" {
            expr = hddTemperature;
            threshold = 60;
            for = "2h";
            summary = "Drive {{ $labels.device }} has been above 60°C for 2h (now ${value "%.0f"}°C)";
          })
          (critical "gpu-temp-critical" "GPU Temperature Critical" {
            expr = "nvidia_smi_temperature_gpu";
            threshold = 90;
            for = "2m";
            summary = "GPU at ${value "%.0f"}°C";
          })
          (critical "root-fs-full" "Root Pool Almost Full" {
            # In GiB, not percent: rpool/reserved holds 180 GiB back, so the
            # pool's own percentage flatters what `/` can still use.
            expr = ''node_filesystem_avail_bytes{mountpoint="/"} / 2^30'';
            op = "lt";
            threshold = 30;
            for = "10m";
            summary = "Only ${value "%.0f"} GiB left on rpool";
          })
          (critical "storage-fs-full" "Storage Pool Almost Full" {
            expr = ''zfs_pool_free_bytes{pool="storage"} / zfs_pool_size_bytes{pool="storage"} * 100'';
            op = "lt";
            threshold = 10;
            for = "10m";
            summary = "Storage pool has ${value "%.1f"}% free";
          })
          (critical "postgresql-down" "PostgreSQL Down" {
            expr = "pg_up";
            op = "lt";
            threshold = 1;
            for = "2m";
            summary = "PostgreSQL is down";
          })
          (critical "service-failed" "Unit Failed" {
            # Filtered in the query so Grafana tracks the failing units, not
            # one instance for each of the three hundred healthy ones.
            expr = ''systemd_unit_state{state="failed"} == 1'';
            for = "2m";
            summary = "{{ $labels.name }} has failed";
          })
          (critical "tang-unreachable" "Tang Unreachable" {
            expr = ''probe_success{probe="tang"}'';
            op = "lt";
            threshold = 1;
            for = "10m";
            summary = "Tang on the RPi is not answering: the next unattended reboot will stop at the LUKS prompt";
          })
          (critical "postgres-backup-stale" "Postgres Backup Stale" {
            expr = hoursSince "postgres_backup_newest_timestamp_seconds";
            threshold = 30;
            for = "0s";
            summary = "Newest Postgres dump is ${value "%.0f"}h old";
          })
          (critical "replica-stale" "Backup Replica Stale" {
            # The replica keeps dailies only, and syncoid starts in the same
            # second as the daily it would send, so 25 to 49 hours is normal.
            expr = hoursSince ''zfs_snapshot_newest_timestamp_seconds{dataset=~"storage/backup/.+"}'';
            threshold = 54;
            for = "0s";
            summary = "Newest snapshot on {{ $labels.dataset }} is ${value "%.0f"}h old";
          })
        ])

        (group "warning" "2m" [
          (warning "target-down" "Scrape Target Down" {
            # llama-server ports are only open while a model is loaded.
            expr = ''up{job!="llama-server"}'';
            op = "lt";
            threshold = 1;
            summary = "Prometheus cannot scrape {{ $labels.job }}";
          })
          (warning "postgres-exporter-blind" "Postgres Collector Failing" {
            expr = "pg_scrape_collector_success";
            op = "lt";
            threshold = 1;
            for = "10m";
            summary = "postgres exporter collector {{ $labels.collector }} is failing";
          })
          (warning "smartctl-blind" "smartctl Cannot Read Drive" {
            expr = "smartctl_device_smartctl_exit_status";
            for = "10m";
            summary = "smartctl exits ${value "%.0f"} for {{ $labels.device }}";
          })
          (warning "nvidia-smi-blind" "nvidia-smi Failing" {
            expr = "nvidia_smi_command_exit_code";
            for = "10m";
            summary = "nvidia-smi exits ${value "%.0f"}";
          })
          (warning "deluge-exporter-blind" "Deluge Exporter Blind" {
            expr = "absent(deluge_torrents)";
            for = "10m";
            summary = "The deluge exporter is up but returns no torrent metrics";
          })
          (warning "textfile-stale" "Textfile Collector Stale" {
            expr = ''time() - node_textfile_mtime_seconds{file!~".*static.*"}'';
            threshold = 900;
            summary = "{{ $labels.file }} has not been rewritten for ${value "%.0f"}s";
          })
          (warning "service-probe-failed" "Service Not Answering" {
            expr = ''probe_success{kind="service"}'';
            op = "lt";
            threshold = 1;
            for = "10m";
            summary = "{{ $labels.probe }} is not answering on {{ $labels.instance }}";
          })
          (warning "resolver-failing" "DNS Resolver Failing" {
            expr = ''probe_success{kind="dns"}'';
            op = "lt";
            threshold = 1;
            for = "10m";
            summary = "{{ $labels.probe }} is not resolving";
          })
          (warning "uplink-down" "Uplink Down" {
            expr = ''probe_success{kind="ping"}'';
            op = "lt";
            threshold = 1;
            for = "10m";
            summary = "No ping reply from {{ $labels.probe }}";
          })
          (warning "certificate-expiring" "Certificate Expiring" {
            expr = "(probe_ssl_earliest_cert_expiry - time()) / 86400";
            op = "lt";
            threshold = 14;
            for = "1h";
            summary = "Certificate for {{ $labels.probe }} expires in ${value "%.0f"} days";
          })
          (warning "drive-temp-high" "Drive Temperature High" {
            expr = hddTemperature;
            threshold = 50;
            for = "1h";
            summary = "Drive {{ $labels.device }} at ${value "%.0f"}°C";
          })
          (warning "drive-crc-errors" "Drive CRC Errors Increasing" {
            # A count that grows points at the cable or port, not the platters.
            expr = "delta(${smartRaw "UDMA_CRC_Error_Count"}[1d])";
            for = "0s";
            summary = "Drive {{ $labels.device }} logged ${value "%.0f"} new CRC errors in a day";
          })
          (warning "nvme-wear-high" "NVMe Wear High" {
            expr = ''smartctl_device_percentage_used{device=~"nvme.*"}'';
            threshold = 80;
            for = "0s";
            summary = "NVMe {{ $labels.device }} is ${value "%.0f"}% worn";
          })
          (warning "nvme-spare-low" "NVMe Spare Low" {
            expr = "smartctl_device_available_spare";
            op = "lt";
            threshold = 20;
            for = "0s";
            summary = "NVMe {{ $labels.device }} has ${value "%.0f"}% spare blocks left";
          })
          (warning "rpool-space-low" "Root Pool Space Low" {
            expr = ''node_filesystem_avail_bytes{mountpoint="/"} / 2^30'';
            op = "lt";
            threshold = 75;
            for = "30m";
            summary = "${value "%.0f"} GiB left on rpool";
          })
          (warning "snapshot-stale" "Snapshots Stale" {
            # rpool is snapshotted hourly, storage/data daily.
            expr = ''
              (${hoursSince ''zfs_snapshot_newest_timestamp_seconds{dataset=~"rpool/(home|root)"}''} > 3)
                or (${hoursSince ''zfs_snapshot_newest_timestamp_seconds{dataset="storage/data"}''} > 30)
            '';
            for = "0s";
            summary = "Newest snapshot of {{ $labels.dataset }} is ${value "%.0f"}h old";
          })
          (warning "syncoid-not-running" "Replication Not Running" {
            expr = hoursSince ''systemd_timer_last_trigger_seconds{name=~"syncoid-.*"}'';
            threshold = 26;
            for = "0s";
            summary = "{{ $labels.name }} last fired ${value "%.0f"}h ago";
          })
          (warning "scrub-stale" "ZFS Scrub Overdue" {
            expr = ''(time() - systemd_timer_last_trigger_seconds{name="zfs-scrub.timer"}) / 86400'';
            threshold = 9;
            for = "0s";
            summary = "Last scrub started ${value "%.0f"} days ago";
          })
          (warning "cpu-load-high" "CPU Load High" {
            expr = ''100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)'';
            threshold = 80;
            # 20m: this box sustains high CPU during transcodes/inference;
            # only a much longer plateau signals a genuinely stuck load.
            for = "20m";
            summary = "CPU at ${value "%.0f"}% for 20m";
          })
          (warning "ram-usage-high" "RAM Usage High" {
            expr = "node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100";
            op = "lt";
            threshold = 10;
            summary = "${value "%.1f"}% of RAM available";
          })
          (warning "memory-pressure" "Memory Pressure" {
            expr = "rate(node_pressure_memory_stalled_seconds_total[5m]) * 100";
            threshold = 10;
            summary = "Every task stalled on memory ${value "%.0f"}% of the time";
          })
          (warning "oom-kill" "Process Killed For Memory" {
            expr = "increase(node_vmstat_oom_kill[15m])";
            for = "0s";
            summary = "The kernel OOM killer ran ${value "%.0f"} times in 15m";
          })
          (warning "pg-deadlocks" "PostgreSQL Deadlocks" {
            expr = "rate(pg_stat_database_deadlocks[5m])";
            summary = "Deadlocks in database {{ $labels.datname }}";
          })
          (warning "pg-connections-high" "PostgreSQL Connections High" {
            expr = "sum(pg_stat_activity_count) / scalar(pg_settings_max_connections) * 100";
            threshold = 80;
            summary = "${value "%.0f"}% of PostgreSQL connections in use";
          })
          (warning "power-high" "Power Consumption High" {
            # CPU package plus GPU. 700W for 15m: the two legitimately pass
            # 500W together during inference or gaming.
            expr = "sum(rate(node_rapl_package_joules_total[5m])) + sum(nvidia_smi_power_draw_watts)";
            threshold = 700;
            for = "15m";
            summary = "CPU and GPU drawing ${value "%.0f"}W for 15m";
          })
          (warning "gpu-throttled" "GPU Throttled By Hardware" {
            expr = "nvidia_smi_clocks_event_reasons_hw_thermal_slowdown + nvidia_smi_clocks_event_reasons_hw_power_brake_slowdown";
            summary = "The GPU is slowing itself down for heat or power";
          })
          (warning "camera-stalled" "Camera Stalled" {
            expr = "frigate_camera_fps";
            op = "lt";
            threshold = 1;
            for = "10m";
            summary = "Frigate receives no frames from {{ $labels.camera_name }}";
          })
        ])

        (group "info" "5m" [
          (info "system-rebooted" "System Rebooted" {
            expr = "node_time_seconds - node_boot_time_seconds";
            op = "lt";
            threshold = 900;
            for = "0s";
            summary = "ninho booted ${value "%.0f"}s ago";
          })
          (info "reboot-required" "Reboot Pending" {
            expr = "nixos_reboot_required";
            for = "1d";
            summary = "The running kernel has been behind the current system for a day";
          })
        ])
      ];
    };
  };
}
