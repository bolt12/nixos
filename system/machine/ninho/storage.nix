# Storage: ZFS pool config, sanoid snapshot policies,
# and the storage directory tmpfiles seeds (root/data/media/backup).
# Coolercontrol seed lives in configuration.nix (different concern).
{ constants, ... }:
{
  services.zfs = {
    # Periodic TRIM (weekly) reclaims freed blocks on the rpool NVMe SSDs.
    # Requires allowDiscards on the rpool LUKS devices (boot.nix) to actually
    # reach the drives; it is a harmless no-op on the storage HDDs.
    trim.enable = true;

    # Auto-scrub pools weekly
    autoScrub = {
      enable = true;
      pools = [
        "rpool"
        "storage"
      ];
      interval = "Sun *-*-* 02:00:00"; # Sunday 2 AM
    };
  };

  # Advanced snapshot management with Sanoid
  services.sanoid = {
    enable = true;
    interval = "*:00,15,30,45"; # Every 15 minutes

    datasets = {
      # Root filesystem - conservative snapshots
      "rpool/root" = {
        useTemplate = [ "system" ];
        recursive = false;
      };

      # Nix store - no snapshots (reproducible)
      "rpool/nix" = {
        autosnap = false;
        autoprune = false;
      };

      # Home directories - frequent snapshots
      "rpool/home" = {
        useTemplate = [ "production" ];
        recursive = true;
      };

      # Storage data - daily snapshots with long retention
      "storage/data" = {
        useTemplate = [ "storage" ];
        recursive = true;
      };

      # Replicated rpool/{home,root} snapshots from syncoid live here.
      # autosnap is off, sanoid doesn't create snapshots, only prunes the
      # ones syncoid replicates. Retention is much longer than rpool's
      # because HDD space is cheap; this is the historical archive.
      "storage/backup" = {
        useTemplate = [ "longterm" ];
        recursive = true;
      };
    };

    templates = {
      # System datasets (root) - Reduced retention to prevent disk space issues
      system = {
        frequently = 0;
        hourly = 6; # 6 hours (reduced from 24)
        daily = 3; # 3 days (reduced from 7)
        weekly = 2; # 2 weeks (reduced from 4)
        monthly = 2; # 2 months (reduced from 3)
        yearly = 0;
        autosnap = true;
        autoprune = true;
      };

      # User data (home) - Reduced retention to prevent disk space issues
      production = {
        frequently = 0; # Disabled (reduced from 4)
        hourly = 12; # 12 hours (reduced from 48)
        daily = 7; # 1 week (reduced from 14)
        weekly = 4; # 1 month (reduced from 8)
        monthly = 6; # 6 months (reduced from 12)
        yearly = 0; # Disabled (reduced from 2)
        autosnap = true;
        autoprune = true;
      };

      # Bulk storage - Reduced retention to prevent disk space issues
      storage = {
        frequently = 0;
        hourly = 0;
        daily = 14; # 2 weeks (reduced from 30)
        weekly = 4; # 1 month (reduced from 8)
        monthly = 6; # 6 months (reduced from 24)
        yearly = 1; # 1 year (reduced from 5)
        autosnap = true;
        autoprune = true;
      };

      # Long-term archive for syncoid-replicated snapshots. autosnap=false
      # because syncoid ships sanoid's snapshots from rpool wholesale; this
      # template only governs how long they stick around on the destination.
      longterm = {
        frequently = 0;
        hourly = 0;
        daily = 30; # 1 month
        weekly = 12; # 3 months
        monthly = 12; # 1 year
        yearly = 3; # 3 years
        autosnap = false;
        autoprune = true;
      };
    };

    extraArgs = [ "--verbose" ];
  };

  systemd.tmpfiles.rules = [
    # Storage directories: SGID so new files inherit storage-users.
    "d ${constants.storage.root}   2775 root storage-users - -"
    "d ${constants.storage.backup} 2775 root storage-users - -"
    "d ${constants.storage.media}  2775 root storage-users - -"
    "d ${constants.storage.data}   2775 root storage-users - -"
  ];
}
