{ ... }:
{
  imports = [
    ./permissions.nix # Centralized permission management
    ./databases.nix   # PostgreSQL
    ./emanote.nix     # Personal journal
    ./nextcloud.nix   # File sync (includes OnlyOffice)
    ./immich.nix      # Photo backup
    ./ollama.nix      # LLM inference
    ./homepage.nix    # Dashboard
    ./monitoring.nix  # Grafana + Prometheus
    ./jellyfin.nix    # Jellyfin
    ./servarr.nix     # *Arr services
    ./gaming.nix      # Game streaming (Steam + Sunshine)
    ./supernote.nix   # Supernote private cloud
  ];
}
