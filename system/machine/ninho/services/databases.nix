{ config, pkgs, ... }:
{
  # PostgreSQL - services will auto-create databases
  services.postgresql.enable = true;

  # Redis - for Nextcloud/Immich caching (auto-configured by those services)
}
