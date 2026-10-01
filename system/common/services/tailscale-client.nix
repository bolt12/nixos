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
  # Hand-placed secret, deliberately outside the store and outside git. Mint it
  # on the hub with `headscale preauthkeys create --user <id> --reusable`.
  authKeyPath = "/etc/tailscale/authkey";
  # raw-table rule that keeps peers off IPv6 link-local paths; see the
  # firewall block below for why.
  linkLocalDrop = "PREROUTING -s fe80::/10 -p udp --dport ${toString config.services.tailscale.port} -j DROP";
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
      authKeyFile = authKeyPath;

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

    # Keep peers off IPv6 link-local paths until every node runs a Tailscale
    # with the fix for tailscale#21411 (PR #21523, merged 2026-09-29, in no
    # release yet; 26.05 ships 1.98.10 and the Android app has the same bug).
    # Linux's batched send drops the %zone from fe80:: destinations, so the
    # kernel refuses every WireGuard packet on that path, while disco uses a
    # send that keeps the zone and reports the path healthy. ninho and the
    # Pixel picked it on home wifi about once a minute and lost all tunnel
    # traffic until the next switch.
    #
    # Dropping link-local UDP to our port makes disco fail there too, so both
    # ends settle on the IPv4 LAN address. It has to live in `raw`: tailscaled
    # jumps to its own ts-input chain at the top of filter/INPUT and accepts
    # this port there, before nixos-fw is ever consulted.
    networking.firewall.extraCommands = ''
      ip6tables -t raw -D ${linkLocalDrop} 2>/dev/null || true
      ip6tables -t raw -I ${linkLocalDrop}
    '';
    networking.firewall.extraStopCommands = ''
      ip6tables -t raw -D ${linkLocalDrop} 2>/dev/null || true
    '';

    # nixpkgs builds tailscaled-autoconnect around a `cat` of that file under
    # `set -o errexit`, so a missing key kills the unit with nothing in the
    # journal but "No such file or directory", and only at the moment the daemon
    # next needs to log in. A host whose /var/lib/tailscale survived keeps
    # working until it reboots or logs out, which is how a reimaged box looks
    # healthy for hours and then quietly leaves the tailnet. Reflashing the Pi
    # did exactly that on 2026-08-20 and cost it four node registrations. Say it
    # at activation, where the colmena run that skipped the step can still show
    # it.
    system.activationScripts.tailscaleAuthKey.text = ''
      if [ ! -s ${authKeyPath} ]; then
        echo "tailscale: ${authKeyPath} is missing or empty; this host cannot (re-)enrol." >&2
        echo "tailscale: mint one on the hub with 'headscale preauthkeys create --user <id> --reusable --expiration 720h'." >&2
      fi
    '';
  };
}
