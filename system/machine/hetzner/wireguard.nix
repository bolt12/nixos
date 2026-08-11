# WireGuard hub, the role moved off the RPi. This box reuses the RPi's server
# key (pre-placed at constants.paths.wireguardPrivateKey via nixos-anywhere
# --extra-files) AND its VPN address (10.100.0.1), so every existing peer keeps
# working; only each peer's endpoint moves to this box's public IP.
#
# NAT lets full-tunnel clients reach the internet; the firewall exposes only SSH
# and the WireGuard port publicly. DNS (53) is reachable ONLY over the tunnel
# via trustedInterfaces, never on the public interface (see dns.nix).
{ constants, ... }:
{
  # Masquerade wg0 traffic out the public NIC. networking.nat.enable also turns
  # on IPv4 forwarding automatically; the tunnel is IPv4-only.
  networking.nat = {
    enable = true;
    externalInterface = constants.network.hub.externalInterface;
    internalInterfaces = [ constants.network.wireguard.interface ];
  };

  networking.firewall = {
    enable = true;
    # Trust wg0: peers are personal devices, and this enables wg0->wg0 forwarding
    # (peer-to-peer traffic, e.g. phone -> ninho) plus tunnel-only reach to DNS.
    trustedInterfaces = [ constants.network.wireguard.interface ];
    allowedTCPPorts = [ 22 ]; # public: SSH only
    allowedUDPPorts = [ constants.network.wireguard.port ]; # public: WireGuard only
  };

  networking.wireguard.interfaces.wg0 = {
    ips = [ constants.network.wireguard.serverIp ]; # 10.100.0.1/24
    listenPort = constants.network.wireguard.port;
    privateKeyFile = constants.paths.wireguardPrivateKey;
    generatePrivateKeyFile = false; # key is REUSED from the RPi, not generated

    # Lower MTU for mobile clients: mobile carriers often filter ICMP
    # "fragmentation needed", breaking PMTUD. 1320 is defensive across carriers.
    mtu = 1320;

    # Peer table copied verbatim from the RPi (system/machine/rpi/rpi5.nix).
    # These are personal-device public keys; each maps to a fixed /32.
    peers = [
      {
        # X1 G8 Carbon
        publicKey = "mFi3yUWeb8f3VZDVJXclrOPSCaOLuHkiNL6DxpnZsmQ=";
        allowedIPs = [ "10.100.0.2/32" ];
      }
      {
        # Bolt Android phone
        publicKey = "KP3wpBB2zEsJnSHzVISjJ1gmUAAWS/rOa1rgBJ5uBkM=";
        allowedIPs = [ "10.100.0.3/32" ];
      }
      {
        # Steam Deck
        publicKey = "3w9nh1xsGDAZRF7QSEo9N8oEwpL5a+g6wGscNC+PbkQ=";
        allowedIPs = [ "10.100.0.4/32" ];
      }
      {
        # Supernote
        publicKey = "OcLbbW78TqTqFSdn24oCAfRt1U+VlSilAfeEspiqUR4=";
        allowedIPs = [ "10.100.0.5/32" ];
      }
      {
        # Pollard Android phone
        publicKey = "QFbI4k1IANbEVUpPEE71QF71aSQRgdr4OqJnwtxUkn0=";
        allowedIPs = [ "10.100.0.6/32" ];
      }
      {
        # Ninho Home Server
        publicKey = "xSZiLvopp4Q/eMMxYyzQrdmvt/dyejc2CR4/dzsm5gw=";
        allowedIPs = [ "${constants.network.ninho.vpnIp}/32" ];
      }
      {
        # Pollard MacOs
        publicKey = "mk0JLBqa8b16kH/Kh87/ceaf+iQpUfxRHoHb+I/zqHY=";
        allowedIPs = [ "10.100.0.7/32" ];
      }
    ];
  };
}
