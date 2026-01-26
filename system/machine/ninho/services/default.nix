{ ... }:
{
  imports = [
    ./permissions.nix    # Centralized permission management
    ./databases.nix      # PostgreSQL
    ./emanote.nix        # Personal journal
    ./nextcloud.nix      # File sync (includes OnlyOffice)
    ./immich.nix         # Photo backup
    ./llama-cpp.nix      # LLM inference with CUDA
    ./faster-whisper.nix      # Speech-to-text with CUDA
    ./homepage.nix       # Dashboard
    ./monitoring.nix     # Grafana + Prometheus
    ./jellyfin.nix       # Jellyfin
    ./servarr.nix        # *Arr services
    ./gaming.nix         # Game streaming (Steam + Sunshine)
    ./supernote.nix      # Supernote private cloud
    ./miniflux.nix       # RSS reader
    ./anki-sync-server.nix # Anki flashcard sync server
    ./navidrome.nix      # Music streaming server
    ./ntfy.nix           # Push notification service
    ./home-assistant.nix # Home automation platform

    # New services
    ./uptime-kuma.nix    # Uptime monitoring
    ./kavita.nix         # Ebook/comic reader
    ./memos.nix          # Note-taking service
    ./bazarr.nix         # Automatic subtitles for Sonarr/Radarr
  ];
}
