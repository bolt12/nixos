# SearXNG metasearch. Backs the `searxng` MCP server that the olaude wrappers
# (home-manager/users/bolt/home.nix) give Claude Code in place of WebSearch.
{ pkgs, constants, ... }:
let
  inherit (constants) ports;
  # Holds SEARXNG_SECRET=<hex>. SearXNG reads server.secret_key from that
  # variable and refuses to start on the packaged default.
  secretEnv = "/etc/secrets/searx/env";
in
{
  services.searx = {
    enable = true;
    environmentFile = secretEnv;
    settings = {
      server = {
        # Not in the firewall port list: reached on tailscale0 (trusted) and
        # loopback. It is an unauthenticated search proxy with no rate limit.
        bind_address = "0.0.0.0";
        port = ports.searxng; # upstream default 8888 is atuin's
        limiter = false; # the default; turning it on needs Valkey
      };
      # mcp-searxng asks for format=json, which is a 403 unless listed.
      search.formats = [
        "html"
        "json"
      ];
    };
  };

  # Generated once. Ordered before searx-init, the first unit to load the file.
  systemd.services.searx-secret-key = {
    description = "SearXNG: generate the secret key on first start";
    before = [ "searx-init.service" ];
    requiredBy = [ "searx-init.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      if [ ! -s ${secretEnv} ]; then
        install -d -m 0700 ${dirOf secretEnv}
        umask 077
        printf 'SEARXNG_SECRET=%s\n' "$(${pkgs.openssl}/bin/openssl rand -hex 32)" > ${secretEnv}
      fi
    '';
  };
}
