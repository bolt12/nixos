# Soberan: the home dashboard. One question, "is anything wrong right now",
# answered top to bottom; every other dashboard is a drill-down from here.
{ d, ... }:
let
  inherit (d)
    promql
    q
    row
    stat
    thresholds
    timeseries
    ;

  gib = n: n * 1024 * 1024 * 1024;

  tile =
    args:
    stat (
      {
        w = 3;
        h = 4;
      }
      // args
    );

  # A count that should be zero. `or vector(0)` because a count of nothing is
  # no data, and an empty tile reads as broken.
  problems =
    title: expr:
    tile {
      inherit title;
      expr = "count(${expr}) or vector(0)";
      limits = thresholds.zero;
    };
in
d.dashboard {
  uid = "soberan";
  title = "Soberan";
  description = "ninho at a glance: what is failing, what is close to failing, and how loaded the box is.";
  rows = [
    (row null [
      (problems "Targets down" ''up{job!="llama-server"} == 0'')
      (problems "Failed units" ''systemd_unit_state{state="failed"} == 1'')
      (problems "Services not answering" ''probe_success{kind="service"} == 0'')
      (problems "Cameras stalled" "frigate_camera_fps < 1")
      (tile {
        title = "Reboot pending";
        expr = "nixos_reboot_required";
        states = d.mappings.yesNoBad;
        desc = "The booted kernel, initrd or modules differ from the current system.";
      })
      (tile {
        title = "Hottest HDD";
        expr = "max(${promql.hddTemperature})";
        unit = "celsius";
        limits = thresholds.above 50 60;
      })
      (tile {
        title = "CPU temperature";
        expr = promql.cpuTemperature;
        unit = "celsius";
        decimals = 0;
        limits = thresholds.above 85 95;
      })
      (tile {
        title = "GPU temperature";
        expr = "nvidia_smi_temperature_gpu";
        unit = "celsius";
        limits = thresholds.above 80 90;
      })

      (tile {
        title = "CPU";
        expr = promql.cpuBusy;
        unit = "percent";
        decimals = 0;
        spark = true;
        limits = thresholds.above 80 95;
      })
      (tile {
        title = "Memory";
        expr = promql.memoryUsed;
        unit = "percent";
        decimals = 0;
        spark = true;
        limits = thresholds.above 85 95;
      })
      (tile {
        title = "GPU";
        expr = "nvidia_smi_utilization_gpu_ratio * 100";
        unit = "percent";
        decimals = 0;
        spark = true;
      })
      (tile {
        title = "VRAM";
        expr = "nvidia_smi_memory_used_bytes / nvidia_smi_memory_total_bytes * 100";
        unit = "percent";
        decimals = 0;
        spark = true;
        desc = "llama-swap keeps a model resident on purpose, so a high value here is normal.";
      })
      (tile {
        title = "CPU + GPU power";
        expr = promql.watts;
        unit = "watt";
        decimals = 0;
        spark = true;
        desc = "CPU package plus GPU. Drives, board, memory, fans and PSU loss are not measured.";
      })
      (tile {
        title = "rpool usable";
        expr = ''node_filesystem_avail_bytes{mountpoint="/"}'';
        unit = "bytes";
        decimals = 0;
        limits = thresholds.below (gib 75) (gib 30);
        desc = "What `/` can still write. rpool/reserved holds 180 GiB back, so this is lower than the pool's free space.";
      })
      (tile {
        title = "storage pool used";
        expr = ''zfs_pool_allocated_bytes{pool="storage"} / zfs_pool_size_bytes{pool="storage"} * 100'';
        unit = "percent";
        decimals = 0;
        limits = thresholds.above 80 90;
      })
      (tile {
        title = "Internet round trip";
        expr = ''probe_icmp_duration_seconds{probe="internet",phase="rtt"}'';
        unit = "s";
      })

      (d.alerts {
        title = "Alerts firing or pending";
        h = 7;
      })
    ])

    (row "Is my data safe" [
      (tile {
        title = "rpool";
        expr = ''zfs_pool_health{pool="rpool"}'';
        states = d.mappings.poolHealth;
        w = 4;
      })
      (tile {
        title = "storage";
        expr = ''zfs_pool_health{pool="storage"}'';
        states = d.mappings.poolHealth;
        w = 4;
      })
      (tile {
        title = "Drives failing SMART";
        expr = "count(smartctl_device_smart_status == 0) or vector(0)";
        limits = thresholds.zero;
        w = 4;
      })
      (tile {
        title = "Postgres dump age";
        expr = promql.hoursSince "postgres_backup_newest_timestamp_seconds";
        unit = "suffix: h";
        decimals = 0;
        limits = thresholds.above 26 30;
        w = 4;
        desc = "The dump runs nightly at 03:00.";
      })
      (tile {
        title = "Replica age";
        expr = promql.hoursSince ''max(zfs_snapshot_newest_timestamp_seconds{dataset=~"storage/backup/.+"})'';
        unit = "suffix: h";
        decimals = 0;
        limits = thresholds.above 50 54;
        w = 4;
        desc = "Age of the newest snapshot kept on storage/backup. The replica keeps dailies only, so 25 to 49 hours is normal.";
      })
      (tile {
        title = "Last scrub";
        expr = promql.daysSince ''systemd_timer_last_trigger_seconds{name="zfs-scrub.timer"}'';
        unit = "suffix: d";
        decimals = 0;
        limits = thresholds.above 8 9;
        w = 4;
      })
    ])

    (row "What is answering" [
      (d.timeline {
        title = "Services";
        targets = [ (q ''probe_success{kind="service"}'' "{{probe}}") ];
        states = d.mappings.upDown;
        h = 15;
        desc = "An HTTP request to each service every minute. Any answer short of a server error counts as up.";
      })
      (d.timeline {
        title = "What ninho depends on";
        targets = [ (q ''probe_success{kind!="service"}'' "{{probe}}") ];
        states = d.mappings.upDown;
        h = 7;
        desc = "Tang unlocks the disks at boot, Headscale runs the tailnet, the resolvers answer DNS for the LAN and the tailnet, and the rest are pings.";
      })
    ])

    (row "How loaded is it" [
      (timeseries {
        title = "CPU by mode";
        targets = [
          (q ''sum(rate(node_cpu_seconds_total{mode=~"user|nice"}[$__rate_interval])) / count(node_cpu_seconds_total{mode="idle"}) * 100'' "user")
          (q ''sum(rate(node_cpu_seconds_total{mode="system"}[$__rate_interval])) / count(node_cpu_seconds_total{mode="idle"}) * 100'' "system")
          (q ''sum(rate(node_cpu_seconds_total{mode="iowait"}[$__rate_interval])) / count(node_cpu_seconds_total{mode="idle"}) * 100'' "iowait")
        ];
        unit = "percent";
        stack = true;
        min = 0;
        w = 8;
      })
      (timeseries {
        title = "Memory";
        targets = [
          (q "node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes" "in use")
          (q "node_zfs_arc_size" "of which ZFS ARC")
          (q "node_memory_Cached_bytes + node_memory_Buffers_bytes" "page cache")
        ];
        unit = "bytes";
        min = 0;
        w = 8;
        desc = "In use is everything that cannot be reclaimed on demand. The ARC counts as in use, though ZFS gives it back under pressure.";
      })
      (timeseries {
        title = "GPU memory by tenant";
        targets = [ (q "nvidia_tenant_memory_used_bytes" "{{tenant}}") ];
        unit = "bytes";
        stack = true;
        many = true;
        min = 0;
        w = 8;
        interval = "15s";
      })
      (timeseries {
        title = "Busiest services, CPU cores";
        targets = [ (q (promql.topServiceCpu 8) "{{service}}") ];
        many = true;
        min = 0;
      })
      (timeseries {
        title = "Largest services, memory";
        targets = [ (q (promql.topServiceMemory 8) "{{service}}") ];
        unit = "bytes";
        many = true;
        min = 0;
      })
    ])
  ];
}
