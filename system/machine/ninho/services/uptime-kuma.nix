{ config, pkgs, lib, constants, ... }:
let
  inherit (constants) ports storage;
in
{
  services.uptime-kuma = {
    enable = true;
    package = pkgs.unstable.uptime-kuma;
    appriseSupport = true;  # Enable notification support
    settings = {
      # Port configuration via environment variable
      UPTIME_KUMA_PORT = toString ports.uptime-kuma;
      UPTIME_KUMA_HOST = "0.0.0.0";
    };
  };

  # Open firewall
  networking.firewall.allowedTCPPorts = [ ports.uptime-kuma ];
}
