# Centralized PostgreSQL: shared by Nextcloud, Immich, Miniflux, Home Assistant.
{ config, pkgs, ... }:
{
  # PostgreSQL - services will auto-create databases
  services.postgresql.enable = true;

  # Login role for prometheus-postgres-exporter. Its systemd unit runs as OS
  # user "postgres-exporter"; a matching role lets peer auth over the local
  # socket succeed (fixes the recurring "peer authentication failed" FATALs).
  services.postgresql.ensureUsers = [
    { name = "postgres-exporter"; }
  ];

  # Redis - for Nextcloud/Immich caching (auto-configured by those services)
}
