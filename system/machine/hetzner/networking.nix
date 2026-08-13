# Host networking for the Hetzner Cloud VM.
#
# systemd-networkd (not NetworkManager/scripted) because Hetzner Cloud hands out
# IPv4 by DHCP but expects a STATIC IPv6 address in your routed /64 with a route
# via the link-local gateway fe80::1. The NIC is pinned to eth0
# (usePredictableInterfaceNames = false) so both this match and the NAT
# externalInterface (see wireguard.nix) reference one stable name.
{ constants, ... }:
{
  networking = {
    hostName = "hetzner-hub";
    useDHCP = false;
    usePredictableInterfaceNames = false; # NIC becomes eth0

    # The host resolves via public DNS, NOT its own unbound. unbound here only
    # serves tunnel clients (see dns.nix); pointing the host at it would create a
    # boot-time chicken-and-egg (no name resolution until wg0 + unbound are up).
    nameservers = [
      "1.1.1.1"
      "8.8.8.8"
    ];

    # Public firewall: SSH only here. headscale.nix adds TCP 80/443, and the
    # tailscale-client module adds tailscale0 to trustedInterfaces + UDP 41641.
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ];
    };
  };

  systemd.network = {
    enable = true;
    networks."10-wan" = {
      matchConfig.Name = constants.network.hub.externalInterface;
      networkConfig.DHCP = "ipv4";
      address = [ "${constants.network.hub.ipv6}/64" ];
      routes = [
        {
          # fe80::1 is link-local so it is inherently on-link; GatewayOnLink is
          # belt-and-suspenders on Cloud (strictly required only on dedicated,
          # where the gateway sits outside the prefix).
          Gateway = "fe80::1";
          GatewayOnLink = true;
        }
      ];
      linkConfig.RequiredForOnline = "routable";
    };
  };
}
