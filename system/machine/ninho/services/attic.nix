{
  config,
  pkgs,
  constants,
  ...
}:
let
  inherit (constants) ports;
in
{
  # Attic - self-hosted Nix binary cache
  services.atticd = {
    enable = true;

    # Contains ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64
    # Generate with: openssl genrsa -traditional 4096 | base64 -w0
    # Then create /etc/atticd.env with: ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64="<output>"
    environmentFile = "/etc/atticd.env";

    settings = {
      listen = "[::]:${toString ports.attic}";
    };
  };

  networking.firewall.allowedTCPPorts = [ ports.attic ];
}
