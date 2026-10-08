# Prometheus server and scrape jobs. Exporters are in ./exporters.nix.
{
  config,
  constants,
  lib,
  ...
}:
let
  inherit (constants) ports;
  exporters = config.services.prometheus.exporters;

  # Language-runtime internals that every Go and Python exporter ships and
  # nothing here graphs.
  dropRuntime = {
    source_labels = [ "__name__" ];
    regex = "go_(memstats|gc|sched|threads|info).*|promhttp_.*|python_gc_.*";
    action = "drop";
  };

  keepOnly = regex: {
    source_labels = [ "__name__" ];
    inherit regex;
    action = "keep";
  };

  # One target on this host. `extra` overrides or adds per-job settings.
  job =
    name: port: extra:
    {
      job_name = name;
      static_configs = [ { targets = [ "localhost:${toString port}" ]; } ];
      metric_relabel_configs = [ dropRuntime ];
    }
    // extra;

  llama = config.services.llama-swap.settings;
  usesPortMacro = model: lib.hasInfix "\${PORT}" ((model.cmd or "") + (model.proxy or ""));
  # llama-swap hands out ports from startPort in sorted model order, which is
  # also the order of attrNames. Only llama-server started with --metrics
  # answers on /metrics.
  llamaTargets = lib.pipe llama.models [
    (lib.filterAttrs (_: usesPortMacro))
    lib.attrNames
    (lib.imap0 (
      i: model: {
        inherit model;
        port = llama.startPort + i;
      }
    ))
    (lib.filter (target: lib.hasInfix "--metrics" llama.models.${target.model}.cmd))
  ];
in
{
  services.prometheus = {
    enable = true;
    port = ports.prometheus;

    # A year of history for the wear, growth and cost panels. The size cap is
    # the backstop: the TSDB sits on rpool, which is the small pool.
    retentionTime = "1y";
    extraFlags = [ "--storage.tsdb.retention.size=15GB" ];

    globalConfig.scrape_interval = "1m";

    scrapeConfigs = [
      (job "node" exporters.node.port { })
      # GPU load moves in seconds; a minute between samples hides inference.
      (job "nvidia" exporters.nvidia-gpu.port { scrape_interval = "15s"; })
      (job "postgresql" exporters.postgres.port {
        # pg_settings_* is 268 names and two are read: the connection limit
        # and the buffer size. Mark those, drop the unmarked rest.
        metric_relabel_configs = [
          dropRuntime
          {
            source_labels = [ "__name__" ];
            regex = "pg_settings_(max_connections|shared_buffers_bytes)";
            target_label = "__tmp_keep";
            replacement = "1";
          }
          {
            source_labels = [
              "__name__"
              "__tmp_keep"
            ];
            regex = "pg_settings_.*;";
            action = "drop";
          }
          {
            regex = "__tmp_keep";
            action = "labeldrop";
          }
        ];
      })
      (job "zfs" exporters.zfs.port { })
      (job "smartctl" exporters.smartctl.port { })
      (job "systemd" exporters.systemd.port { })
      (job "prowlarr" exporters.exportarr-prowlarr.port { })
      (job "radarr" exporters.exportarr-radarr.port { })
      (job "sonarr" exporters.exportarr-sonarr.port { })
      (job "lidarr" exporters.exportarr-lidarr.port { })
      (job "readarr" exporters.exportarr-readarr.port { })
      (job "deluge" exporters.deluge.port { })

      (job "cadvisor" ports.cadvisor {
        metric_relabel_configs = [
          (keepOnly "container_(cpu_usage_seconds_total|memory_(working_set_bytes|rss|cache)|fs_(reads|writes)_bytes_total|oom_events_total|pressure_(cpu_waiting|memory_stalled|io_stalled)_seconds_total)")
          # Services, their template instances, containers and whole users.
          # Session and tmux scopes under a user come and go all day.
          {
            source_labels = [ "id" ];
            regex = "/|/system\\.slice/(system-[^/]+\\.slice/)?[^/]+\\.(service|scope)|/user\\.slice/user-[0-9]+\\.slice";
            action = "keep";
          }
          # `service` is the unit name for a service, `user-<uid>` for a user
          # slice, and the container name for anything Docker started.
          {
            source_labels = [ "id" ];
            regex = "/system\\.slice/(?:system-[^/]+\\.slice/)?(.+)\\.service";
            target_label = "service";
          }
          {
            source_labels = [ "id" ];
            regex = "/user\\.slice/(user-[0-9]+)\\.slice";
            target_label = "service";
          }
          {
            source_labels = [ "name" ];
            regex = "(.+)";
            target_label = "service";
          }
        ];
      })

      # The servers themselves. Both export far more than is worth keeping.
      (job "prometheus" ports.prometheus {
        metric_relabel_configs = [
          (keepOnly "prometheus_(tsdb|rule|notifications|config|build|ready|engine|target_scrapes)_?.*|process_.+|go_goroutines")
        ];
      })
      (job "grafana" ports.grafana {
        metric_relabel_configs = [
          (keepOnly "grafana_(alerting|stat)_.+|grafana_build_info|grafana_http_request_duration_seconds_(count|sum)|process_.+|go_goroutines")
        ];
      })

      # Applications that publish their own metrics.
      (job "frigate" ports.frigate { metrics_path = "/api/metrics"; })
      # Nextcloud stamps samples with the time of its last cached snapshot,
      # which can fall outside the lookback window.
      (job "nextcloud" ports.nextcloud { honor_timestamps = false; })
      (job "syncthing" ports.syncthing { })
      (job "bitmagnet" ports.bitmagnet { })

      # A model's port is only open while llama-swap has it loaded, so a down
      # target here means "not loaded". Going to the port directly, and not
      # through llama-swap's /upstream route, keeps a scrape from loading it.
      {
        job_name = "llama-server";
        scrape_interval = "15s";
        static_configs = map (target: {
          targets = [ "localhost:${toString target.port}" ];
          labels.model = target.model;
        }) llamaTargets;
      }
    ];
  };
}
