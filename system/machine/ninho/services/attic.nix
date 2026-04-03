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

  # Auto-push all new store paths to the local Attic cache
  # Setup: generate a dedicated long-lived token:
  #   sudo atticd-atticadm make-token --sub "watch-store" --validity "10y" --push '*' --pull '*'
  # Then write /etc/attic/attic/config.toml (XDG_CONFIG_HOME=/etc/attic):
  #   sudo mkdir -p /etc/attic/attic
  #   sudo tee /etc/attic/attic/config.toml <<EOF
  #   default-server = "local"
  #   [servers.local]
  #   endpoint = "http://localhost:8090"
  #   token = "<paste-token>"
  #   EOF
  #   sudo chmod 600 /etc/attic/attic/config.toml
  systemd.services.attic-watch-store = {
    description = "Attic watch-store — auto-push to local cache";
    wantedBy = [ "multi-user.target" ];
    after = [ "atticd.service" ];
    requires = [ "atticd.service" ];

    serviceConfig = {
      ExecStart = "${pkgs.attic-client}/bin/attic watch-store local:main";
      Restart = "on-failure";
      RestartSec = 5;
      User = "root";
      Environment = "XDG_CONFIG_HOME=/etc/attic";
    };
  };
}
