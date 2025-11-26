{ ... }:
{
  imports = [
    ./databases.nix  # PostgreSQL
    ./caddy.nix      # Reverse proxy with HTTPS
    ./emanote.nix    # Personal journal
    ./nextcloud.nix  # File sync (includes OnlyOffice)
    ./immich.nix     # Photo backup
    ./ollama.nix     # LLM inference
    ./homepage.nix   # Dashboard
    ./monitoring.nix # Grafana + Prometheus
  ];
}
