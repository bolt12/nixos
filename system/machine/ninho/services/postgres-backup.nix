# Daily Postgres logical backup — pg_dumpall → zstd → /storage/data/postgres-backups.
#
# Why a logical dump on top of ZFS snapshots: a snapshot of /var/lib/postgresql
# is crash-consistent at the block level, but a running cluster's WAL state
# doesn't always replay cleanly on restore. pg_dumpall is the one form that's
# restore-anywhere-safe AND grep-able with zstdgrep, and it lives on /storage
# (HDDs) so an SSD failure doesn't take it out.
#
# Retention: 14 daily files in the directory. Older recovery comes free via
# sanoid's `production` template (storage/data: 14d/4w/6m/1y), so the effective
# recoverable window is months without paying for it twice.
{
  pkgs,
  constants,
  ...
}:
let
  backupDir = "${constants.storage.data}/postgres-backups";
  retention = 14;

  backupScript = pkgs.writeShellApplication {
    name = "postgres-backup";
    runtimeInputs = with pkgs; [
      postgresql
      zstd
      coreutils
      findutils
    ];
    text = ''
      DEST="${backupDir}"
      DAY=$(date +%Y-%m-%d)
      OUT="$DEST/$DAY.sql.zst"
      TMP="$OUT.partial"

      # Clear any half-written dumps from a previous crashed run.
      find "$DEST" -maxdepth 1 -name '*.partial' -delete

      # --clean --if-exists makes the dump self-contained for restore-onto-empty:
      #   zstdcat <file>.sql.zst | psql -U postgres -d postgres
      # Globals (roles, tablespaces) are included automatically by pg_dumpall.
      # zstd level 15 is past the compression-curve knee — going to 19 spends
      # 15× more wall-clock time for ~2-3% better ratio, and contends with the
      # sanoid 15-min snapshot cadence on the same CPU.
      pg_dumpall --clean --if-exists | zstd -T0 -15 -q -o "$TMP"
      mv "$TMP" "$OUT"

      # Keep the ${toString retention} newest dumps; delete older ones from the
      # working directory. Sanoid snapshots of /storage/data still cover them.
      find "$DEST" -maxdepth 1 -name '*.sql.zst' -printf '%T@ %p\n' \
        | sort -rn \
        | tail -n +$((${toString retention} + 1)) \
        | awk '{ $1=""; sub(/^ /,""); print }' \
        | xargs -r -d '\n' rm -f
    '';
  };
in
{
  systemd.tmpfiles.rules = [
    # postgres owns the dir so it can write; storage-users (bolt+pollard) can
    # read for grep/zstdgrep. SGID propagates storage-users onto written files.
    "d ${backupDir} 2750 postgres storage-users - -"
  ];

  systemd.services.postgres-backup = {
    description = "Daily PostgreSQL logical dump (pg_dumpall → zstd)";
    after = [ "postgresql.service" ];
    wants = [ "postgresql.service" ];
    serviceConfig = {
      Type = "oneshot";
      User = "postgres";
      ExecStart = "${backupScript}/bin/postgres-backup";
      # Files default to 0640 (owner rw, group r) — others can't read even if
      # they somehow get the path.
      UMask = "0027";
    };
  };

  systemd.timers.postgres-backup = {
    description = "Fire postgres-backup nightly at 03:00";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 03:00:00";
      Persistent = true;
      AccuracySec = "5min";
    };
  };
}
