# Self-hosted Anki sync (clients point at http://ninho.local:27701).
{
  config,
  pkgs,
  lib,
  constants,
  ...
}:
{
  # Adding a user: `anki-sync-server --add-user <name>` (interactive prompt
  # for the password). On clients, point Anki preferences → Syncing →
  # custom sync server at http://ninho.local:27701.
  services.anki-sync-server = {
    enable = true;
    address = "0.0.0.0";
    port = constants.ports.anki-sync-server;
    openFirewall = true;
    users = [
      {
        username = "bolt";
        password = "tlob";
      }
    ];
  };
}
