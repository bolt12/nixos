# NixOS & Monitoring: the state of the system itself, and of the monitoring
# that every other dashboard depends on.
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

  tile =
    args:
    stat (
      {
        w = 3;
        h = 4;
      }
      // args
    );

  # Not a problem: a model's port is only open while it is loaded.
  scraped = ''job!="llama-server"'';
in
d.dashboard {
  uid = "platform";
  title = "NixOS & Monitoring";
  description = "System generation, input ages and pending reboot, then the health of Prometheus, the exporters and Grafana alerting.";
  from = "now-24h";
  rows = [
    (row null [
      (tile {
        title = "Generation";
        expr = "nixos_generation";
      })
      (tile {
        title = "Built";
        expr = "nixos_generation_created_timestamp_seconds * 1000";
        unit = "dateTimeFromNow";
      })
      (tile {
        title = "Generations kept";
        expr = "nixos_generations";
        desc = "Each one pins its closure in the store until nix-gc removes it.";
      })
      (tile {
        title = "Reboot pending";
        expr = "nixos_reboot_required";
        states = d.mappings.yesNoBad;
        desc = "The booted kernel, initrd or modules differ from the current system.";
      })
      (tile {
        title = "Uptime";
        expr = "(node_time_seconds - node_boot_time_seconds) / 86400";
        unit = "suffix: d";
        decimals = 0;
      })
      (tile {
        title = "nixpkgs is";
        expr = promql.daysSince ''nixos_flake_input_last_modified_seconds{input="nixpkgs"}'';
        unit = "suffix: d old";
        decimals = 0;
        limits = thresholds.above 30 90;
        desc = "Age of the nixpkgs commit the running system was built from.";
      })
      (tile {
        title = "Store";
        expr = ''zfs_dataset_used_bytes{name="rpool/nix"}'';
        unit = "bytes";
        decimals = 0;
      })
      (tile {
        title = "Last garbage collection";
        expr = promql.hoursSince ''systemd_timer_last_trigger_seconds{name="nix-gc.timer"}'';
        unit = "suffix: h ago";
        decimals = 0;
      })
    ])

    (row "NixOS" [
      (stat {
        title = "Running";
        targets = [ (q "nixos_system_info" "{{version}}, kernel {{kernel}}") ];
        nameOnly = true;
        w = 8;
        h = 4;
      })
      (timeseries {
        title = "Generation";
        targets = [ (q "nixos_generation" "") ];
        w = 8;
        h = 4;
        desc = "Each step up is a rebuild that was switched to.";
      })
      (timeseries {
        title = "Store size";
        targets = [ (q ''zfs_dataset_used_bytes{name="rpool/nix"}'' "") ];
        unit = "bytes";
        w = 8;
        h = 4;
        desc = "Drops are garbage collections.";
      })
      (d.bars {
        title = "Age of each flake input";
        targets = [
          (q "sort_desc(${promql.daysSince "nixos_flake_input_last_modified_seconds"})" "{{input}}")
        ];
        unit = "suffix: d";
        decimals = 0;
        h = 13;
        desc = "Days since the commit each input is pinned to. Old is fine for a plugin that rarely changes; for nixpkgs it means missed security updates.";
      })
      (d.table {
        title = "Collectors that write textfiles";
        key = "collector";
        keyTitle = "Collector";
        w = 12;
        h = 13;
        columns = [
          {
            name = "Last written";
            expr = ''max by (collector) (label_replace(time() - node_textfile_mtime_seconds, "collector", "$1", "file", ".*/(.+)\\.prom"))'';
            unit = "s";
            decimals = 0;
          }
        ];
        desc = "A loop service rewrites each file. One that stops growing older than its interval has died; the static file is written once per rebuild.";
      })
    ])

    (row "Is the monitoring working" [
      (tile {
        title = "Targets down";
        expr = "count(up{${scraped}} == 0) or vector(0)";
        limits = thresholds.zero;
      })
      (tile {
        title = "Collectors failing";
        expr = "(count(pg_scrape_collector_success == 0) or vector(0)) + (count(smartctl_device_smartctl_exit_status != 0) or vector(0)) + (count(node_textfile_scrape_error != 0) or vector(0))";
        limits = thresholds.zero;
        desc = "Parts of an exporter that return nothing while the exporter itself is up.";
      })
      (tile {
        title = "Config reload";
        expr = "prometheus_config_last_reload_successful";
        states = d.mappings.okFailed;
      })
      (tile {
        title = "Series";
        expr = "prometheus_tsdb_head_series";
        decimals = 0;
        spark = true;
      })
      (tile {
        title = "Samples";
        expr = "sum(rate(prometheus_tsdb_head_samples_appended_total[$__rate_interval]))";
        unit = "suffix: /s";
        decimals = 0;
      })
      (tile {
        title = "On disk";
        expr = "prometheus_tsdb_storage_blocks_bytes + prometheus_tsdb_wal_storage_size_bytes";
        unit = "bytes";
        decimals = 1;
        desc = "Capped at 15 GB, on rpool.";
      })
      (tile {
        title = "History";
        expr = "(time() - prometheus_tsdb_lowest_timestamp_seconds) / 86400";
        unit = "suffix: d";
        decimals = 0;
        desc = "How far back the data goes. Retention is one year.";
      })
      (tile {
        title = "Alert rule failures";
        expr = "sum(increase(grafana_alerting_rule_evaluation_failures_total[1d]))";
        decimals = 0;
        limits = thresholds.zero;
      })

      (d.timeline {
        title = "Scrape targets";
        targets = [ (q "min by (job) (up{${scraped}})" "{{job}}") ];
        states = d.mappings.upDown;
        h = 12;
      })
      (timeseries {
        title = "Time each scrape takes";
        targets = [
          (q (d.topOver 8 "job" "max by (job) (scrape_duration_seconds)"
            "max by (job) (avg_over_time(scrape_duration_seconds[$__range] @ end()))"
          ) "{{job}}")
        ];
        unit = "s";
        many = true;
        min = 0;
      })
      (d.bars {
        title = "Series kept per job";
        targets = [ (q "sort_desc(sum by (job) (scrape_samples_post_metric_relabeling))" "{{job}}") ];
        decimals = 0;
        h = 8;
      })
      (timeseries {
        title = "Prometheus disk use";
        targets = [
          (q "prometheus_tsdb_storage_blocks_bytes" "blocks")
          (q "prometheus_tsdb_wal_storage_size_bytes" "write-ahead log")
        ];
        unit = "bytes";
        stack = true;
        min = 0;
        w = 8;
      })
      (timeseries {
        title = "Memory of the monitoring stack";
        targets = [
          (q ''sum by (service) (container_memory_working_set_bytes{service=~"prometheus.*|grafana|cadvisor"})'' "{{service}}")
        ];
        unit = "bytes";
        many = true;
        stack = true;
        min = 0;
        w = 8;
      })
      (timeseries {
        title = "Alert instances by state";
        targets = [ (q "sum by (state) (grafana_alerting_alerts)" "{{state}}") ];
        many = true;
        min = 0;
        w = 8;
      })
    ])
  ];
}
