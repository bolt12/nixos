# Gatus — declarative status monitor with built-in status page.
# Replaces uptime-kuma (whose sqlite-only data model fought config-as-code).
# All endpoints, conditions, and alerts live in this file.
{ constants, ... }:
let
  inherit (constants) network ports;
  ninho = network.ninho.vpnIp;
  rpiLan = network.rpi.lanIp;
  http = url: "http://${url}";

  okStatus = [ "[STATUS] == 200" ];
  okOrRedirect = [ "[STATUS] == any(200, 302)" ];
  okPing = [ "[CONNECTED] == true" ];

  ep =
    group: name: cond: extra:
    {
      inherit name group;
      interval = "60s";
      conditions = cond;
      alerts = [ { type = "ntfy"; } ];
    }
    // extra;

  httpEp =
    group: name: port:
    ep group name okStatus { url = http "${ninho}:${toString port}"; };

  # Same as httpEp but the URL path is custom — for services exposing a
  # cheap healthcheck endpoint (e.g. /health, /-/healthy, /api/server/ping).
  # Probes a tiny response instead of the full SPA bundle on `/`.
  healthEp =
    group: name: port: path:
    ep group name okStatus { url = http "${ninho}:${toString port}${path}"; };

  # Same as httpEp but tolerates a 302 (services whose root redirects to
  # /login or similar). Used for Nextcloud, Open WebUI, CoolerControl.
  httpEpOrRedirect =
    group: name: port:
    ep group name okOrRedirect { url = http "${ninho}:${toString port}"; };

  pingEp =
    group: name: target:
    ep group name okPing { url = "icmp://${target}"; };

  # 5-minute interval for low-volatility services (rarely fail; loud
  # alerting on transient blips is worse than slower detection).
  slowInterval = { interval = "5m"; };
in
{
  services.gatus = {
    enable = true;
    openFirewall = true;
    settings = {
      web = {
        port = ports.gatus;
        address = "0.0.0.0";
      };
      ui = {
        title = "Ninho";
        description = "Home server services";
        header = "Ninho";
      };
      storage = {
        type = "sqlite";
        path = "/var/lib/gatus/data.db";
      };
      alerting.ntfy = {
        url = "http://localhost:${toString ports.ntfy}";
        topic = "uptime-alerts";
        priority = 4;
        default-alert = {
          enabled = true;
          send-on-resolved = true;
          failure-threshold = 3;
          success-threshold = 2;
        };
      };
      endpoints = [
        # Infrastructure ----------------------------------------------------
        (pingEp "Infrastructure" "Internet (1.1.1.1)" "1.1.1.1")
        (pingEp "Infrastructure" "LAN gateway" network.lan.gateway)
        (pingEp "Infrastructure" "RPi (LAN)" rpiLan)
        (pingEp "Infrastructure" "WireGuard peer (RPi VPN)" network.rpi.vpnIp)
        (ep "Infrastructure" "Tang advertise" okStatus {
          url = http "${rpiLan}:7654/adv";
        })
        # DNS-probe variant — doesn't require an HTTPS server at the DDNS
        # name; just confirms the A record resolves via 1.1.1.1.
        (ep "Infrastructure" "DDNS resolves"
          [
            "[DNS_RCODE] == NOERROR"
            "[BODY] != \"\""
          ]
          {
            url = "1.1.1.1";
            dns = {
              query-name = network.rpi.hostname;
              query-type = "A";
            };
            interval = "5m";
          }
        )
        (healthEp "Infrastructure" "Prometheus" ports.prometheus "/-/healthy")

        # Media -------------------------------------------------------------
        (healthEp "Media" "Jellyfin" ports.jellyfin "/health")
        (httpEp "Media" "Navidrome" ports.navidrome)
        (healthEp "Media" "Immich" ports.immich "/api/server/ping")
        (httpEp "Media" "Kavita" ports.kavita)
        (httpEp "Media" "Emanote" ports.emanote)
        (httpEp "Media" "Memos" ports.memos)

        # Media Automation --------------------------------------------------
        (httpEp "Media Automation" "Sonarr" ports.sonarr)
        (httpEp "Media Automation" "Radarr" ports.radarr)
        (httpEp "Media Automation" "Lidarr" ports.lidarr)
        (httpEp "Media Automation" "Readarr" ports.readarr)
        (httpEp "Media Automation" "Prowlarr" ports.prowlarr)
        (httpEp "Media Automation" "Bazarr" ports.bazarr)
        (httpEp "Media Automation" "Bitmagnet" ports.bitmagnet)
        (httpEp "Media Automation" "Deluge" ports.deluge)
        (httpEp "Media Automation" "Jellyseerr" ports.jellyseerr)

        # Cloud -------------------------------------------------------------
        (httpEpOrRedirect "Cloud" "Nextcloud" ports.nextcloud)
        (httpEp "Cloud" "Syncthing" ports.syncthing)
        (httpEp "Cloud" "Atuin" ports.atuin)
        ((httpEp "Cloud" "Attic" ports.attic) // slowInterval)

        # AI ----------------------------------------------------------------
        (httpEp "AI" "llama-swap" ports.llamaswap)
        (httpEpOrRedirect "AI" "Open WebUI" ports.open-webui)

        # Reading & Notifications -------------------------------------------
        (httpEp "Reading & Notifications" "Ntfy" ports.ntfy)
        (httpEp "Reading & Notifications" "Miniflux" ports.miniflux)
        # Body assertion catches "process up but Reddit-blocked" (200 + error
        # body shaped like "RSS is disabled" / "Failed to parse").
        (ep "Reading & Notifications" "Redlib"
          [
            "[STATUS] == 200"
            "[BODY] != pat(*RSS is disabled*)"
            "[BODY] != pat(*Failed to parse page JSON*)"
          ]
          {
            url = http "${ninho}:${toString ports.redlib}/r/popular";
          }
        )

        # Tools -------------------------------------------------------------
        (httpEp "Tools" "Homepage" ports.homepage)
        (healthEp "Tools" "Grafana" ports.grafana "/api/health")
        (httpEp "Tools" "Home Assistant" ports.home-assistant)
        ((httpEpOrRedirect "Tools" "CoolerControl" ports.coolercontrol) // slowInterval)
        # Anki-Sync's root POST-only handler returns 400 on GET — but that
        # 400 is itself proof the protocol handler is alive.
        (ep "Tools" "Anki Sync" [ "[STATUS] == any(200, 400)" ] {
          url = http "${ninho}:${toString ports.anki-sync-server}";
          interval = "5m";
        })
      ];
    };
  };
}
