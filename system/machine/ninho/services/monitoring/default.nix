# Monitoring stack: Prometheus, exporters, probes, Grafana and its alerts.
# Each piece is its own file; module merging combines services.prometheus.*
# across them.
{ ... }:
{
  imports = [
    ./prometheus.nix
    ./exporters.nix
    ./probes.nix
    ./textfile.nix
    ./grafana.nix
    ./alerts.nix
  ];
}
