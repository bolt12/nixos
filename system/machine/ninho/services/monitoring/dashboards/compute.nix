# Compute & Thermals: CPU, memory, pressure and heat, and which service is
# responsible for each.
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

  cores = ''count(node_cpu_seconds_total{mode="idle"})'';
  coreBusy = ''100 * (1 - rate(node_cpu_seconds_total{mode="idle"}[$__rate_interval]))'';
  modeShare =
    modes: ''sum(rate(node_cpu_seconds_total{mode=~"${modes}"}[$__rate_interval])) / ${cores} * 100'';

  # Share of wall time in which tasks waited on a resource.
  pressure = metric: "rate(node_pressure_${metric}_seconds_total[$__rate_interval]) * 100";
  pressurePanel =
    title: targets:
    timeseries {
      inherit title targets;
      unit = "percent";
      min = 0;
      w = 8;
      h = 7;
    };

  # Readable sensor names: the label metric names the sensor, the chip
  # metric names the driver.
  namedSensors =
    drivers:
    "(node_hwmon_temp_celsius * on (chip, sensor) group_left (label) node_hwmon_sensor_label)"
    + " * on (chip) group_left (chip_name) node_hwmon_chip_names{chip_name=~\"${drivers}\"}";
in
d.dashboard {
  uid = "compute";
  title = "Compute & Thermals";
  description = "CPU, memory, pressure and temperatures, with the services behind the load.";
  rows = [
    (row null [
      (tile {
        title = "CPU";
        expr = promql.cpuBusy;
        unit = "percent";
        decimals = 0;
        spark = true;
        limits = thresholds.above 80 95;
      })
      (tile {
        title = "Load per core";
        expr = "node_load1 / scalar(${cores})";
        decimals = 2;
        spark = true;
        limits = thresholds.above 1 2;
        desc = "1-minute load average divided by the number of CPUs. Above 1, work is queueing.";
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
        title = "Memory stalls";
        expr = pressure "memory_stalled";
        unit = "percent";
        decimals = 1;
        limits = thresholds.above 5 10;
        desc = "Share of time every runnable task was waiting for memory.";
      })
      (tile {
        title = "OOM kills, 24h";
        expr = "increase(node_vmstat_oom_kill[1d])";
        decimals = 0;
        limits = thresholds.zero;
      })
      (tile {
        title = "CPU temperature";
        expr = promql.cpuTemperature;
        unit = "celsius";
        decimals = 0;
        limits = thresholds.above 85 95;
      })
      (tile {
        title = "VRM temperature";
        expr = ''max(node_hwmon_temp_celsius * on (chip, sensor) group_left () node_hwmon_sensor_label{label="VRM"})'';
        unit = "celsius";
        decimals = 0;
        limits = thresholds.above 90 105;
      })
      (tile {
        title = "Uptime";
        expr = "(node_time_seconds - node_boot_time_seconds) / 86400";
        unit = "suffix: d";
        decimals = 0;
      })
    ])

    (row "CPU" [
      (timeseries {
        title = "CPU time by mode";
        targets = [
          (q (modeShare "user|nice") "user")
          (q (modeShare "system") "system")
          (q (modeShare "iowait") "iowait")
          (q (modeShare "irq|softirq") "interrupts")
        ];
        unit = "percent";
        stack = true;
        min = 0;
      })
      (timeseries {
        title = "Spread across cores";
        targets = [
          (q "max(${coreBusy})" "busiest core")
          (q "avg(${coreBusy})" "average")
          (q "min(${coreBusy})" "idlest core")
        ];
        unit = "percent";
        min = 0;
        max = 100;
        desc = "One busy core with an idle average is a single-threaded job. All three together is a parallel one.";
      })
      (timeseries {
        title = "Load average";
        targets = [
          (q "node_load1" "1 min")
          (q "node_load5" "5 min")
          (q "node_load15" "15 min")
        ];
        min = 0;
        w = 8;
      })
      (timeseries {
        title = "Clock frequency";
        targets = [
          (q "max(node_cpu_scaling_frequency_hertz)" "fastest core")
          (q "avg(node_cpu_scaling_frequency_hertz)" "average")
        ];
        unit = "hertz";
        w = 8;
      })
      (timeseries {
        title = "Context switches and interrupts";
        targets = [
          (q "rate(node_context_switches_total[$__rate_interval])" "context switches")
          (q "rate(node_intr_total[$__rate_interval])" "interrupts")
        ];
        unit = "ops";
        w = 8;
      })
    ])

    (row "Memory" [
      (timeseries {
        title = "Where the memory is";
        targets = [
          (q "node_memory_AnonPages_bytes" "applications")
          (q "node_zfs_arc_size" "ZFS ARC")
          (q "node_memory_Cached_bytes + node_memory_Buffers_bytes" "page cache")
          (q "node_memory_Slab_bytes" "kernel slab")
          (q "node_memory_MemFree_bytes" "free")
        ];
        unit = "bytes";
        stack = true;
        min = 0;
      })
      (timeseries {
        title = "Largest services";
        targets = [ (q (promql.topServiceMemory 10) "{{service}}") ];
        unit = "bytes";
        many = true;
        min = 0;
      })
    ])

    (row "Pressure: time lost waiting" [
      (pressurePanel "CPU" [ (q (pressure "cpu_waiting") "some tasks waiting") ])
      (pressurePanel "Memory" [
        (q (pressure "memory_waiting") "some tasks waiting")
        (q (pressure "memory_stalled") "every task stalled")
      ])
      (pressurePanel "IO" [
        (q (pressure "io_waiting") "some tasks waiting")
        (q (pressure "io_stalled") "every task stalled")
      ])
    ])

    (row "Temperatures" [
      (timeseries {
        title = "Board and CPU";
        targets = [ (q (namedSensors "asusec|k10temp") "{{chip_name}} {{label}}") ];
        unit = "celsius";
        many = true;
        w = 8;
      })
      (timeseries {
        title = "Memory modules";
        targets = [
          # An SPD hub at I2C address 0x50 + n sits in DIMM slot n.
          (q ''label_replace(node_hwmon_temp_celsius * on (chip) group_left () node_hwmon_chip_names{chip_name="spd5118"}, "slot", "$1", "chip", ".*005([0-7])")'' "slot {{slot}}")
        ];
        unit = "celsius";
        many = true;
        w = 8;
      })
      (timeseries {
        title = "Drives";
        targets = [ (q ''smartctl_device_temperature{temperature_type="current"}'' "{{device}}") ];
        unit = "celsius";
        many = true;
        w = 8;
        limits = thresholds.above 50 60;
        desc = "The lines at 50 and 60 are the alert thresholds for the hard drives. NVMe drives run warmer by design.";
      })
    ])

    (row "Who is using it" [
      (timeseries {
        title = "Busiest services, CPU cores";
        targets = [ (q (promql.topServiceCpu 10) "{{service}}") ];
        many = true;
        min = 0;
      })
      (timeseries {
        title = "Services stalled on memory";
        targets = [
          (q (d.topOver 8 "service"
            ''sum by (service) (rate(container_pressure_memory_stalled_seconds_total{service!=""}[$__rate_interval])) * 100''
            ''sum by (service) (rate(container_pressure_memory_stalled_seconds_total{service!=""}[$__range] @ end()))''
          ) "{{service}}")
        ];
        unit = "percent";
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
            name = "CPU cores";
            expr = promql.serviceCpu "5m";
            decimals = 2;
          }
          {
            name = "Disk writes";
            expr = ''sum by (service) (rate(container_fs_writes_bytes_total{service!=""}[5m]))'';
            unit = "Bps";
          }
          {
            name = "OOM kills, 24h";
            expr = ''sum by (service) (increase(container_oom_events_total{service!=""}[1d]))'';
            decimals = 0;
            limits = thresholds.zero;
          }
        ];
      })
    ])
  ];
}
