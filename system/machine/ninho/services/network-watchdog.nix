{ config, pkgs, lib, ... }:

let
  watchdogScript = ../scripts/network-watchdog.sh;
  interface = "enp11s0";
in
{
  # ==========================================================================
  # Network Watchdog — Escalating recovery for RTL8126A r8169 driver failures
  # ==========================================================================

  systemd = {
    # ------------------------------------------------------------------------
    # Watchdog timer — runs every 30s, 60s after boot
    # ------------------------------------------------------------------------
    timers.network-watchdog = {
      description = "Network watchdog timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "60s";
        OnUnitActiveSec = "30s";
        AccuracySec = "5s";
      };
    };

    # ------------------------------------------------------------------------
    # Watchdog service — runs the escalating recovery script
    # ------------------------------------------------------------------------
    services.network-watchdog = {
      description = "Network watchdog for RTL8126A NIC";
      after = [ "network-online.target" "NetworkManager.service" ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash ${watchdogScript}";
        TimeoutStartSec = "60s";
        StateDirectory = "network-watchdog";

        # PATH: tools the script needs
        Environment = "PATH=${lib.makeBinPath [
          pkgs.coreutils
          pkgs.iproute2
          pkgs.iputils
          pkgs.curl
          pkgs.gnugrep
          pkgs.gnused
          pkgs.gawk
          pkgs.kmod
          pkgs.networkmanager
          pkgs.systemd
          pkgs.util-linux
          pkgs.zfs
        ]}";
      };
    };

    # ------------------------------------------------------------------------
    # WoL enable — set Wake-on-LAN at boot for RPi-based remote recovery
    # ------------------------------------------------------------------------
    services.wol-enable = {
      description = "Enable Wake-on-LAN for ${interface}";
      after = [ "NetworkManager-wait-online.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.ethtool}/bin/ethtool -s ${interface} wol g";
      };
    };

    # ------------------------------------------------------------------------
    # Hardware watchdog — sp5100_tco (AMD)
    # ------------------------------------------------------------------------
    watchdog = {
      runtimeTime = "60s";
      rebootTime = "10min";
    };

    # ------------------------------------------------------------------------
    # Preventive reboot — every 6 days at 4 AM, skip if ZFS scrub running
    # ------------------------------------------------------------------------
    timers.preventive-reboot = {
      description = "Preventive reboot to mitigate RTL8126A driver degradation";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        # ~every 6 days: 1st, 7th, 13th, 19th, 25th of each month at 04:00
        OnCalendar = "*-*-01,07,13,19,25 04:00:00";
        RandomizedDelaySec = "10min";
        Persistent = true;
      };
    };

    services.preventive-reboot = {
      description = "Preventive reboot (skip if ZFS scrub in progress)";
      serviceConfig = {
        Type = "oneshot";
        Environment = "PATH=${lib.makeBinPath [ pkgs.zfs pkgs.systemd pkgs.coreutils pkgs.gnugrep pkgs.curl ]}";
      };
      script = ''
        ntfy_url="http://127.0.0.1:8106/network-watchdog"
        if zpool status 2>/dev/null | grep -q "scrub in progress"; then
          echo "ZFS scrub in progress — skipping preventive reboot"
          curl -sf -o /dev/null -H "Title: Preventive Reboot" -H "Priority: default" \
            -d "Preventive reboot skipped — ZFS scrub in progress" "$ntfy_url" 2>/dev/null || true
          exit 0
        fi
        echo "No ZFS scrub running — initiating preventive reboot"
        curl -sf -o /dev/null -H "Title: Preventive Reboot" -H "Priority: high" \
          -d "Preventive reboot starting now (RTL8126A driver hygiene)" "$ntfy_url" 2>/dev/null || true
        sleep 2
        systemctl reboot
      '';
    };
  };
}
