{ ... }:
{
  imports = [
    ./permissions.nix    # Centralized permission management
    ./databases.nix      # PostgreSQL
    ./emanote.nix        # Personal journal
    ./nextcloud.nix      # File sync (includes OnlyOffice)
    ./immich.nix         # Photo backup
    ./llama-cpp.nix      # LLM inference with CUDA
    # ./faster-whisper.nix # Speech-to-text with CUDA (DISABLED - not in use)
    ./homepage.nix       # Dashboard
    ./monitoring.nix     # Grafana + Prometheus
    ./jellyfin.nix       # Jellyfin
    ./servarr.nix        # *Arr services
    ./gaming.nix         # Game streaming (Steam + Sunshine)
    ./supernote.nix      # Supernote private cloud
    ./miniflux.nix       # RSS reader
    ./anki-sync-server.nix # Anki flashcard sync server
  ];
}
