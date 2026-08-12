# Home Assistant, rest_command service definitions (HTTP calls invoked by automations).
# Module-merged into services.home-assistant.config by ./default.nix.
{ constants, ... }:
let
  inherit (constants) ports;
in
{
  services.home-assistant.config = {
    rest_command = {
      ntfy_notify = {
        url = "http://127.0.0.1:${toString ports.ntfy}/home-assistant";
        method = "POST";
        headers = {
          Title = "{{ title }}";
          Priority = "{{ priority | default('default') }}";
          Tags = "{{ tags | default('house') }}";
        };
        content_type = "text/plain";
        payload = "{{ message }}";
      };
    };
  };
}
