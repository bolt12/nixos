{ config, pkgs, lib, constants, ... }:
let
  inherit (constants) ports storage;
in
{
  services.ntfy-sh = {
    enable = true;
    package = pkgs.unstable.ntfy-sh;
    settings = {
      # Network
      listen-http = "0.0.0.0:${toString ports.ntfy}";
      base-url = "http://10.100.0.100:${toString ports.ntfy}";

      # Limits (generous for home server)
      message-size-limit = "4K";
      attachment-file-size-limit = "15M";
      attachment-total-size-limit = "5G";

      # Performance
      visitor-request-limit-burst = 60;
      visitor-request-limit-replenish = "5s";

      # Features
      enable-login = true;
      enable-signup = false;
      behind-proxy = true;
    };
  };

  # Open firewall
  networking.firewall.allowedTCPPorts = [ ports.ntfy ];
}
