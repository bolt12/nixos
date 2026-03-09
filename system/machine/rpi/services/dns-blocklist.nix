{ pkgs, lib, ... }:

let
  blocklistUrl = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/rpz/pro.txt";
  blocklistPath = "/var/lib/unbound/hagezi-pro.rpz";

  updateScript = pkgs.writeShellScript "update-dns-blocklist" ''
    set -uo pipefail

    TEMP_DOWNLOAD="${blocklistPath}.download"

    log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

    log "Downloading Hagezi Pro RPZ blocklist..."
    if ! curl -sSf -o "$TEMP_DOWNLOAD" --max-time 120 "${blocklistUrl}"; then
      log "ERROR: Download failed — keeping existing blocklist"
      rm -f "$TEMP_DOWNLOAD"
      exit 1
    fi

    line_count=$(grep -cvE '^\s*(;|$)' "$TEMP_DOWNLOAD" || true)
    if [ "$line_count" -lt 1000 ]; then
      log "ERROR: Downloaded list has only $line_count entries (expected >1000) — keeping existing blocklist"
      rm -f "$TEMP_DOWNLOAD"
      exit 1
    fi

    mv "$TEMP_DOWNLOAD" "${blocklistPath}"
    log "Blocklist updated: $line_count entries"

    if unbound-control reload 2>/dev/null; then
      log "Unbound reloaded successfully"
    else
      log "WARN: unbound-control reload failed — Unbound will pick up changes on next restart"
    fi
  '';
in
{
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
        User = "bolt";
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
        User = "bolt";
        RemainAfterExit = true;
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
}
