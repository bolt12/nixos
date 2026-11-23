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

      # Storage data - daily snapshots with long retention.
      # This is the only copy of service state history (Nextcloud, Immich,
      # postgres dumps, etc.), so retention is generous.
      "storage/data" = {
        useTemplate = [ "storage" ];
        recursive = true;
      };

      # Torrents and media are expendable (re-downloadable) and churn
      # heavily, so snapshotting them wastes space for no benefit.
      "storage/torrents" = {
        autosnap = false;
        autoprune = false;
      };

      "storage/media" = {
        autosnap = false;
        autoprune = false;
      };

      # LLM model cache: freely re-downloadable from Hugging Face.
      "rpool/llama" = {
        autosnap = false;
        autoprune = false;
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
      system = {
        frequently = 0;
        hourly = 6;
        daily = 3;
        weekly = 2;
        monthly = 2;
        yearly = 0;
        autosnap = true;
        autoprune = true;
      };

      # User data (home) - tight retention; longterm archive on storage/ keeps the history
      production = {
        frequently = 0;
        hourly = 12;
        daily = 7;
        weekly = 2; # 2 weeks; storage/backup keeps 12
        monthly = 1; # 1 month; storage/backup keeps 12
        yearly = 0;
        autosnap = true;
        autoprune = true;
      };

      storage = {
        frequently = 0;
        hourly = 0;
        daily = 30;
        weekly = 8;
        monthly = 12;
        yearly = 2;
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
