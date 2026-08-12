# Monitoring stack, Prometheus + exporters + Grafana.
# Each piece is its own file; module merging combines services.prometheus.*
# across them.
{ ... }:
{
  imports = [
    ./prometheus.nix
    ./exporters.nix
    ./grafana.nix
  ];
}
