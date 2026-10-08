# The dashboards, built into the directory Grafana is provisioned from.
# One file per dashboard; ./lib.nix has the panel constructors.
{
  constants,
  lib,
  pkgs,
}:
let
  d = import ./lib.nix { inherit lib; };
  dashboards = map (file: import file { inherit constants d lib; }) [
    ./overview.nix
    ./compute.nix
    ./gpu.nix
    ./storage.nix
    ./backups.nix
    ./network.nix
    ./services.nix
    ./data.nix
    ./media.nix
    ./cameras.nix
    ./energy.nix
    ./platform.nix
  ];
in
pkgs.linkFarm "grafana-dashboards" (
  map (dashboard: {
    name = "${dashboard.uid}.json";
    path = pkgs.writeText "${dashboard.uid}.json" (builtins.toJSON dashboard);
  }) dashboards
)
