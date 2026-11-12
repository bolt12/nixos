# HTTPS front for rabisco, the server behind the Supernote plugin, at
# rabisco.<constants.network.ninho.domain>.
#
# The tablet's plugin host refuses plain HTTP and trusts only public CAs, so
# the plugin talks to this vhost, which uses the wildcard certificate from
# tls.nix and forwards to the server on loopback.
{ constants, ... }:
let
  inherit (constants) ports;
  inherit (constants.network.ninho) domain vpnIp;
in
{
  services.nginx.virtualHosts."rabisco.${domain}" = {
    useACMEHost = domain;
    onlySSL = true;
    # Tailnet address only; tailscale0 is a trusted interface, so no firewall
    # rule is needed and the LAN never sees this port.
    listen = [
      {
        addr = vpnIp;
        port = 443;
        ssl = true;
      }
    ];
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString ports.rabisco}";
      # A whole-page lasso arrives as a base64 PNG in the JSON body.
      extraConfig = ''
        client_max_body_size 32m;
      '';
    };
  };
}
