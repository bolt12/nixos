# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{
  config,
  lib,
  pkgs,
  raspberry-pi-nix,
  inputs,
  constants,
  ...
}@attrs:

let
  # Get emanote from the flake input
  emanotePackage = inputs.emanote.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # This RPi is the public journal gateway (single-user: bolt).
  # The service is intentionally system-level so the journal survives user-session
  # logouts and boots before any login. The path is bolt-scoped by design; if this
  # ever becomes multi-user, lift journalDir to a NixOS option.
  emanoteUser = "bolt";
  journalDir = "/home/${emanoteUser}/journal";
in
{
  imports = [ ./services/dns-blocklist.nix ];
  nixpkgs = {
    config.allowUnfree = true;
  };

  nix = {
    channel.enable = true;
    gc = {
      automatic = true;
      options = "--delete-older-than 30d";
    };

    nixPath = [
      "nixpkgs=${inputs.nixpkgs}"
      # Add more channels as needed
    ];
    # Required by Cachix to be used as non-root user
    settings.trusted-users = [
      "bolt"
      "deck"
      "root"
      "@wheel"
    ];
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  systemd = {
    services = {
      iwd.serviceConfig.Restart = "always";

      # Emanote public journal gateway (see let-binding for scoping rationale)
      emanote = {
        enable = true;
        description = "Emanote web server";
        after = [ "network.target" ];
        wantedBy = [ "default.target" ];

        serviceConfig = {
          Type = "simple";
          User = emanoteUser;
          Group = "users";
          ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${journalDir}";
          ExecStart = ''
            ${emanotePackage}/bin/emanote --layers "${journalDir}" run --no-ws --host=0.0.0.0 --port=${toString constants.ports.emanote}
          '';
          Restart = "always";
          RestartSec = "10";

          # Security hardening
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = "tmpfs";
          ReadWritePaths = [ journalDir ];
          BindReadOnlyPaths = [ journalDir ];
        };
      };
    };
  };

  boot.kernel.sysctl = {
    # The generic hardening value can exceed Raspberry Pi's ARM64 VA range and
    # make systemd-sysctl fail activation with "vm/mmap_rnd_bits: Invalid argument".
    "vm.mmap_rnd_bits" = lib.mkForce 24;
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment = {
    systemPackages = with pkgs; [
      bluez
      bluez-tools
      git
      git-annex
      iptables
      libraspberrypi
      neovim
      unbound-full
      unzip
      wget
      wireguard-tools
      # Add emanote to system packages as well for manual use
      emanotePackage
    ];

  };

  services = {
    # Tang server for Clevis/LUKS auto-unlock on ninho
    # Serves key advertisement on port 7654 for initrd Clevis clients
    tang = {
      enable = true;
      listenStream = [ "7654" ];
      ipAddressAllow = [
        "127.0.0.0/8"
        constants.network.lan.subnet
        constants.network.wireguard.subnet
      ];
    };

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    # Setting up Unbound as a recursive DNS Server
    # Check https://docs.pi-hole.net/guides/dns/unbound/#configure-unbound
    unbound = {
      enable = true;
      user = "bolt";
      settings = {
        server = {
          module-config = ''"respip validator iterator"'';
          # Logging — production settings (use unbound-control to enable debug temporarily)
          verbosity = 0;
          log-queries = "no";
          log-servfail = "yes";

          # Stale/expired record serving (RFC 8767)
          serve-expired = "yes";
          serve-expired-ttl = 86400;
          serve-expired-client-timeout = 1800;

          # Network
          interface = [ "0.0.0.0" ];
          do-ip4 = "yes";
          do-udp = "yes";
          do-tcp = "yes";
          so-reuseport = "yes";
          so-rcvbuf = "1m";
          so-sndbuf = "1m";
          edns-buffer-size = "1232";

          # Security hardening
          harden-glue = "yes";
          harden-dnssec-stripped = "yes";
          harden-below-nxdomain = "yes";
          harden-algo-downgrade = "yes";
          harden-large-queries = "yes";
          use-caps-for-id = "yes";
          aggressive-nsec = "yes";
          val-clean-additional = "yes";
          deny-any = "yes";
          unwanted-reply-threshold = 10000;

          # Privacy
          hide-identity = "yes";
          hide-version = "yes";
          qname-minimisation = "yes";

          # Performance
          num-threads = 1;
          prefetch = "yes";
          prefetch-key = "yes";
          minimal-responses = "yes";
          rrset-roundrobin = "yes";

          # Cache sizing
          msg-cache-size = "8m";
          rrset-cache-size = "16m";
          key-cache-size = "8m";
          neg-cache-size = "4m";
          cache-min-ttl = 300;
          cache-max-ttl = 86400;

          # DNS rebinding protection
          private-address = [
            "192.168.0.0/16"
            "169.254.0.0/16"
            "172.16.0.0/12"
            "10.0.0.0/8"
            "fd00::/8"
            "fe80::/10"
          ];

          access-control = [
            "192.168.0.0/16 allow"
            "10.100.0.0/16 allow"
          ];
        };
        remote-control = {
          control-enable = true;
        };
        rpz = {
          name = "hagezi-pro";
          zonefile = "/var/lib/unbound/hagezi-pro.rpz";
          rpz-action-override = "nxdomain";
          rpz-log = "yes";
          rpz-log-name = "hagezi-pro";
        };
      };
    };
  };

  networking = {
    nameservers = [
      "127.0.0.1"
      "1.1.1.1"
      constants.network.lan.gateway
    ];

    # enable NAT
    nat = {
      enable = true;
      externalInterface = "end0";
      internalInterfaces = [ "wg0" ];
    };

    # Open ports in the firewall.
    firewall = {
      enable = true;
      # Trust VPN interface — all peers are personal devices, and this also
      # enables wg0→wg0 forwarding (peer-to-peer traffic like phone → ninho)
      trustedInterfaces = [ "wg0" ];
      allowedTCPPorts = [
        22
        25
        53
        465
        587
        constants.ports.emanote
        7654 # Tang server (Clevis/LUKS auto-unlock advertisement)
      ];
      allowedUDPPorts = [
        53
        constants.network.wireguard.port
      ];
    };

    wireguard.interfaces = {
      wg0 = {
        generatePrivateKeyFile = true;
        ips = [ constants.network.wireguard.rpiIp ];

        # Lower MTU for mobile clients — mobile carriers often filter ICMP
        # "fragmentation needed", breaking PMTUD. WG overhead is 60 B (IPv4) /
        # 80 B (IPv6); defaults (1420) leave little headroom once a carrier
        # adds its own tunnel. 1320 is defensive across carriers.
        mtu = 1320;

        listenPort = constants.network.wireguard.port;
        privateKeyFile = constants.paths.wireguardPrivateKey;

        peers = [
          # List of allowed peers.
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
    };
  };

  # Swap
  swapDevices = [
    {
      device = "/swapfile";
      size = 8192;
    }
  ];
}
