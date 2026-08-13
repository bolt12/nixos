# =============================================================================
# Shared adblocking recursive DNS: unbound + Hagezi Pro RPZ blocklist.
# =============================================================================
#
# One definition, two importers:
#   - RPi  (LAN resolver): binds 0.0.0.0, allows the LAN, runs as `bolt`.
#   - Hetzner hub (tunnel resolver): binds the wg0 address only, refuse-by-
#     default ACL, runs as `unbound`.
#
# The machine-specific bits (listen interfaces, access-control, service user,
# ip-freebind) are the only knobs; everything else (hardening, cache sizing,
# the RPZ block, and the daily blocklist updater) is identical on both hosts.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.adblockDns;

  # hagezi migrated distribution to release tags in Aug 2026; the old
  # raw.githubusercontent.com/.../main/rpz/pro.txt path (and the whole main
  # branch raw) now 404s. jsDelivr `@latest` resolves to the newest release
  # tag, which carries the RPZ files.
  blocklistUrl = "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/rpz/pro.txt";
  blocklistPath = "/var/lib/unbound/hagezi-pro.rpz";

  updateScript = pkgs.writeShellScript "update-dns-blocklist" ''
    set -uo pipefail

    TEMP_DOWNLOAD="${blocklistPath}.download"

    log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

    log "Downloading Hagezi Pro RPZ blocklist..."
    if ! curl -sSf -o "$TEMP_DOWNLOAD" --max-time 120 "${blocklistUrl}"; then
      log "ERROR: Download failed, keeping existing blocklist"
      rm -f "$TEMP_DOWNLOAD"
      exit 1
    fi

    line_count=$(grep -cvE '^\s*(;|$)' "$TEMP_DOWNLOAD" || true)
    if [ "$line_count" -lt 1000 ]; then
      log "ERROR: Downloaded list has only $line_count entries (expected >1000), keeping existing blocklist"
      rm -f "$TEMP_DOWNLOAD"
      exit 1
    fi

    mv "$TEMP_DOWNLOAD" "${blocklistPath}"
    log "Blocklist updated: $line_count entries"

    if unbound-control reload 2>/dev/null; then
      log "Unbound reloaded successfully"
    else
      log "WARN: unbound-control reload failed. Unbound will pick up changes on next restart"
    fi
  '';
in
{
  options.services.adblockDns = {
    enable = lib.mkEnableOption "Hagezi RPZ adblocking recursive DNS via unbound";

    user = lib.mkOption {
      type = lib.types.str;
      default = "unbound";
      description = ''
        User that runs unbound and owns /var/lib/unbound (so the blocklist
        updater, which runs as this user, can write the RPZ zonefile).
      '';
    };

    interfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      example = [
        "100.64.0.5"
        "127.0.0.1"
      ];
      description = ''
        Addresses unbound listens on. A public host MUST list only its VPN
        address + loopback (never 0.0.0.0) to avoid becoming an open resolver.
      '';
    };

    accessControl = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      example = [
        "0.0.0.0/0 refuse"
        "100.64.0.0/10 allow"
      ];
      description = "unbound access-control entries (order matters; refuse-by-default recommended for public hosts).";
    };

    allowlist = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "example.ddns.net" ];
      description = ''
        Hostnames exempted from the RPZ blocklist and resolved normally. Use for
        dynamic-DNS names (e.g. the Headscale control host) that a blocklist may
        otherwise catch. Rendered as `local-zone: "<name>." always_transparent`,
        which takes precedence over the RPZ.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.unbound = {
      enable = true;
      inherit (cfg) user;
      settings = {
        server = {
          module-config = ''"respip validator iterator"'';
          # Logging: production settings (use unbound-control to enable debug temporarily)
          verbosity = 0;
          log-queries = "no";
          log-servfail = "yes";

          # Stale/expired record serving (RFC 8767)
          serve-expired = "yes";
          serve-expired-ttl = 86400;
          serve-expired-client-timeout = 1800;

          # Network (listen interfaces are machine-specific)
          interface = cfg.interfaces;
          do-ip4 = "yes";
          do-udp = "yes";
          do-tcp = "yes";
          so-reuseport = "yes";
          so-rcvbuf = "1m";
          so-sndbuf = "1m";
          edns-buffer-size = "1232";

          # Security hardening
          harden-glue = "yes";
          harden-dnssec-stripped = "yes";
          harden-below-nxdomain = "yes";
          harden-algo-downgrade = "yes";
          harden-large-queries = "yes";
          use-caps-for-id = "yes";
          aggressive-nsec = "yes";
          val-clean-additional = "yes";
          deny-any = "yes";
          unwanted-reply-threshold = 10000;

          # Privacy
          hide-identity = "yes";
          hide-version = "yes";
          qname-minimisation = "yes";

          # Performance
          num-threads = 1;
          prefetch = "yes";
          prefetch-key = "yes";
          minimal-responses = "yes";
          rrset-roundrobin = "yes";

          # Cache sizing
          msg-cache-size = "8m";
          rrset-cache-size = "16m";
          key-cache-size = "8m";
          neg-cache-size = "4m";
          cache-min-ttl = 300;
          cache-max-ttl = 86400;

          # DNS rebinding protection
          private-address = [
            "192.168.0.0/16"
            "169.254.0.0/16"
            "172.16.0.0/12"
            "10.0.0.0/8"
            "fd00::/8"
            "fe80::/10"
          ];

          access-control = cfg.accessControl;

          # Exempt allowlisted names from the RPZ blocklist. always_transparent
          # resolves them normally and overrides the RPZ, so a dynamic-DNS name
          # we depend on (e.g. the Headscale control host) can't be blocked by a
          # blocklist update on either resolver.
          local-zone = map (h: ''"${h}." always_transparent'') cfg.allowlist;
          # nixpkgs already sets ip-freebind by default, so unbound can bind an
          # address that does not exist yet (e.g. the hub's wg0 address before
          # the tunnel is up). No consumer needs to opt in.
        };

        remote-control = {
          control-enable = true;
        };
        rpz = {
          name = "hagezi-pro";
          zonefile = blocklistPath;
          rpz-action-override = "nxdomain";
          rpz-log = "yes";
          rpz-log-name = "hagezi-pro";
        };
      };
    };

    systemd = {
      timers.dns-blocklist-update = {
        description = "DNS blocklist update timer";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "30s";
          OnCalendar = "daily";
          RandomizedDelaySec = "1h";
          Persistent = true;
        };
      };

      services.dns-blocklist-update = {
        description = "Update Hagezi DNS blocklist for Unbound";
        after = [
          "network-online.target"
          "unbound.service"
        ];
        wants = [ "network-online.target" ];

        # Don't fail deployment if download fails (timer will retry)
        restartIfChanged = false;

        serviceConfig = {
          Type = "oneshot";
          User = cfg.user;
          ExecStart = "${pkgs.bash}/bin/bash ${updateScript}";
          TimeoutStartSec = "300s";

          Environment = "PATH=${
            lib.makeBinPath [
              pkgs.coreutils
              pkgs.curl
              pkgs.gnugrep
              pkgs.unbound-full
            ]
          }";
        };
      };

      # Ensure a valid RPZ zonefile exists before Unbound starts (first boot)
      services.dns-blocklist-seed = {
        description = "Ensure DNS blocklist file exists for Unbound";
        before = [ "unbound.service" ];
        requiredBy = [ "unbound.service" ];

        serviceConfig = {
          Type = "oneshot";
          User = cfg.user;
          RemainAfterExit = true;
          # Create /var/lib/unbound (owned by cfg.user) before the script runs.
          # unbound.service also declares this, but the seed runs *before* it, so
          # on a fresh install the directory would not exist yet and the write
          # would fail, leaving unbound unable to start.
          StateDirectory = "unbound";
        };

        script = ''
          if [ ! -f ${blocklistPath} ]; then
            cat > ${blocklistPath} <<'EOF'
          $ORIGIN rpz.
          $TTL 3600
          @ SOA localhost. root.localhost. 1 14400 3600 86400 3600
            NS localhost.
          EOF
          fi
        '';
      };
    };
  };
}
