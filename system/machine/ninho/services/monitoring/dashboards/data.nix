# Databases & Apps: PostgreSQL, and the two applications that publish their
# own metrics, Nextcloud and Syncthing.
{ d, ... }:
let
  inherit (d)
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

  # template0 and template1 are PostgreSQL's own; the nameless row is shared
  # catalogue activity.
  real = ''datname!~"template.*|"'';
  dbRate = counter: "rate(pg_stat_database_${counter}{${real}}[$__rate_interval])";
  perDatabase =
    title: unit: expr:
    timeseries {
      inherit title unit;
      targets = [ (q expr "{{datname}}") ];
      many = true;
      min = 0;
      w = 8;
    };

  hitRate = "sum(${dbRate "blks_hit"}) / (sum(${dbRate "blks_hit"}) + sum(${dbRate "blks_read"})) * 100";

  folder = scope: type: ''syncthing_model_folder_summary{scope="${scope}",type="${type}"}'';
in
d.dashboard {
  uid = "data";
  title = "Databases & Apps";
  description = "PostgreSQL size, connections, throughput and locks, plus Nextcloud and Syncthing.";
  rows = [
    (row null [
      (tile {
        title = "PostgreSQL";
        expr = "pg_up";
        states = d.mappings.upDown;
      })
      (tile {
        title = "Connections used";
        expr = "sum(pg_stat_activity_count) / scalar(pg_settings_max_connections) * 100";
        unit = "percent";
        decimals = 0;
        limits = thresholds.above 70 85;
        desc = "Of max_connections.";
      })
      (tile {
        title = "All databases";
        expr = "sum(pg_database_size_bytes{${real}})";
        unit = "bytes";
        decimals = 1;
      })
      (tile {
        title = "Transactions";
        expr = "sum(${dbRate "xact_commit"}) + sum(${dbRate "xact_rollback"})";
        unit = "ops";
        decimals = 0;
        spark = true;
      })
      (tile {
        title = "Buffer hit rate";
        expr = hitRate;
        unit = "percent";
        decimals = 1;
        desc = "Share of block reads served from shared buffers in the visible window, not since the server started.";
      })
      (tile {
        title = "Open transaction";
        expr = "max(pg_stat_activity_max_tx_duration)";
        unit = "s";
        limits = thresholds.above 300 3600;
        desc = "Age of the longest-running transaction. One open for hours holds back vacuum.";
      })
      (tile {
        title = "Deadlocks, 24h";
        expr = "sum(increase(pg_stat_database_deadlocks[1d]))";
        decimals = 0;
        limits = thresholds.zero;
      })
      (tile {
        title = "Collectors failing";
        expr = "count(pg_scrape_collector_success == 0) or vector(0)";
        limits = thresholds.zero;
        desc = "Parts of the exporter that cannot read their data, usually for want of a grant.";
      })
    ])

    (row "PostgreSQL" [
      (d.bars {
        title = "Size by database";
        targets = [ (q "sort_desc(pg_database_size_bytes{${real}})" "{{datname}}") ];
        unit = "bytes";
        w = 8;
        h = 8;
      })
      (perDatabase "Connections by database" "short" "sum by (datname) (pg_stat_activity_count{${real}})")
      (timeseries {
        title = "Connections by state";
        targets = [ (q "sum by (state) (pg_stat_activity_count)" "{{state}}") ];
        many = true;
        stack = true;
        min = 0;
        w = 8;
      })
      (perDatabase "Commits" "ops" (dbRate "xact_commit"))
      (perDatabase "Rollbacks" "ops" (dbRate "xact_rollback"))
      (timeseries {
        title = "Rows written";
        targets = [
          (q "sum(${dbRate "tup_inserted"})" "inserted")
          (q "sum(${dbRate "tup_updated"})" "updated")
          (q "sum(${dbRate "tup_deleted"})" "deleted")
        ];
        unit = "ops";
        min = 0;
        w = 8;
      })
      (timeseries {
        title = "Buffer hit rate";
        targets = [ (q hitRate "") ];
        unit = "percent";
        max = 100;
        w = 8;
      })
      (perDatabase "Longest open transaction" "s"
        "max by (datname) (pg_stat_activity_max_tx_duration{${real}})"
      )
      (perDatabase "Temporary files written" "Bps" (dbRate "temp_bytes"))
      (timeseries {
        title = "Locks held, by mode";
        targets = [ (q "sum by (mode) (pg_locks_count) > 0" "{{mode}}") ];
        many = true;
        min = 0;
      })
      (timeseries {
        title = "Checkpoints";
        targets = [
          (q "rate(pg_stat_bgwriter_checkpoints_timed_total[$__rate_interval]) * 3600" "on schedule")
          (q "rate(pg_stat_bgwriter_checkpoints_req_total[$__rate_interval]) * 3600" "forced by WAL volume")
        ];
        unit = "suffix: /h";
        min = 0;
        desc = "Forced checkpoints mean max_wal_size is too small for the write load.";
      })
    ])

    (row "Nextcloud" [
      (tile {
        title = "Maintenance mode";
        expr = "nextcloud_maintenance";
        states = d.mappings.yesNoBad;
      })
      (tile {
        title = "Users";
        expr = "sum(nextcloud_users)";
      })
      (tile {
        title = "Active, last day";
        expr = ''max(nextcloud_active_users{time="Last day"})'';
      })
      (tile {
        title = "Files";
        expr = "sum(nextcloud_files)";
        decimals = 0;
      })
      (tile {
        title = "Shares";
        expr = "sum(nextcloud_shares)";
      })
      (tile {
        title = "Jobs running";
        expr = "sum(nextcloud_running_jobs)";
      })
      (tile {
        title = "Apps enabled";
        expr = "count(nextcloud_app_enabled == 1)";
      })
      (tile {
        title = "Sessions, last hour";
        expr = ''max(nextcloud_active_sessions{time="Last hour"})'';
      })
      (d.bars {
        title = "Most common file types";
        targets = [ (q "sort_desc(topk(12, nextcloud_files))" "{{mimetype}}") ];
        decimals = 0;
        h = 9;
      })
      (timeseries {
        title = "Active users";
        targets = [ (q "nextcloud_active_users" "{{time}}") ];
        many = true;
        min = 0;
        h = 9;
      })
    ])

    (row "Syncthing" [
      (tile {
        title = "Devices connected";
        expr = "count(syncthing_connections_active > 0) or vector(0)";
        w = 4;
      })
      (tile {
        title = "Still to sync";
        expr = "sum(${folder "need" "bytes"})";
        unit = "bytes";
        w = 4;
        desc = "Data this node knows about and does not have yet.";
      })
      (tile {
        title = "Conflicts";
        expr = "sum(syncthing_model_folder_conflicts_total)";
        limits = thresholds.zero;
        w = 4;
        desc = "Files changed on two devices at once since Syncthing started.";
      })
      (tile {
        title = "Files";
        expr = "sum(${folder "local" "files"})";
        decimals = 0;
        w = 4;
      })
      (tile {
        title = "Size on this node";
        expr = "sum(${folder "local" "bytes"})";
        unit = "bytes";
        decimals = 1;
        w = 4;
      })
      (tile {
        title = "Size across the cluster";
        expr = "sum(${folder "global" "bytes"})";
        unit = "bytes";
        decimals = 1;
        w = 4;
      })
      (timeseries {
        title = "Traffic with other devices";
        targets = [
          (q "sum(rate(syncthing_protocol_recv_bytes_total[$__rate_interval])) * 8" "received")
          (q "sum(rate(syncthing_protocol_sent_bytes_total[$__rate_interval])) * 8" "sent")
        ];
        unit = "bps";
        min = 0;
      })
      (timeseries {
        title = "Still to sync, by folder";
        targets = [ (q (folder "need" "bytes") "{{folder}}") ];
        unit = "bytes";
        many = true;
        min = 0;
      })
    ])
  ];
}
