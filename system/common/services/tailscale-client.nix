# Shared Tailscale client bound to the self-hosted Headscale hub.
#
# Every host that joins the tailnet imports this and sets just `hostname` (its
# --hostname, which is deliberately distinct from networking.hostName) and, if it
# routes traffic, `routingFeatures`. The login-server, the hand-placed authkey
# path, and the MagicDNS-off policy (so each host's own resolver stays
# authoritative instead of Tailscale pushing 100.100.100.100) live here once.
#
# tailscale0 runs on the 100.64.0.0/10 CGNAT range over udp 41641.
{
  config,
  lib,
  constants,
  ...
}:
let
  cfg = config.services.headscaleClient;
in
{
  options.services.headscaleClient = {
    enable = lib.mkEnableOption "Tailscale client bound to the self-hosted Headscale hub";

    hostname = lib.mkOption {
      type = lib.types.str;
      description = "The node's --hostname on the tailnet (distinct from networking.hostName).";
    };

    routingFeatures = lib.mkOption {
      type = lib.types.enum [
        "none"
        "client"
        "server"
        "both"
      ];
      default = "none";
      description = ''
        Tailscale routing role: "client" to accept subnet routes / exit nodes,
        "server" to advertise them, "none" for a pure host.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      openFirewall = true; # UDP 41641 for direct NAT traversal
      useRoutingFeatures = cfg.routingFeatures;
      authKeyFile = "/etc/tailscale/authkey"; # hand-placed, cf. /etc/wireguard/private

      # --accept-dns=false keeps each host's own resolver authoritative instead
      # of MagicDNS. It lives in extraUpFlags (the first `tailscale up`) AND
      # extraSetFlags (re-applied every rebuild) so DNS is never briefly
      # clobbered during initial enrolment.
      extraUpFlags = [
        "--login-server=${constants.network.headscale.url}"
        "--hostname=${cfg.hostname}"
        "--accept-dns=false"
      ];
      extraSetFlags = [ "--accept-dns=false" ];
    };

    networking.firewall.trustedInterfaces = [ "tailscale0" ];
  };
}
