# Grafana alert rules and their routing to ntfy.
#
# A rule is a PromQL expression compared against one threshold. Missing data
# is not an alert here: when an exporter dies, `target-down` and the
# `*-blind` rules say so once, where NoData on every rule would say it thirty
# times.
{
  config,
  constants,
  lib,
  ...
}:
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
      # What the alert is about, without the measured value. A resolved alert
      # is reported by this alone: its summary would be filled in with the
      # healthy value and read "0 new CRC errors".
      subject ? null,
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
      annotations = {
        inherit summary;
      }
      // lib.optionalAttrs (subject != null) { inherit subject; };
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

  # sdX letters follow probe order at boot and move between disks, so drive
  # rules name the model and serial printed on the label. topk keeps the
  # newest identity per device: after a quick reboot the old one is still in
  # the lookback window, and a plain join then fails as many-to-many.
  withDrive =
    expr:
    "(${expr}) * on(device) group_left(model_name, serial_number) (topk by (device) (1, timestamp(smartctl_device)) > bool 0)";
  drive = "{{ $labels.model_name }} {{ $labels.serial_number }}";

  # Units that something stops on purpose: gpu-tenant-control in llama-cpp.nix
  # stops Frigate to give a large model its VRAM. While such a unit is cleanly
  # stopped, its probe failing is expected. A crash leaves the unit failed
  # instead, and service-failed reports that.
  stoppedOnPurpose = {
    frigate = "${config.virtualisation.oci-containers.backend}-frigate.service";
  };
  unlessStoppedOnPurpose =
    expr:
    let
      stopped = lib.mapAttrsToList (
        probe: unit:
        ''label_replace(systemd_unit_state{name="${unit}",state="inactive"} == 1, "probe", "${probe}", "", "")''
      ) stoppedOnPurpose;
    in
    "${expr} unless on(probe) (${lib.concatStringsSep " or " stopped})";

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
      # Rules that left this file. Grafana keeps a provisioned rule until it is
      # deleted by uid here.
      deleteRules =
        map
          (uid: {
            orgId = 1;
            inherit uid;
          })
          [
            # There is no swap on this machine; the rule divided zero by zero.
            "swap-usage-high"
            # Dropped in July without a delete, and Grafana kept firing it.
            "gpu-vram-high"
            # The cameras that went quiet are switched off while someone is
            # home, so a stalled feed was the normal state, not a fault.
            "camera-stalled"
          ];
      groups = [
        (group "critical" "1m" [
          (critical "zfs-degraded" "ZFS Pool Degraded" {
            expr = "zfs_pool_health";
            for = "0s";
            summary = "ZFS pool {{ $labels.pool }} is not ONLINE";
            subject = "ZFS pool {{ $labels.pool }}";
          })
          (critical "smart-failed" "SMART Health Failed" {
            expr = withDrive "smartctl_device_smart_status";
            op = "lt";
            threshold = 1;
            for = "0s";
            summary = "${drive} failed its SMART health check";
            subject = drive;
          })
          (critical "smart-bad-sectors" "Drive Has Bad Sectors" {
            expr = withDrive "sum by (device) (${smartRaw "Reallocated_Sector_Ct|Current_Pending_Sector|Offline_Uncorrectable|Reported_Uncorrect"})";
            for = "0s";
            summary = "${drive} reports ${value "%.0f"} reallocated, pending or uncorrectable sectors";
            subject = drive;
          })
          (critical "nvme-critical-warning" "NVMe Critical Warning" {
            expr = withDrive "smartctl_device_critical_warning";
            for = "0s";
            summary = "${drive} raised its NVMe critical warning flag";
            subject = drive;
          })
          (critical "drive-temp-critical" "Drive Temperature Critical" {
            expr = withDrive hddTemperature;
            threshold = 60;
            for = "2h";
            summary = "${drive} has been above 60°C for 2h (now ${value "%.0f"}°C)";
            subject = drive;
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
            summary = "{{ $labels.name }} is in the failed state (journalctl -u {{ $labels.name }})";
            subject = "{{ $labels.name }}";
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
            summary = "Backup copy {{ $labels.dataset }}: newest snapshot is ${value "%.0f"}h old, normal is up to 49h";
            subject = "{{ $labels.dataset }}";
          })
        ])

        (group "warning" "2m" [
          (warning "target-down" "Exporter Down" {
            # llama-server ports are only open while a model is loaded. A job
            # that scrapes a service on the same port its probe checks would
            # repeat service-probe-failed, so it is left to that rule.
            expr = ''
              up{job!="llama-server"}
                unless on(instance)
                  label_replace(probe_success{kind="service"}, "instance", "$1", "instance", "http://([^/]+)/")
            '';
            op = "lt";
            threshold = 1;
            summary = "The {{ $labels.job }} exporter ({{ $labels.instance }}) is not answering, so alerts that read it cannot fire";
            subject = "{{ $labels.job }} exporter";
          })
          (warning "postgres-exporter-blind" "Postgres Collector Failing" {
            expr = "pg_scrape_collector_success";
            op = "lt";
            threshold = 1;
            for = "10m";
            summary = "postgres exporter collector {{ $labels.collector }} is failing";
            subject = "collector {{ $labels.collector }}";
          })
          (warning "smartctl-blind" "smartctl Cannot Read Drive" {
            # By device name: a drive smartctl cannot read may have no
            # identity series to take the serial from.
            expr = "smartctl_device_smartctl_exit_status";
            for = "10m";
            summary = "smartctl cannot read {{ $labels.device }} (exit status ${value "%.0f"})";
            subject = "{{ $labels.device }}";
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
            expr = ''(time() - node_textfile_mtime_seconds{file!~".*static.*"}) / 60'';
            threshold = 15;
            summary = "{{ $labels.file }} has not been rewritten for ${value "%.0f"} min: the job that writes it has stopped";
            subject = "{{ $labels.file }}";
          })
          (warning "service-probe-failed" "Service Not Answering" {
            expr = unlessStoppedOnPurpose ''probe_success{kind="service"}'';
            op = "lt";
            threshold = 1;
            for = "10m";
            summary = "{{ $labels.probe }} is not answering on {{ $labels.instance }}";
            subject = "{{ $labels.probe }}";
          })
          (warning "resolver-failing" "DNS Resolver Failing" {
            expr = ''probe_success{kind="dns"}'';
            op = "lt";
            threshold = 1;
            for = "10m";
            summary = "{{ $labels.probe }} is not resolving";
            subject = "{{ $labels.probe }}";
          })
          (warning "uplink-down" "Uplink Down" {
            expr = ''probe_success{kind="ping"}'';
            op = "lt";
            threshold = 1;
            for = "10m";
            summary = "No ping reply from {{ $labels.probe }}";
            subject = "{{ $labels.probe }}";
          })
          (warning "certificate-expiring" "Certificate Expiring" {
            expr = "(probe_ssl_earliest_cert_expiry - time()) / 86400";
            op = "lt";
            threshold = 14;
            for = "1h";
            summary = "Certificate for {{ $labels.probe }} expires in ${value "%.0f"} days";
            subject = "certificate for {{ $labels.probe }}";
          })
          (warning "drive-temp-high" "Drive Temperature High" {
            expr = withDrive hddTemperature;
            threshold = 50;
            for = "1h";
            summary = "${drive} at ${value "%.0f"}°C, above 50°C for the last hour";
            subject = drive;
          })
          (warning "drive-crc-errors" "Drive CRC Errors Increasing" {
            expr = withDrive "delta(${smartRaw "UDMA_CRC_Error_Count"}[1d])";
            for = "0s";
            summary = "${drive} logged ${value "%.0f"} new interface CRC errors in a day, which points at its SATA cable or port rather than the disk";
            subject = drive;
          })
          (warning "nvme-wear-high" "NVMe Wear High" {
            expr = withDrive ''smartctl_device_percentage_used{device=~"nvme.*"}'';
            threshold = 80;
            for = "0s";
            summary = "${drive} is ${value "%.0f"}% worn";
            subject = drive;
          })
          (warning "nvme-spare-low" "NVMe Spare Low" {
            expr = withDrive "smartctl_device_available_spare";
            op = "lt";
            threshold = 20;
            for = "0s";
            summary = "${drive} has ${value "%.0f"}% spare blocks left";
            subject = drive;
          })
          (warning "rpool-space-low" "Root Pool Space Low" {
            expr = ''node_filesystem_avail_bytes{mountpoint="/"} / 2^30'';
            op = "lt";
            threshold = 120;
            for = "10m";
            summary = "${value "%.0f"} GiB left on rpool";
          })
          (warning "snapshot-stale" "Snapshots Stale" {
            # rpool is snapshotted hourly, storage/data daily.
            expr = ''
              (${hoursSince ''zfs_snapshot_newest_timestamp_seconds{dataset=~"rpool/(home|root)"}''} > 3)
                or (${hoursSince ''zfs_snapshot_newest_timestamp_seconds{dataset="storage/data"}''} > 30)
            '';
            for = "0s";
            summary = "Newest snapshot of {{ $labels.dataset }} is ${value "%.0f"}h old (expected hourly for rpool, daily for storage/data)";
            subject = "{{ $labels.dataset }}";
          })
          (warning "syncoid-not-running" "Replication Not Running" {
            expr = hoursSince ''systemd_timer_last_trigger_seconds{name=~"syncoid-.*"}'';
            threshold = 26;
            for = "0s";
            summary = "{{ $labels.name }} last ran ${value "%.0f"}h ago: the copy to storage/backup is falling behind";
            subject = "{{ $labels.name }}";
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
            summary = "The kernel OOM killer ran ${value "%.0f"} times in 15m (journalctl -k -g oom names the processes)";
          })
          (warning "pg-deadlocks" "PostgreSQL Deadlocks" {
            expr = "rate(pg_stat_database_deadlocks[5m])";
            summary = "Deadlocks in database {{ $labels.datname }}";
            subject = "database {{ $labels.datname }}";
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
            summary = "A newer kernel has been installed for a day: reboot to run it";
          })
        ])
      ];
    };
  };
}
