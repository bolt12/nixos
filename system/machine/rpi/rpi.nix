# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

let emanote = import (builtins.fetchTarball "https://github.com/srid/emanote/archive/master.tar.gz");
    emanotePkg = emanote.packages.aarch64-linux.default;
in
{
  nixpkgs.overlays = [
    (self: super: {
      firmwareLinuxNonfree = super.firmwareLinuxNonfree.overrideAttrs (old: {
        version = "2020-12-18";
        src = pkgs.fetchgit {
          url = "https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git";
          rev = "b79d2396bc630bfd9b4058459d3e82d7c3428599";
          sha256 = "1rb5b3fzxk5bi6kfqp76q1qszivi0v1kdz1cwj2llp5sd9ns03b5";
        };
        outputHash = "1p7vn2hfwca6w69jhw5zq70w44ji8mdnibm1z959aalax6ndy146";
      });
    })
  ];

  nixpkgs.config.allowUnfree = true;

  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix

      # emanote.homeManagerModule
    ];

  # Use the extlinux boot loader. (NixOS wants to enable GRUB by default)
  boot.loader.grub.enable = false;
  # Enables the generation of /boot/extlinux/extlinux.conf
  boot.loader.generic-extlinux-compatible.enable = true;

  networking.hostName = "rpi-nixos"; # Define your hostname.
  networking.wireless.interfaces = [ "wlan0" ];
  systemd.services.iwd.serviceConfig.Restart = "always";
  networking.networkmanager.enable = true;
  networking.networkmanager.wifi.backend = "iwd";
  networking.wireless.iwd.enable = true;

  # Emanote systemd service
  systemd.services.emanote = {
    enable = true;
    description = "Emanote web server";
    after = [ "network.target" ];
    wantedBy = [ "default.target" ];

    serviceConfig = {
      ExecStart = ''
        ${emanotePkg}/bin/emanote --layers "/home/bolt/journal" run --host=0.0.0.0 --port=7000
      '';
    };
  };

  # Preserve space by sacrificing documentation and history
  documentation.nixos.enable = false;
  nix.gc.automatic = true;
  nix.gc.options = "--delete-older-than 30d";
  boot.cleanTmpDir = true;

  # Set your time zone.
  time.timeZone = "Europe/Lisbon";

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  #networking.useDHCP = false;
  # networking.interfaces.eth0.useDHCP = true;

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  # };

  # Enable the X11 windowing system.
  # services.xserver.enable = true;

  # Enable support for Pi firmware blobs
  hardware.enableRedistributableFirmware = false;
  hardware.firmware = [ pkgs.raspberrypiWirelessFirmware ];

  # Configure keymap in X11
  # services.xserver.layout = "us";
  # services.xserver.xkbOptions = "eurosign:e";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Docker container services

  # virtualisation.docker.enable = true;
  virtualisation.oci-containers.backend = "podman";

  virtualisation.oci-containers.containers = {
  };

  # Enable sound.
  sound.enable = true;
  hardware.pulseaudio.enable = false;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.bolt = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "podman" ]; # Enable ‘sudo’ for the user.
    openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHKTf4Bb2BBymwZvxPtxEefspOPTACPn3HqrRiWAMJEJ armandoifsantos@gmail.com" ];
  };

  users.users.root = {
    openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHKTf4Bb2BBymwZvxPtxEefspOPTACPn3HqrRiWAMJEJ armandoifsantos@gmail.com" ];
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages =
    with pkgs; [
      libraspberrypi
      neovim
      wget
      git
      git-annex
      git-annex-utils
      unzip
      wireguard-tools
      iptables
      unbound-full

      emanotePkg
    ];

  # enable NAT
  networking.nat.enable = true;
  networking.nat.externalInterface = "wlan0";
  networking.nat.internalInterfaces = [ "wg0" ];

  # Open ports in the firewall.
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 25 53 465 587 7000 ];
    allowedUDPPorts = [ 53 51820 ];
  };

  networking.wireguard.interfaces = {
    # "wg0" is the network interface name. You can name the interface arbitrarily.
    wg0 = {
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
      privateKeyFile = "/home/bolt/wireguard-keys/private";

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
          publicKey = "GhHsMo+0PqWAbflsSuphRzN4YyOzOjVKV31O6gjOIFQ=";
          # List of IPs assigned to this peer within the tunnel subnet. Used to configure routing.
          allowedIPs = [ "10.100.0.3/32" ];
        }
      ];
    };
  };

  # Setting up Unbound as a recursive DNS Server
  # Check https://docs.pi-hole.net/guides/dns/unbound/#configure-unbound
  services.unbound = {
    enable = true;
    user = "root";
    settings = {
      include = "/run/keys/unbound-ads";
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

        access-control = [ "192.168.0.0/16 allow" ];
        qname-minimisation = "yes";
      };
      remote-control = {
        control-enable = true;
      };
    };
  };

  networking = {
    useDHCP = false;
    interfaces.wlan0.ipv4.addresses = [ {
      address = "192.168.1.73";
      prefixLength = 24;
    } ];
    defaultGateway = "192.168.1.254";
    nameservers = [ "127.0.0.1" "1.1.1.1" "192.168.1.254" ];
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  services.openssh.permitRootLogin = "yes";
  services.openssh.forwardX11 = true;

  # Swap
  swapDevices = [{ device = "/swapfile"; size = 8192; }];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.05"; # Did you read the comment?
}
