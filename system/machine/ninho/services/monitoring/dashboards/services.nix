# Services: which are answering, which have failed or keep restarting, and
# what each one costs in CPU, memory and disk.
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

  # Panels in the last row follow the service picked at the top.
  picked = ''service=~"$service"'';
  selected =
    title: unit: targets:
    timeseries {
      inherit title unit targets;
      many = true;
      min = 0;
      w = 8;
    };
in
d.dashboard {
  uid = "services";
  title = "Services";
  description = "Probe results, failed and restarting units, and resource use per systemd service and container.";
  variables = [
    (d.labelVar {
      name = "service";
      label = "Service";
      metric = ''container_memory_working_set_bytes{service!=""}'';
      labelName = "service";
      all = false;
    })
  ];
  rows = [
    (row null [
      (tile {
        title = "Not answering";
        expr = ''count(probe_success{kind="service"} == 0) or vector(0)'';
        limits = thresholds.zero;
      })
      (tile {
        title = "Failed units";
        expr = ''count(systemd_unit_state{state="failed"} == 1) or vector(0)'';
        limits = thresholds.zero;
      })
      (tile {
        title = "Restarts, 24h";
        expr = "sum(increase(systemd_service_restart_total[1d]))";
        decimals = 0;
        desc = "Automatic restarts by systemd across all services.";
      })
      (tile {
        title = "Services running";
        expr = ''count(systemd_unit_state{state="active",type="service"} == 1)'';
      })
      (tile {
        title = "Containers";
        expr = ''count(container_memory_working_set_bytes{name!=""}) or vector(0)'';
      })
      (tile {
        title = "Slowest answer";
        expr = ''max(probe_duration_seconds{kind="service"})'';
        unit = "s";
        limits = thresholds.above 1 5;
      })
      (tile {
        title = "Availability, 24h";
        expr = ''avg(avg_over_time(probe_success{kind="service"}[1d])) * 100'';
        unit = "percent";
        decimals = 2;
        limits = thresholds.below 99.5 99;
        desc = "Share of probes answered, averaged over every service.";
      })
      (tile {
        title = "OOM kills, 24h";
        expr = ''sum(increase(container_oom_events_total{service!=""}[1d]))'';
        decimals = 0;
        limits = thresholds.zero;
      })
    ])

    (row "Answering" [
      (d.table {
        title = "Probes";
        key = "probe";
        keyTitle = "Service";
        sortBy = "Answer time";
        w = 14;
        h = 12;
        columns = [
          {
            name = "Now";
            expr = ''max by (probe) (probe_success{kind="service"})'';
            states = d.mappings.upDown;
          }
          {
            name = "HTTP status";
            expr = ''max by (probe) (probe_http_status_code{kind="service"})'';
          }
          {
            name = "Answer time";
            expr = ''max by (probe) (probe_duration_seconds{kind="service"})'';
            unit = "s";
          }
          {
            name = "Available, 24h";
            expr = ''avg by (probe) (avg_over_time(probe_success{kind="service"}[1d])) * 100'';
            unit = "percent";
            decimals = 2;
            limits = thresholds.below 99.5 99;
          }
        ];
      })
      (d.labelTable {
        title = "Failed units";
        expr = ''systemd_unit_state{state="failed"} == 1'';
        labels = [
          "name"
          "type"
        ];
        w = 10;
        h = 12;
        desc = "Empty when nothing has failed.";
      })
      (timeseries {
        title = "Slowest services to answer";
        targets = [
          (q (d.topOver 8 "probe" ''max by (probe) (probe_duration_seconds{kind="service"})''
            ''max by (probe) (avg_over_time(probe_duration_seconds{kind="service"}[$__range] @ end()))''
          ) "{{probe}}")
        ];
        unit = "s";
        many = true;
        min = 0;
        h = 7;
      })
    ])

    (row "Restarting" [
      (timeseries {
        title = "Restarts per hour";
        targets = [
          (q (d.topOver 8 "name" "increase(systemd_service_restart_total[1h])"
            "increase(systemd_service_restart_total[$__range] @ end())"
          ) "{{name}}")
        ];
        many = true;
        min = 0;
        desc = "The eight most restarted services in the visible range. A line above zero is a crash loop or a watchdog restart.";
      })
      (d.bars {
        title = "Most restarted, 7 days";
        targets = [ (q "sort_desc(topk(10, increase(systemd_service_restart_total[7d])))" "{{name}}") ];
        decimals = 0;
        h = 8;
      })
    ])

    (row "What they cost" [
      (timeseries {
        title = "Busiest, CPU cores";
        targets = [ (q (promql.topServiceCpu 10) "{{service}}") ];
        many = true;
        min = 0;
      })
      (timeseries {
        title = "Largest, memory";
        targets = [ (q (promql.topServiceMemory 10) "{{service}}") ];
        unit = "bytes";
        many = true;
        min = 0;
      })
      (d.table {
        title = "Every service";
        key = "service";
        keyTitle = "Service";
        sortBy = "Memory";
        h = 12;
        columns = [
          {
            name = "Memory";
            expr = promql.serviceMemory;
            unit = "bytes";
          }
          {
            name = "Of which cache";
            expr = ''sum by (service) (container_memory_cache{service!=""})'';
            unit = "bytes";
          }
          {
            name = "CPU cores";
            expr = promql.serviceCpu "5m";
            decimals = 2;
          }
          {
            name = "Disk reads";
            expr = ''sum by (service) (rate(container_fs_reads_bytes_total{service!=""}[5m]))'';
            unit = "Bps";
          }
          {
            name = "Disk writes";
            expr = ''sum by (service) (rate(container_fs_writes_bytes_total{service!=""}[5m]))'';
            unit = "Bps";
          }
        ];
        desc = "Memory is the working set: what the kernel cannot drop without the service noticing. Part of it can still be file cache the service keeps touching.";
      })
    ])

    (row "Selected: $service" [
      (selected "CPU cores" "short" [
        (q "sum by (service) (rate(container_cpu_usage_seconds_total{${picked}}[$__rate_interval]))" "{{service}}")
      ])
      (selected "Memory" "bytes" [
        (q "sum by (service) (container_memory_working_set_bytes{${picked}})" "{{service}}")
      ])
      (selected "Anonymous memory" "bytes" [
        (q "sum by (service) (container_memory_rss{${picked}})" "{{service}}")
      ])
      (selected "Disk reads" "Bps" [
        (q "sum by (service) (rate(container_fs_reads_bytes_total{${picked}}[$__rate_interval]))" "{{service}}")
      ])
      (selected "Disk writes" "Bps" [
        (q "sum by (service) (rate(container_fs_writes_bytes_total{${picked}}[$__rate_interval]))" "{{service}}")
      ])
      (selected "Time stalled on memory" "percent" [
        (q "sum by (service) (rate(container_pressure_memory_stalled_seconds_total{${picked}}[$__rate_interval])) * 100" "{{service}}")
      ])
    ])
  ];
}
