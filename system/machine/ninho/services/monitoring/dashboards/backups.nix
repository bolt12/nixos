# Backups & Snapshots: is there a recent copy, and are the jobs that make
# the copies still running.
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

  newestAge = selector: promql.hoursSince "zfs_snapshot_newest_timestamp_seconds${selector}";

  hoursTile =
    title: expr: warn: crit: desc:
    tile {
      inherit title expr desc;
      unit = "suffix: h";
      decimals = 0;
      limits = thresholds.above warn crit;
    };

  perDataset =
    title: unit: expr:
    timeseries {
      inherit title unit;
      targets = [ (q expr "{{dataset}}") ];
      many = true;
      min = 0;
      w = 8;
    };

  # 1 when a timer's service is in the failed state. systemd unloads an idle
  # one-shot unit, so its state series disappears between runs; the timer is
  # always there and supplies the 0.
  jobFailed =
    selector:
    ''max by (name) (label_replace(systemd_unit_state{state="failed",type="service"}, "name", "$1.timer", "name", "(.+)\\.service") and on (name) systemd_timer_last_trigger_seconds${selector})''
    + " or max by (name) (systemd_timer_last_trigger_seconds${selector} * 0)";

  # The jobs that make or check copies of the data.
  jobs = "syncoid-.*|sanoid|postgres-backup|zfs-scrub|zpool-trim";
in
d.dashboard {
  uid = "backups";
  title = "Backups & Snapshots";
  description = "Age of the newest copy at every tier, snapshot counts and space, and whether the backup jobs ran.";
  from = "now-7d";
  rows = [
    (row null [
      (hoursTile "Home snapshot" (newestAge ''{dataset="rpool/home"}'') 2 3
        "sanoid snapshots rpool/home every hour."
      )
      (hoursTile "Root snapshot" (newestAge ''{dataset="rpool/root"}'') 2 3
        "sanoid snapshots rpool/root every hour."
      )
      (hoursTile "Data snapshot" (newestAge ''{dataset="storage/data"}'') 26 30
        "sanoid snapshots storage/data every day."
      )
      (hoursTile "Home replica" (newestAge ''{dataset="storage/backup/home"}'') 50 54
        "Newest snapshot kept on the HDD pool. The replica keeps dailies only and syncoid starts in the same second as the daily it would send, so 25 to 49 hours is normal."
      )
      (hoursTile "Root replica" (newestAge ''{dataset="storage/backup/root"}'') 50 54
        "Newest snapshot kept on the HDD pool. 25 to 49 hours is normal, for the same reason as the home replica."
      )
      (hoursTile "Postgres dump" (promql.hoursSince "postgres_backup_newest_timestamp_seconds") 26 30
        "pg_dumpall runs nightly at 03:00."
      )
      (tile {
        title = "Dump size";
        expr = "postgres_backup_newest_size_bytes";
        unit = "bytes";
        decimals = 1;
      })
      (tile {
        title = "Backup jobs failed";
        expr = "count((${jobFailed ''{name=~"(${jobs})\\.timer"}''}) == 1) or vector(0)";
        limits = thresholds.zero;
      })
    ])

    (row "Snapshots" [
      (d.table {
        title = "Per dataset";
        key = "dataset";
        keyTitle = "Dataset";
        h = 8;
        columns = [
          {
            name = "Snapshots";
            expr = "sum by (dataset) (zfs_snapshot_count)";
          }
          {
            name = "Newest";
            expr = "max by (dataset) (${promql.hoursSince "zfs_snapshot_newest_timestamp_seconds"})";
            unit = "suffix: h";
            decimals = 0;
          }
          {
            name = "Oldest";
            expr = "max by (dataset) (${promql.daysSince "zfs_snapshot_oldest_timestamp_seconds"})";
            unit = "suffix: d";
            decimals = 0;
          }
          {
            name = "Space held";
            expr = "sum by (dataset) (zfs_dataset_used_by_snapshots_bytes) and on (dataset) zfs_snapshot_count";
            unit = "bytes";
          }
        ];
      })
      (perDataset "Age of the newest snapshot" "suffix: h" (
        promql.hoursSince "zfs_snapshot_newest_timestamp_seconds"
      ))
      (perDataset "Snapshots kept" "short" "zfs_snapshot_count")
      (perDataset "Space held by snapshots" "bytes"
        "zfs_dataset_used_by_snapshots_bytes and on (dataset) zfs_snapshot_count"
      )
    ])

    (row "Jobs" [
      (d.timeline {
        title = "Backup jobs";
        targets = [ (q (jobFailed ''{name=~"(${jobs})\\.timer"}'') "{{name}}") ];
        states = d.mapValues {
          "0" = [
            "ok"
            d.status.good
          ];
          "1" = [
            "FAILED"
            d.status.critical
          ];
        };
        h = 7;
      })
      (d.table {
        title = "Timers";
        key = "name";
        keyTitle = "Timer";
        sortBy = "Last run";
        sortDesc = false;
        w = 12;
        h = 11;
        columns = [
          {
            name = "Last run";
            expr = "max by (name) (${promql.hoursSince "systemd_timer_last_trigger_seconds"})";
            unit = "suffix: h ago";
            decimals = 1;
          }
          {
            name = "Its service";
            expr = jobFailed "";
            states = d.mapValues {
              "0" = [
                "ok"
                d.status.neutral
              ];
              "1" = [
                "FAILED"
                d.status.critical
              ];
            };
          }
        ];
        desc = "Every systemd timer on the box, most recently run first.";
      })
      (timeseries {
        title = "Postgres dump size";
        targets = [ (q "postgres_backup_newest_size_bytes" "") ];
        unit = "bytes";
        min = 0;
        w = 6;
        h = 11;
      })
      (timeseries {
        title = "Dumps kept";
        targets = [ (q "postgres_backup_count" "") ];
        min = 0;
        w = 6;
        h = 11;
        desc = "The backup script keeps 14.";
      })
    ])
  ];
}
