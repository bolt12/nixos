{ ... }:
{
  imports = [
    ./permissions.nix # Centralized permission management
    ./databases.nix # PostgreSQL
    ./nextcloud.nix # File sync
    ./immich.nix # Photo backup
    ./llama-cpp.nix # LLM inference with CUDA
    ./faster-whisper.nix # Speech-to-text with CUDA
    ./homepage.nix # Dashboard
    ./monitoring # Grafana + Prometheus + exporters
    ./jellyfin.nix # Jellyfin
    ./servarr.nix # *Arr services
    ./gaming.nix # Game streaming (Steam + Sunshine)
    ./supernote.nix # Supernote private cloud
    ./miniflux.nix # RSS reader
    ./anki-sync-server.nix # Anki flashcard sync server
    ./navidrome.nix # Music streaming server
    ./ntfy.nix # Push notification service
    ./home-assistant.nix # Home automation platform

    # New services
    ./gatus.nix # Declarative uptime monitoring (replaces uptime-kuma)
    ./kavita.nix # Ebook/comic reader
    ./memos.nix # Note-taking service
    ./bazarr.nix # Automatic subtitles for Sonarr/Radarr
    ./atuin.nix # Shell history sync server
    ./attic.nix # Nix binary cache server
    ./open-webui.nix # Multimodal chat UI for llama-swap
    ./morning-brief.nix # Daily LLM-summarized overnight brief → ntfy
    ./redlib.nix # Privacy-respecting Reddit frontend
    ./syncoid.nix # ZFS replication rpool → storage/backup (tier-2 backup)
    ./postgres-backup.nix # Daily pg_dumpall → /storage/data/postgres-backups
  ];
}
