# Grafana server, datasource and dashboard provisioning.
# Alert rules and their ntfy routing are in ./alerts.nix.
{
  constants,
  lib,
  pkgs,
  ...
}:
let
  inherit (constants) ports;
  dashboards = import ./dashboards { inherit constants lib pkgs; };
in
{
  # Ensure /etc/secrets/grafana/secret_key exists and is readable by the grafana
  # user (it reads it via the settings file provider). Generates one on first
  # boot if missing; otherwise just fixes ownership/permissions.
  systemd.services.grafana-secret-key = {
    wantedBy = [ "multi-user.target" ];
    before = [ "grafana.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      install -d -m 0750 -o grafana -g grafana /etc/secrets/grafana
      if [ ! -s /etc/secrets/grafana/secret_key ]; then
        ${pkgs.openssl}/bin/openssl rand -base64 32 > /etc/secrets/grafana/secret_key
      fi
      chown grafana:grafana /etc/secrets/grafana/secret_key
      chmod 0400 /etc/secrets/grafana/secret_key
    '';
  };

  systemd.services.grafana = {
    after = [ "grafana-secret-key.service" ];
    requires = [ "grafana-secret-key.service" ];
  };

  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "0.0.0.0";
        http_port = ports.grafana;
        domain = "grafana.ninho.local";
      };
      # 26.05 removed the default for security.secret_key (signs auth cookies).
      # Read it at runtime via Grafana's file provider (keeps it out of the store);
      # generate once: openssl rand -base64 32 > /etc/secrets/grafana/secret_key
      security.secret_key = "$__file{/etc/secrets/grafana/secret_key}";
      unified_alerting.enabled = true;
      # Open on the overview, not on Grafana's welcome page.
      dashboards.default_home_dashboard_path = "${dashboards}/soberan.json";
    };

    provision = {
      enable = true;

      datasources.settings.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          url = "http://localhost:${toString ports.prometheus}";
          isDefault = true;
          uid = "prometheus";
          # The global scrape interval. Grafana sizes $__rate_interval from
          # it; left at its 15s default, rate() windows are too short to hold
          # two samples and graphs come out as scattered dots.
          jsonData.timeInterval = "1m";
        }
      ];

      dashboards.settings.providers = [
        {
          name = "ninho";
          folder = "ninho";
          options.path = dashboards;
        }
      ];
    };
  };
}
