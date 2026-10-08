# Media & Downloads: the *arr libraries, what they are complaining about, the
# indexers behind them, Deluge and Bitmagnet.
{ d, ... }:
let
  inherit (d)
    q
    row
    stat
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

  count =
    title: expr:
    tile {
      inherit title expr;
      decimals = 0;
    };

  # A queue metric only exists while something is queued.
  queued = metric: "sum(${metric}) or vector(0)";

  # Prowlarr reports lifetime totals per indexer.
  indexer24h = counter: "sum by (indexer) (increase(prowlarr_indexer_${counter}_total[1d]))";

  librarySizes = [
    (q "radarr_movie_filesize_total" "movies")
    (q "sonarr_series_filesize_bytes" "series")
    (q "lidarr_artists_filesize_bytes" "music")
    (q "readarr_author_filesize_bytes" "books")
  ];

  payload =
    direction: "rate(deluge_libtorrent_net_${direction}_payload_bytes_total[$__rate_interval]) * 8";
in
d.dashboard {
  uid = "media";
  title = "Media & Downloads";
  description = "Library counts and growth, health issues reported by the *arr apps, indexer status, Deluge and Bitmagnet.";
  from = "now-24h";
  rows = [
    (row null [
      (count "Movies" "radarr_movie_downloaded_total")
      (count "Episodes" "sonarr_episode_downloaded_total")
      (count "Albums" "lidarr_albums_total")
      (count "Books" "readarr_book_downloaded_total")
      (tile {
        title = "Queued downloads";
        expr = "${queued "radarr_queue_total"} + ${queued "sonarr_queue_total"}";
        decimals = 0;
      })
      (tile {
        title = "Health issues";
        expr = ''count({__name__=~".+_system_health_issues",source!="UpdateCheck"}) or vector(0)'';
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
        desc = "Problems the *arr apps report about themselves. Update notices are left out: NixOS does the updating.";
      })
      (tile {
        title = "Indexers down";
        expr = "count(prowlarr_indexer_unavailable == 1) or vector(0)";
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
      })
      (tile {
        title = "Torrents";
        expr = ''max(deluge_torrents{state="total"})'';
        decimals = 0;
      })
    ])

    (row "What the apps are complaining about" [
      (d.labelTable {
        title = "Health issues";
        expr = ''{__name__=~".+_system_health_issues",source!="UpdateCheck"}'';
        labels = [
          "job"
          "type"
          "message"
        ];
        widths = {
          job = 110;
          type = 100;
        };
        h = 11;
        desc = "Straight from each app's System > Status page.";
      })
    ])

    (row "Indexers" [
      (d.table {
        title = "Prowlarr indexers";
        key = "indexer";
        keyTitle = "Indexer";
        sortBy = "Queries, 24h";
        w = 14;
        h = 11;
        columns = [
          {
            name = "State";
            expr = "max by (indexer) (prowlarr_indexer_unavailable) or max by (indexer) (prowlarr_indexer_queries_total * 0)";
            states = d.mapValues {
              "0" = [
                "ok"
                d.status.neutral
              ];
              "1" = [
                "DOWN"
                d.status.warning
              ];
            };
          }
          {
            name = "Queries, 24h";
            expr = indexer24h "queries";
            decimals = 0;
          }
          {
            name = "Failed, 24h";
            expr = indexer24h "failed_queries";
            decimals = 0;
          }
          {
            name = "Grabs, 24h";
            expr = indexer24h "grabs";
            decimals = 0;
          }
          {
            name = "Response";
            expr = "max by (indexer) (prowlarr_indexer_average_response_time_ms)";
            unit = "ms";
            decimals = 0;
          }
        ];
      })
      (timeseries {
        title = "Queries per hour";
        targets = [
          (q "sum(increase(prowlarr_indexer_queries_total[1h]))" "sent")
          (q "sum(increase(prowlarr_indexer_failed_queries_total[1h]))" "failed")
        ];
        min = 0;
        w = 10;
        h = 11;
      })
    ])

    (row "Library" [
      (d.bars {
        title = "Size on disk";
        targets = librarySizes;
        unit = "bytes";
        w = 8;
        h = 7;
      })
      (timeseries {
        title = "Growth";
        targets = librarySizes;
        unit = "bytes";
        min = 0;
        w = 8;
        h = 7;
      })
      (d.bars {
        title = "Wanted and missing";
        targets = [
          (q "radarr_movie_missing_total" "movies")
          (q "sonarr_episode_missing_total" "episodes")
          (q "lidarr_albums_missing_total" "albums")
          (q "readarr_book_missing_total" "books")
        ];
        decimals = 0;
        w = 8;
        h = 7;
      })
    ])

    (row "Deluge" [
      (d.bars {
        title = "Torrents by state";
        targets = [ (q ''sort_desc(deluge_torrents{state!="total"})'' "{{state}}") ];
        decimals = 0;
        w = 8;
        desc = "States overlap: a seeding torrent is also active while it uploads.";
      })
      (timeseries {
        title = "Transfer rate";
        targets = [
          (q (payload "recv") "download")
          (q (payload "sent") "upload")
        ];
        unit = "bps";
        min = 0;
        w = 8;
        h = 6;
      })
      (timeseries {
        title = "Peers connected";
        targets = [ (q "deluge_libtorrent_peer_num_peers_connected" "") ];
        min = 0;
        w = 5;
        h = 6;
      })
      (stat {
        title = "Reachable from outside";
        expr = "deluge_libtorrent_net_has_incoming_connections";
        states = d.mapValues {
          "1" = [
            "YES"
            d.status.good
          ];
          "0" = [
            "NO"
            d.status.warning
          ];
        };
        w = 3;
        h = 6;
        desc = "Whether any peer has connected in. NO means the listening port is not forwarded.";
      })
    ])

    (row "Bitmagnet" [
      (timeseries {
        title = "Torrents indexed per hour";
        targets = [
          (q "sum by (entity) (increase(bitmagnet_dht_crawler_persisted_total[1h]))" "{{entity}}")
        ];
        many = true;
        min = 0;
        w = 8;
      })
      (timeseries {
        title = "Jobs queued";
        targets = [ (q "sum by (queue, status) (bitmagnet_queue_jobs_total)" "{{queue}} {{status}}") ];
        many = true;
        min = 0;
        w = 8;
      })
      (timeseries {
        title = "DHT routing table";
        targets = [ (q "bitmagnet_dht_ktable_nodes_count" "") ];
        min = 0;
        w = 8;
      })
    ])
  ];
}
