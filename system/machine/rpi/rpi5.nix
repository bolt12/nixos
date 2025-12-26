# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, lib, pkgs, raspberry-pi-nix, inputs, ... }@attrs:

let
  # Get emanote from the flake input
  emanotePackage = inputs.emanote.packages.${pkgs.system}.default;
in
{
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
    settings.trusted-users = [ "bolt" "deck" "root" "@wheel" ];
    settings.experimental-features = [ "nix-command" "flakes" ];
  };

  systemd = {
    services = {
      iwd.serviceConfig.Restart = "always";

      # Emanote systemd service - now using the flake input version
      emanote = {
        enable = true;
        description = "Emanote web server";
        after = [ "network.target" ];
        wantedBy = [ "default.target" ];

        serviceConfig = {
          Type = "simple";
          User = "bolt";
          Group = "users";
          # Ensure the journal directory exists and is owned by bolt
          ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /home/bolt/journal";
          ExecStart = ''
            ${emanotePackage}/bin/emanote --layers "/home/bolt/journal" run --no-ws --host=0.0.0.0 --port=7000
          '';
          Restart = "always";
          RestartSec = "10";

          # Security hardening
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = "tmpfs";
          ReadWritePaths = [ "/home/bolt/journal" ];
          BindReadOnlyPaths = [ "/home/bolt/journal" ];
        };
      };
    };
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment = {
    systemPackages =
      with pkgs; [
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

    etc."unbound/unbound-ads".text = builtins.readFile ./unbound-ads/unbound_ad_servers;
  };

  services = {
    # PostgreSQL configuration for RPI 5 (16KB page size compatibility)
    postgresql = {
      enable = true;
      enableJIT = false; # Disable JIT on ARM for stability
    };

    # Immich - Self-hosted photo and video backup solution
    # Access at http://<rpi-ip>:2283
    immich = {
      enable = true;
      host = "0.0.0.0"; # Listen on all interfaces
      port = 2283; # Default Immich port
      openFirewall = true; # Automatically opens port 2283 in firewall

      # Database settings (uses PostgreSQL configured above)
      database = {
        enable = true;
        createDB = true;
        # Disable Vectors to avoid jemalloc 16KB page size issues on RPI 5
        enableVectors = false;
      };

      machine-learning.enable = false;

      # Redis for job queuing and caching
      redis.enable = true;
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
        include = "/etc/unbound/unbound-ads";
        server = {
          verbosity = 2;
          log-queries = "yes";

          serve-expired = "yes";
          serve-expired-ttl = 86400;

          interface = [ "0.0.0.0" ];
          do-ip4 = "yes";
          do-udp = "yes";
          do-tcp = "yes";

          harden-glue = "yes";
          harden-dnssec-stripped = "yes";
          use-caps-for-id = "no";
          edns-buffer-size = "1232";
          prefetch = "yes";

          num-threads = 1;
          so-rcvbuf = "1m";

          private-address = [
            "192.168.0.0/16"
            "169.254.0.0/16"
            "172.16.0.0/12"
            "10.0.0.0/8"
          ];

          access-control = [
            "192.168.0.0/16 allow"
            "10.100.0.0/16 allow"
          ];
          qname-minimisation = "yes";
        };
        remote-control = {
          control-enable = true;
        };
      };
    };
  };

  networking = {
    nameservers = [ "127.0.0.1" "1.1.1.1" "192.168.1.254" ];

    # enable NAT
    nat = {
      enable = true;
      externalInterface = "wlan0";
      internalInterfaces = [ "wg0" ];
    };

    # Open ports in the firewall.
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 25 53 465 587 7000 ];
      allowedUDPPorts = [ 53 51820 ];
    };

    wireguard.interfaces = {
      # "wg0" is the network interface name. You can name the interface arbitrarily.
      wg0 = {
        generatePrivateKeyFile = true;
        # Determines the IP address and subnet of the server's end of the tunnel interface.
        ips = [ "10.100.0.1/24" ];

        # The port that WireGuard listens to. Must be accessible by the client.
        listenPort = 51820;

        # This allows the wireguard server to route your traffic to the internet and hence be like a VPN
        # For this to work you have to set the dnsserver IP of your router (or dnsserver of choice) in your clients
        postSetup = ''
          ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s 10.100.0.0/24 -o wlan0 -j MASQUERADE
        '';

        # This undoes the above command
        postShutdown = ''
          ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s 10.100.0.0/24 -o wlan0 -j MASQUERADE
        '';

        # Path to the private key file.
        privateKeyFile = "/home/bolt/wireguard-keys/privatekey";

        peers = [
          # List of allowed peers.
          { # X1 G8 Carbon
            publicKey = "hUUAT7Dny5aFJHvwUE9poaaAcEheyEDMhff5AwQPiRk=";
            allowedIPs = [ "10.100.0.2/32" ];
          }
          { # Bolt Android phone
            publicKey = "KP3wpBB2zEsJnSHzVISjJ1gmUAAWS/rOa1rgBJ5uBkM=";
            allowedIPs = [ "10.100.0.3/32" ];
          }
          { # Steam Deck
            publicKey = "3w9nh1xsGDAZRF7QSEo9N8oEwpL5a+g6wGscNC+PbkQ=";
            allowedIPs = [ "10.100.0.4/32" ];
          }
          { # Supernote
            publicKey = "OcLbbW78TqTqFSdn24oCAfRt1U+VlSilAfeEspiqUR4=";
            allowedIPs = [ "10.100.0.5/32" ];
          }
          { # Pollard Android phone
            publicKey = "QFbI4k1IANbEVUpPEE71QF71aSQRgdr4OqJnwtxUkn0=";
            allowedIPs = [ "10.100.0.6/32" ];
          }
          { # Ninho Home Server
            publicKey = "xSZiLvopp4Q/eMMxYyzQrdmvt/dyejc2CR4/dzsm5gw=";
            allowedIPs = [ "10.100.0.100/32" ];
          }
        ];
      };
    };
  };

  # Swap
  swapDevices = [{ device = "/swapfile"; size = 8192; }];
}
