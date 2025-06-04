# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, lib, pkgs, raspberry-pi-nix, inputs, ... }@attrs:

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
  };

  systemd = {
    services = {
      iwd.serviceConfig.Restart = "always";

      # Emanote systemd service
      emanote = {
        enable = true;
        description = "Emanote web server";
        after = [ "network.target" ];
        wantedBy = [ "default.target" ];

        serviceConfig = {
          ExecStart = ''
            ${pkgs.emanote}/bin/emanote --layers "/home/bolt/journal" run --host=0.0.0.0 --port=7000
          '';
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
        git-annex-utils
        inputs.emanote
        iptables
        libraspberrypi
        neovim
        unbound-full
        unzip
        wget
        wireguard-tools
      ];

    etc."unbound/unbound-ads".text = builtins.readFile ./unbound-ads/unbound_ad_servers;
  };

  services = {

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
          log-queries= "yes";

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

          private-address = [ "192.168.0.0/16"
                              "169.254.0.0/16"
                              "172.16.0.0/12"
                              "10.0.0.0/8"
                            ];

          access-control = [ "192.168.0.0/16 allow"
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
      enable             = true;
      externalInterface  = "wlan0";
      internalInterfaces = [ "wg0" ];
    };

    # Open ports in the firewall.
    firewall = {
      enable          = true;
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
        #
        # Note: The private key can also be included inline via the privateKey option,
        # but this makes the private key world-readable; thus, using privateKeyFile is
        # recommended.
        privateKeyFile = "/home/bolt/wireguard-keys/privatekey";

        peers = [
          # List of allowed peers.
          { # X1 G8 Carbon
            # Public key of the peer (not a file path).
            publicKey = "hUUAT7Dny5aFJHvwUE9poaaAcEheyEDMhff5AwQPiRk=";
            # List of IPs assigned to this peer within the tunnel subnet. Used to configure routing.
            allowedIPs = [ "10.100.0.2/32" ];
          }
          { # Android phone
            # Public key of the peer (not a file path).
            publicKey = "KP3wpBB2zEsJnSHzVISjJ1gmUAAWS/rOa1rgBJ5uBkM=";
            # List of IPs assigned to this peer within the tunnel subnet. Used to configure routing.
            allowedIPs = [ "10.100.0.3/32" ];
          }
          { # Steam DEck
            # Public key of the peer (not a file path).
            publicKey = "N1VIBzM8r1g0ItVXPrAopAGN8R+Dpqcmm8BbPKHOBx8=";
            # List of IPs assigned to this peer within the tunnel subnet. Used to configure routing.
            allowedIPs = [ "10.100.0.4/32" ];
          }
          { # Supernote
            # Public key of the peer (not a file path).
            publicKey = "OcLbbW78TqTqFSdn24oCAfRt1U+VlSilAfeEspiqUR4=";
            # List of IPs assigned to this peer within the tunnel subnet. Used to configure routing.
            allowedIPs = [ "10.100.0.5/32" ];
          }
        ];
      };
    };
  };

  # Swap
  swapDevices = [{ device = "/swapfile"; size = 8192; }];
}
