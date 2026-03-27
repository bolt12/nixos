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

  };
}
