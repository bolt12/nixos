# Syncoid — ZFS-native replication, sister tool to sanoid.
#
# Why: rpool snapshots live ON rpool. If the NVMe pool dies, the snapshots
# die with it. Replicating the snapshot stream to a separate pool (storage,
# 3× HDD raidz1) keeps a copy on independent hardware. Daily incremental
# `zfs send -i` ships only changed blocks — minutes per day after bootstrap.
#
# Targets are auto-created on first run: the upstream module grants `create`
# on the parent (storage/backup) when the leaf doesn't exist yet.
#
# Retention on the destination is governed by sanoid's `longterm` template
# in storage.nix — we keep replicated snapshots much longer than rpool's
# stingy 2-month max.
{ ... }:
{
  services.syncoid = {
    enable = true;
    interval = "daily";
    # Use sanoid's existing snapshots verbatim; don't have syncoid take its
    # own pre-send snapshot every run.
    commonArgs = [ "--no-sync-snap" ];

    commands = {
      "rpool/home".target = "storage/backup/home";
      "rpool/root".target = "storage/backup/root";
    };
  };
}
