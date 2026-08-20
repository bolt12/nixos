# Adblocking recursive DNS on the hub, served ONLY over the tailnet.
#
# Uses the shared services.adblockDns module (system/common/services/
# unbound-adblock.nix). The public-box hardening is entirely in the options:
# bind the tailscale address + loopback (never 0.0.0.0), refuse-by-default ACL.
# There is deliberately NO port 53 in the public firewall (see networking.nix):
# tailnet reach comes from trustedInterfaces = [ "tailscale0" ], which
# tailscale-client.nix sets, so an open-resolver amplification leak is
# impossible even if the firewall were misconfigured.
{ constants, ... }:
{
  services.adblockDns = {
    enable = true;
    # Bind the tailnet address + loopback only, never 0.0.0.0 / the public IP.
    # unbound binds the tailscale address before tailscale0 exists because
    # nixpkgs enables ip-freebind by default, so no start-ordering is needed.
    interfaces = [
      constants.network.hub.vpnIp # 100.64.0.5, hub tailscale address
      "127.0.0.1"
    ];
    accessControl = [
      "0.0.0.0/0 refuse"
      "::0/0 refuse"
      "127.0.0.0/8 allow"
      "${constants.network.tailscale.subnet} allow" # 100.64.0.0/10 tailnet
    ];
    # Never block the Headscale control host: a DDNS name a blocklist could catch.
    allowlist = [ constants.network.headscale.hostname ];
  };

  # The host itself resolves via the public nameservers in networking.nix, not
  # via its own unbound (which exists only to serve tunnel clients). Without
  # this, nixpkgs prepends 127.0.0.1 to the host's resolv.conf, coupling host
  # name resolution to unbound being up.
  services.unbound.resolveLocalQueries = false;
}
