# Storage: pools, datasets, the drives underneath, IO and the ARC.
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

  gib = n: n * 1024 * 1024 * 1024;

  # Whole drives only: partitions, device-mapper and zvols repeat the same IO.
  drives = ''device=~"nvme[0-9]+n[0-9]+|sd[a-z]+"'';
  perDrive =
    title: unit: expr:
    timeseries {
      inherit title unit;
      targets = [ (q expr "{{device}}") ];
      many = true;
      min = 0;
    };

  smartRaw =
    name:
    ''sum by (device) (smartctl_device_attribute{attribute_name="${name}",attribute_value_type="raw"})'';

  arcRate = counter: "rate(node_zfs_arc_${counter}[$__rate_interval])";
in
d.dashboard {
  uid = "storage";
  title = "Storage";
  description = "ZFS pools and datasets, drive health and temperature, IO latency and the ARC.";
  from = "now-24h";
  rows = [
    (row null [
      (tile {
        title = "rpool";
        expr = ''zfs_pool_health{pool="rpool"}'';
        states = d.mappings.poolHealth;
      })
      (tile {
        title = "storage";
        expr = ''zfs_pool_health{pool="storage"}'';
        states = d.mappings.poolHealth;
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
        title = "rpool fragmented";
        expr = ''zfs_pool_fragmentation_ratio{pool="rpool"} * 100'';
        unit = "percent";
        decimals = 0;
        limits = thresholds.above 70 85;
        desc = "Fragmentation of free space. High values on a nearly full pool slow every write.";
      })
      (tile {
        title = "storage used";
        expr = ''zfs_pool_allocated_bytes{pool="storage"} / zfs_pool_size_bytes{pool="storage"} * 100'';
        unit = "percent";
        decimals = 0;
        limits = thresholds.above 80 90;
      })
      (tile {
        title = "Hottest HDD";
        expr = "max(${promql.hddTemperature})";
        unit = "celsius";
        limits = thresholds.above 50 60;
      })
      (tile {
        title = "Bad sectors";
        expr = ''sum(smartctl_device_attribute{attribute_value_type="raw",attribute_name=~"Reallocated_Sector_Ct|Current_Pending_Sector|Offline_Uncorrectable"})'';
        limits = thresholds.zero;
        desc = "Reallocated, pending and uncorrectable sectors across the hard drives.";
      })
      (tile {
        title = "ARC hit rate";
        expr = "${arcRate "hits"} / (${arcRate "hits"} + ${arcRate "misses"}) * 100";
        unit = "percent";
        decimals = 1;
        spark = true;
      })
    ])

    (row "Space" [
      (d.bars {
        title = "Data held by each dataset";
        targets = [
          (q ''sort_desc(zfs_dataset_used_by_dataset_bytes{type="filesystem"} > 1e9)'' "{{name}}")
        ];
        unit = "bytes";
        h = 8;
        desc = "Live data only, snapshots excluded.";
      })
      (d.bars {
        title = "Space held by snapshots";
        targets = [ (q "sort_desc(zfs_dataset_used_by_snapshots_bytes > 1e9)" "{{dataset}}") ];
        unit = "bytes";
        h = 8;
        desc = "What destroying every snapshot of the dataset would free.";
      })
      (timeseries {
        title = "rpool usable space";
        targets = [ (q ''node_filesystem_avail_bytes{mountpoint="/"}'' "") ];
        unit = "bytes";
        min = 0;
        limits = thresholds.below (gib 75) (gib 30);
        w = 8;
      })
      (timeseries {
        title = "rpool datasets";
        targets = [ (q ''zfs_dataset_used_bytes{pool="rpool",name=~"rpool/.+"}'' "{{name}}") ];
        unit = "bytes";
        stack = true;
        many = true;
        min = 0;
        w = 8;
        desc = "Data plus snapshots, and for rpool/reserved its reservation.";
      })
      (timeseries {
        title = "Change in rpool over the previous 24h";
        targets = [ (q ''delta(zfs_pool_allocated_bytes{pool="rpool"}[1d])'' "") ];
        unit = "bytes";
        w = 8;
        desc = "Free space on this pool swings by hundreds of GiB as snapshots expire, so a days-until-full forecast would be noise. This is the measured daily change.";
      })
    ])

    (row "Drives" [
      (d.table {
        title = "Health";
        key = "device";
        keyTitle = "Drive";
        h = 8;
        columns = [
          {
            name = "SMART";
            expr = "max by (device) (smartctl_device_smart_status)";
            states = d.mappings.okFailed;
          }
          {
            name = "Temperature";
            expr = ''max by (device) (smartctl_device_temperature{temperature_type="current"})'';
            unit = "celsius";
          }
          {
            name = "Powered on";
            expr = "max by (device) (smartctl_device_power_on_seconds) / 31557600";
            unit = "suffix: y";
            decimals = 1;
          }
          {
            name = "Reallocated";
            expr = smartRaw "Reallocated_Sector_Ct";
            limits = thresholds.zero;
          }
          {
            name = "Pending";
            expr = smartRaw "Current_Pending_Sector";
            limits = thresholds.zero;
          }
          {
            name = "CRC errors";
            expr = smartRaw "UDMA_CRC_Error_Count";
            limits = d.steps [
              [
                null
                d.status.neutral
              ]
              [
                1
                d.status.warning
              ]
            ];
          }
          {
            name = "NVMe wear";
            expr = "max by (device) (smartctl_device_percentage_used)";
            unit = "percent";
            meter = {
              min = 0;
              max = 100;
            };
          }
          {
            name = "Written";
            expr = "max by (device) (smartctl_device_bytes_written)";
            unit = "bytes";
          }
        ];
        desc = "CRC errors are counted on the SATA link, so a non-zero value points at the cable or port and not at the platters.";
      })
      (timeseries {
        title = "Temperature";
        targets = [ (q ''smartctl_device_temperature{temperature_type="current"}'' "{{device}}") ];
        unit = "celsius";
        many = true;
        limits = thresholds.above 50 60;
        desc = "The lines at 50 and 60 are the alert thresholds for the hard drives.";
      })
      (timeseries {
        title = "Written per day";
        targets = [ (q "increase(smartctl_device_bytes_written[1d])" "{{device}}") ];
        unit = "bytes";
        many = true;
        min = 0;
      })
    ])

    (row "IO" [
      (perDrive "Read throughput" "Bps" "rate(node_disk_read_bytes_total{${drives}}[$__rate_interval])")
      (perDrive "Write throughput" "Bps"
        "rate(node_disk_written_bytes_total{${drives}}[$__rate_interval])"
      )
      (perDrive "Read latency" "s"
        "rate(node_disk_read_time_seconds_total{${drives}}[$__rate_interval]) / rate(node_disk_reads_completed_total{${drives}}[$__rate_interval])"
      )
      (perDrive "Write latency" "s"
        "rate(node_disk_write_time_seconds_total{${drives}}[$__rate_interval]) / rate(node_disk_writes_completed_total{${drives}}[$__rate_interval])"
      )
      (perDrive "Time busy" "percent"
        "rate(node_disk_io_time_seconds_total{${drives}}[$__rate_interval]) * 100"
      )
      (perDrive "Requests queued" "short"
        "rate(node_disk_io_time_weighted_seconds_total{${drives}}[$__rate_interval])"
      )
    ])

    (row "ARC" [
      (timeseries {
        title = "Size against its target";
        targets = [
          (q "node_zfs_arc_size" "size")
          (q "node_zfs_arc_c" "target")
          (q "node_zfs_arc_c_max" "ceiling")
        ];
        unit = "bytes";
        min = 0;
        w = 8;
        desc = "The target shrinks when the rest of the system wants memory.";
      })
      (timeseries {
        title = "Hit rate";
        targets = [ (q "${arcRate "hits"} / (${arcRate "hits"} + ${arcRate "misses"}) * 100" "") ];
        unit = "percent";
        max = 100;
        w = 8;
      })
      (timeseries {
        title = "Recently used against frequently used";
        targets = [
          (q "node_zfs_arc_mru_size" "recent")
          (q "node_zfs_arc_mfu_size" "frequent")
        ];
        unit = "bytes";
        stack = true;
        min = 0;
        w = 8;
      })
    ])
  ];
}
