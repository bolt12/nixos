{ ... }:
{
  imports = [
    ./databases.nix  # Just enables PostgreSQL
    ./caddy.nix      # Reverse proxy
    ./emanote.nix
    ./nextcloud.nix
    ./immich.nix
    ./ollama.nix
    ./homepage.nix
    # monitoring.nix - add later
  ];
}
