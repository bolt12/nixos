# Self-hosted Headscale control server.
#
# Headscale is the open-source control plane for Tailscale clients. Running it
# here gives the fleet a DIRECT, NAT-traversed path between devices (e.g.
# ninho -> laptop game streaming) instead of hairpinning every packet through
# this box. It replaced the wg0 hub that used to live here, so nothing on this
# machine carries peer traffic any more, bar the DERP fallback when NAT
# traversal fails.
#
# What this puts on the public interface: TCP 443 (control API, HTTPS) and
# TCP 80 (Let's Encrypt HTTP-01 challenge). The tailscale client further down
# adds UDP 41641 through its own openFirewall.
#
# No hand-placed secrets: headscale generates its own noise/DERP keys and the
# SQLite DB under /var/lib/headscale on first start. The only "secret" is a
# preauth key you mint at runtime with the CLI (see the bootstrap block below).
{ constants, ... }:
let
  # The control-plane hostname clients dial: a No-IP DDNS name that
  # forward-resolves to this box's public v4 (constants.network.hub.publicHost =
  # 2.28.9.140). The adblock resolvers allowlist it so a dynamic-DNS blocklist
  # entry can never break resolution (see unbound-adblock.nix `allowlist`).
  controlHostname = constants.network.headscale.hostname;
in
{
  services.headscale = {
    enable = true;

    # Serve the control API on all interfaces, TCP 443. The firewall below is
    # what actually gates public exposure. port < 1024 makes the module grant
    # CAP_NET_BIND_SERVICE automatically.
    address = "0.0.0.0";
    port = 443;

    settings = {
      # Clients embed this verbatim in `tailscale up --login-server=...`.
      # Scheme + host; :443 is implicit so it is omitted.
      server_url = "https://${controlHostname}";

      # The admin gRPC API. headscale's own default binds every interface, and
      # on this box tailscale0 is a trusted interface, so that would hand every
      # tailnet node (the phone included) a path to the control API. The CLI
      # used in the bootstrap block below talks over the unix socket, so nothing
      # here needs to be reachable off loopback.
      grpc_listen_addr = "127.0.0.1:50443";

      # Tailnet address pools handed to clients. Both defaults are shown for
      # clarity. Neither collides with anything you run:
      #   v4 100.64.0.0/10  -> the mandated Tailscale CGNAT range
      #   v6 fd7a:115c:a1e0::/48 -> ULA, disjoint from your MEO/Hetzner GUAs
      prefixes = {
        v4 = "100.64.0.0/10";
        v6 = "fd7a:115c:a1e0::/48";
      };

      database = {
        type = "sqlite";
        sqlite.path = "/var/lib/headscale/db.sqlite";
      };

      # DNS: MagicDNS off so headscale pushes no nameservers and never rewrites a
      # client's OS resolver (override_local_dns off). Each host keeps its own
      # nameservers pointing at the adblock resolver (the hub's unbound over the
      # tailnet, or the RPi on the LAN). Enabling MagicDNS later would mean
      # serving tailnet names + forwarding other queries to that adblock resolver
      # as the global upstream.
      dns = {
        magic_dns = false;
        override_local_dns = false;
      };

      # Built-in Let's Encrypt. headscale obtains + renews the cert itself and
      # terminates TLS on :443; no reverse proxy, no ACME module, no gRPC
      # passthrough to get wrong. HTTP-01 needs :80 reachable (firewall below).
      tls_letsencrypt_hostname = controlHostname;
      tls_letsencrypt_challenge_type = "HTTP-01";
      # tls_letsencrypt_listen defaults to ":http" (:80), left at default.
    };
  };

  # Public firewall additions. These MERGE with allowedTCPPorts = [ 22 ] in
  # networking.nix (NixOS concatenates list options across modules), giving a
  # final public TCP set of [ 22 80 443 ].
  networking.firewall.allowedTCPPorts = [
    80 # Let's Encrypt HTTP-01 challenge (headscale ACME)
    443 # headscale control API (HTTPS)
  ];

  # This box also joins its OWN tailnet as a node (a Tailscale client alongside
  # the Headscale server), so it appears in `headscale nodes list` and is
  # reachable over Tailscale (e.g. SSH) like every other host. The client dials
  # the control server by its public hostname, hairpinning back to this box.
  services.headscaleClient = {
    enable = true;
    hostname = "hetzner";
  };
}

# ---------------------------------------------------------------------------
# CLI bootstrap (run once on the box, as root, after the first deploy)
# ---------------------------------------------------------------------------
# The systemd unit writes /etc/headscale/config.yaml so the CLI can find the
# control socket. Root can talk to it directly.
#
#   # 1. Create a user (tailnet namespace) to own your devices:
#   headscale users create bolt
#
#   # 2. Find its numeric ID (0.26+ keys the --user flag on the ID, not name):
#   headscale users list
#
#   # 3. Mint a reusable preauth key (30d validity) to enroll devices:
#   headscale preauthkeys create --user <ID> --reusable --expiration 720h
#
#   # 4. On each client (ninho, laptop, phone, ...):
#   tailscale up --login-server=https://hetzner-nixos.ddns.net \
#     --auth-key=<KEY>
#
#   # 5. Verify enrollment and the assigned 100.64/10 addresses:
#   headscale nodes list
# ---------------------------------------------------------------------------
