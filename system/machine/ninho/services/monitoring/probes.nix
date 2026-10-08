# Blackbox probes: is each service answering, can the box still unlock itself
# at boot, do the resolvers resolve, is the uplink there.
{
  constants,
  lib,
  pkgs,
  ...
}:
let
  inherit (constants) network ports;

  # Entries in constants.ports that are not an HTTP service on this host:
  # nothing listens on the first two, Tang is on the RPi, and the last two are
  # the monitoring plumbing itself, already covered by `up`.
  notProbed = [
    "filebrowser"
    "comfy-ui"
    "tang"
    "cadvisor"
    "blackbox"
  ];

  probe = kind: module: name: target: {
    inherit
      kind
      module
      name
      target
      ;
  };

  probes =
    lib.mapAttrsToList (
      name: port: probe "service" "http_responding" name "http://localhost:${toString port}/"
    ) (removeAttrs ports notProbed)
    ++ [
      # Clevis fetches this at boot to unlock LUKS; if it is gone the next
      # unattended reboot stops at the passphrase prompt.
      (probe "boot" "tang_adv" "tang" "http://${network.rpi.lanIp}:${toString ports.tang}/adv")
      # Every tailnet node logs in here, and the probe reads its certificate.
      (probe "tailnet" "http_2xx" "headscale" "${network.headscale.url}/health")
      (probe "dns" "dns_resolves" "rpi-resolver" "${network.rpi.lanIp}:53")
      (probe "dns" "dns_resolves" "hub-resolver" "${network.hub.vpnIp}:53")
      (probe "ping" "icmp" "gateway" network.lan.gateway)
      (probe "ping" "icmp" "rpi" network.rpi.lanIp)
      (probe "ping" "icmp" "hub" network.hub.vpnIp)
      (probe "ping" "icmp" "internet" "1.1.1.1")
    ];

  modules = {
    # Any answer short of a server error counts as alive: half of these
    # redirect to a login page and a few answer 404 on `/`.
    http_responding = {
      prober = "http";
      http = {
        preferred_ip_protocol = "ip4";
        follow_redirects = false;
        valid_status_codes = [
          200
          204
          301
          302
          303
          307
          308
          400
          401
          403
          404
          405
        ];
      };
    };
    http_2xx = {
      prober = "http";
      http.preferred_ip_protocol = "ip4";
    };
    tang_adv = {
      prober = "http";
      http = {
        preferred_ip_protocol = "ip4";
        fail_if_body_not_matches_regexp = [ "\"payload\"" ];
      };
    };
    dns_resolves = {
      prober = "dns";
      dns = {
        query_name = "nixos.org";
        query_type = "A";
        preferred_ip_protocol = "ip4";
        valid_rcodes = [ "NOERROR" ];
      };
    };
    icmp = {
      prober = "icmp";
      icmp.preferred_ip_protocol = "ip4";
    };
  };
in
{
  services.prometheus.exporters.blackbox = {
    enable = true;
    port = ports.blackbox;
    listenAddress = "127.0.0.1";
    configFile = (pkgs.formats.yaml { }).generate "blackbox.yml" { inherit modules; };
  };

  services.prometheus.scrapeConfigs = [
    {
      job_name = "blackbox";
      metrics_path = "/probe";
      static_configs = map (p: {
        targets = [ p.target ];
        labels = {
          __param_module = p.module;
          probe = p.name;
          inherit (p) kind;
        };
      }) probes;
      # The usual blackbox indirection: the listed address becomes the
      # `target` query parameter and the scrape goes to the exporter.
      relabel_configs = [
        {
          source_labels = [ "__address__" ];
          target_label = "__param_target";
        }
        {
          source_labels = [ "__param_target" ];
          target_label = "instance";
        }
        {
          target_label = "__address__";
          replacement = "localhost:${toString ports.blackbox}";
        }
      ];
    }
  ];
}
