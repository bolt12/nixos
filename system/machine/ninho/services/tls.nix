# A Let's Encrypt wildcard certificate for *.<constants.network.ninho.domain>,
# shared by every service ninho serves over HTTPS on the tailnet.
#
# The name is a free DuckDNS subdomain whose A record points at ninho's tailnet
# address, and DuckDNS answers every name under it with that same address. So
# a new service needs only an nginx vhost on <service>.<domain> with
# `useACMEHost = domain`; see rabisco.nix.
#
# lego proves ownership with a DNS-01 TXT record written through the DuckDNS
# API, so nothing listens on a public port. DuckDNS keeps a single TXT record
# per name, which is why this is one wildcard certificate and not one per
# service: two certificates renewing at once would overwrite each other's
# challenge.
#
# One-time setup, before the first switch:
#   curl "https://www.duckdns.org/update?domains=ninho-bolt&token=<token>&ip=100.64.0.3"
#   sudo install -d -m 700 /etc/secrets/duckdns
#   printf '%s' '<token>' | sudo install -m 600 /dev/stdin /etc/secrets/duckdns/token
{ config, constants, ... }:
let
  inherit (constants.network.ninho) domain;
in
{
  security.acme = {
    acceptTerms = true;
    # The attribute name cannot hold a `*`, so the wildcard goes in `domain`.
    certs.${domain} = {
      domain = "*.${domain}";
      dnsProvider = "duckdns";
      # The DuckDNS account token. It can rewrite every record on the
      # account, so it stays root-only on this host.
      credentialFiles.DUCKDNS_TOKEN_FILE = "/etc/secrets/duckdns/token";
      # Vhosts that use useACMEHost do not set the group, and nginx must read
      # the key.
      group = config.services.nginx.group;
    };
  };
}
