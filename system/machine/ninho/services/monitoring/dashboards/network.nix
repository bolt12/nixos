# Network & Reachability: the wired link, the tailnet, and whether the things
# ninho talks to answer.
{ constants, d, ... }:
let
  inherit (d)
    q
    row
    stat
    thresholds
    timeseries
    ;

  lan = constants.network.ninho.lanInterface;
  onLan = ''device="${lan}"'';
  # Container plumbing would add a line per veth pair.
  real = ''device!~"lo|veth.*|br-.*|docker.*"'';

  tile =
    args:
    stat (
      {
        w = 3;
        h = 4;
      }
      // args
    );

  bits =
    counter: selector: "rate(node_network_${counter}_bytes_total{${selector}}[$__rate_interval]) * 8";
  packets = counter: "rate(node_network_${counter}_total{${onLan}}[$__rate_interval])";
  netstat = name: "rate(node_netstat_${name}[$__rate_interval])";
in
d.dashboard {
  uid = "network";
  title = "Network & Reachability";
  description = "Throughput and errors on the wired link, Tailscale traffic, and latency to everything ninho depends on.";
  rows = [
    (row null [
      (tile {
        title = "Link speed";
        expr = "node_network_speed_bytes{${onLan}} * 8";
        unit = "bps";
        limits = thresholds.below 1000000000 100000000;
        desc = "Negotiated speed of ${lan}. Below 1 Gb/s usually means a cable fault.";
      })
      (tile {
        title = "Receiving";
        expr = bits "receive" onLan;
        unit = "bps";
        spark = true;
      })
      (tile {
        title = "Sending";
        expr = bits "transmit" onLan;
        unit = "bps";
        spark = true;
      })
      (tile {
        title = "Received, 24h";
        expr = "increase(node_network_receive_bytes_total{${onLan}}[1d])";
        unit = "bytes";
        decimals = 1;
      })
      (tile {
        title = "Sent, 24h";
        expr = "increase(node_network_transmit_bytes_total{${onLan}}[1d])";
        unit = "bytes";
        decimals = 1;
      })
      (tile {
        title = "Data retransmitted";
        expr = "(${netstat "Tcp_RetransSegs"} - ${netstat "TcpExt_TCPSynRetrans"}) / ${netstat "Tcp_OutSegs"} * 100";
        unit = "percent";
        decimals = 2;
        limits = thresholds.above 1 5;
        desc = "Share of TCP segments sent again, not counting connection attempts that got no answer. Above 1% the path is losing packets.";
      })
      (tile {
        title = "Internet round trip";
        expr = ''probe_icmp_duration_seconds{probe="internet",phase="rtt"}'';
        unit = "s";
        limits = thresholds.above 5.0e-2 0.2;
      })
      (tile {
        title = "Headscale certificate";
        expr = ''(probe_ssl_earliest_cert_expiry{probe="headscale"} - time()) / 86400'';
        unit = "suffix: d";
        decimals = 0;
        limits = thresholds.below 14 7;
        desc = "Days until it expires. Let's Encrypt renews at 30.";
      })
    ])

    (row "Wired link" [
      (timeseries {
        title = "Throughput on ${lan}";
        targets = [
          (q (bits "receive" onLan) "receive")
          (q (bits "transmit" onLan) "transmit")
        ];
        unit = "bps";
        min = 0;
      })
      (timeseries {
        title = "Errors and drops on ${lan}";
        targets = [
          (q (packets "receive_errs") "receive errors")
          (q (packets "transmit_errs") "transmit errors")
          (q (packets "receive_drop") "receive drops")
          (q (packets "transmit_drop") "transmit drops")
        ];
        unit = "pps";
        min = 0;
        desc = "Should be flat at zero. This NIC had a watchdog bug on older kernels.";
      })
      (timeseries {
        title = "Receiving, by interface";
        targets = [ (q (bits "receive" real) "{{device}}") ];
        unit = "bps";
        many = true;
        min = 0;
      })
      (timeseries {
        title = "Sending, by interface";
        targets = [ (q (bits "transmit" real) "{{device}}") ];
        unit = "bps";
        many = true;
        min = 0;
      })
    ])

    (row "Reachability" [
      (d.timeline {
        title = "What ninho depends on";
        targets = [ (q ''probe_success{kind!="service"}'' "{{probe}}") ];
        states = d.mappings.upDown;
        h = 7;
        desc = "Tang unlocks the disks at boot, Headscale runs the tailnet, the resolvers answer DNS for the LAN and the tailnet, and the rest are pings.";
      })
      (timeseries {
        title = "Ping round trip";
        targets = [ (q ''probe_icmp_duration_seconds{phase="rtt"}'' "{{probe}}") ];
        unit = "s";
        many = true;
        min = 0;
        w = 8;
        desc = "The hub is reached over Tailscale, so its line is the tailnet path.";
      })
      (timeseries {
        title = "DNS answer time";
        targets = [ (q ''probe_duration_seconds{kind="dns"}'' "{{probe}}") ];
        unit = "s";
        many = true;
        min = 0;
        w = 8;
      })
      (timeseries {
        title = "Tang and Headscale answer time";
        targets = [ (q ''probe_duration_seconds{kind=~"boot|tailnet"}'' "{{probe}}") ];
        unit = "s";
        many = true;
        min = 0;
        w = 8;
      })
    ])

    (row "TCP and connection tracking" [
      (timeseries {
        title = "Connections opened";
        targets = [
          (q (netstat "Tcp_ActiveOpens") "outgoing")
          (q (netstat "Tcp_PassiveOpens") "incoming")
        ];
        unit = "ops";
        min = 0;
        w = 8;
      })
      (timeseries {
        title = "Segments sent again";
        targets = [
          (q "${netstat "Tcp_RetransSegs"} - ${netstat "TcpExt_TCPSynRetrans"}" "data")
          (q (netstat "TcpExt_TCPSynRetrans") "unanswered connection attempts")
        ];
        unit = "pps";
        min = 0;
        w = 8;
        desc = "Unanswered attempts are mostly torrent and DHT peers that are gone; they say nothing about the link.";
      })
      (timeseries {
        title = "Connection tracking table";
        targets = [
          (q "node_nf_conntrack_entries" "entries")
          (q "node_nf_conntrack_entries_limit" "limit")
        ];
        min = 0;
        w = 8;
        desc = "When entries reach the limit the kernel drops new connections.";
      })
    ])
  ];
}
