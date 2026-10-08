# Centralized PostgreSQL: shared by Nextcloud, Immich, Miniflux, Home Assistant.
{ lib, ... }:
{
  # PostgreSQL - services will auto-create databases
  services.postgresql.enable = true;

  # Login role for prometheus-postgres-exporter. Its systemd unit runs as OS
  # user "postgres-exporter"; a matching role lets peer auth over the local
  # socket succeed (fixes the recurring "peer authentication failed" FATALs).
  services.postgresql.ensureUsers = [
    { name = "postgres-exporter"; }
  ];

  # Without pg_monitor the exporter cannot size databases it has no CONNECT on
  # or list the WAL directory, so its `database` and `wal` collectors fail.
  # ensureUsers has no clause for role membership, hence the explicit GRANT.
  systemd.services.postgresql-setup.script = lib.mkAfter ''
    psql -tAc 'GRANT pg_monitor TO "postgres-exporter"'
  '';

  # Redis - for Nextcloud/Immich caching (auto-configured by those services)
}
