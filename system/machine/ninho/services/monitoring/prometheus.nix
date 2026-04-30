# Prometheus server config + scrapeConfigs.
# The exporter attrset lives in ./exporters.nix; module merging combines them.
{ constants, ... }:
{
  services.prometheus = {
    enable = true;
    port = constants.ports.prometheus;

    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [
          {
            targets = [ "localhost:9100" ];
          }
        ];
      }
      {
        job_name = "nvidia";
        static_configs = [
          {
            targets = [ "localhost:9835" ];
          }
        ];
      }
      {
        job_name = "postgresql";
        static_configs = [
          {
            targets = [ "localhost:9187" ];
          }
        ];
      }
      {
        job_name = "zfs";
        static_configs = [
          {
            targets = [ "localhost:9134" ];
          }
        ];
      }
      {
        job_name = "smartctl";
        static_configs = [
          {
            targets = [ "localhost:9633" ];
          }
        ];
      }
      {
        job_name = "systemd";
        static_configs = [
          {
            targets = [ "localhost:9558" ];
          }
        ];
      }
      {
        job_name = "scaphandre";
        # scaphandre serves OpenMetrics 0.0.1 by default; force text fallback
        fallback_scrape_protocol = "PrometheusText0.0.4";
        static_configs = [
          {
            targets = [ "localhost:9606" ];
          }
        ];
      }
      {
        job_name = "prowlarr";
        static_configs = [
          {
            targets = [ "localhost:9708" ];
          }
        ];
      }
      {
        job_name = "radarr";
        static_configs = [
          {
            targets = [ "localhost:9709" ];
          }
        ];
      }
      {
        job_name = "sonarr";
        static_configs = [
          {
            targets = [ "localhost:9710" ];
          }
        ];
      }
      {
        job_name = "lidarr";
        static_configs = [
          {
            targets = [ "localhost:9711" ];
          }
        ];
      }
      {
        job_name = "readarr";
        static_configs = [
          {
            targets = [ "localhost:9712" ];
          }
        ];
      }
      {
        job_name = "deluge";
        static_configs = [
          {
            targets = [ "localhost:9713" ];
          }
        ];
      }
    ];
  };
}
