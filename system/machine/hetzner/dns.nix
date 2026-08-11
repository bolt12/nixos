# Adblocking recursive DNS on the hub, served ONLY over the tunnel.
#
# Uses the shared services.adblockDns module (system/common/services/
# unbound-adblock.nix). The public-box hardening is entirely in the options:
# bind the wg0 address + loopback (never 0.0.0.0), refuse-by-default ACL. There
# is deliberately NO port 53 in the public firewall (see wireguard.nix): tunnel
# reach comes from trustedInterfaces = [ "wg0" ], so an open-resolver
# amplification leak is impossible even if the firewall were misconfigured.
{ constants, ... }:
{
  services.adblockDns = {
    enable = true;
    # Bind the tunnel address + loopback only, never 0.0.0.0 / the public IP.
    # unbound binds the wg0 address before the tunnel is up because nixpkgs
    # enables ip-freebind by default, so no wg0 start-ordering is needed.
    interfaces = [
      constants.network.hub.vpnIp
      "127.0.0.1"
    ];
    accessControl = [
      "0.0.0.0/0 refuse"
      "::0/0 refuse"
      "127.0.0.0/8 allow"
      "${constants.network.wireguard.subnet} allow"
    ];
  };

  # The host itself resolves via the public nameservers in networking.nix, not
  # via its own unbound (which exists only to serve tunnel clients). Without
  # this, nixpkgs prepends 127.0.0.1 to the host's resolv.conf, coupling host
  # name resolution to unbound being up.
  services.unbound.resolveLocalQueries = false;
}
