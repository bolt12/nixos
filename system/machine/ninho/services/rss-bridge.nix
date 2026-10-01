# RSS-Bridge: generate RSS feeds from websites that don't provide them.
# Used with XPathBridge for Agere's water-cut notices (https://agere.pt/avisos/).
{ constants, ... }:
let
  port = constants.ports.agere-feed;
in
{
  services.rss-bridge = {
    enable = true;
    virtualHost = "rss-bridge";
    config = {
      system.enabled_bridges = [ "XPathBridge" ];
      FileCache.enable_purge = true;
    };
  };

  services.nginx.virtualHosts."rss-bridge" = {
    listen = [
      {
        addr = "0.0.0.0";
        inherit port;
      }
    ];
  };

  networking.firewall.allowedTCPPorts = [ port ];
}
