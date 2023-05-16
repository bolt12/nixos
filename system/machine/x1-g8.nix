{ config, pkgs, ... }:

{
  # Use the GRUB 2 boot loader.
  boot = {
    #kernelPackages = pkgs.linuxPackages_5_4;
    kernelPackages = pkgs.linuxPackages_latest;
    loader = {
      efi = {
        canTouchEfiVariables = true;
        # efiSysMountPoint = "/boot/efi";
      };
      systemd-boot.enable = true;
      # grub = {
      #   enable = true;
      #   device = "/dev/nvme0n1p1";
      #   efiSupport = true;
      #   memtest86.enable = true;
      # };
    };

    # Emulate ARM on my system. Useful to deploy NixOS on ARM via nixops
    binfmt.emulatedSystems = [ "aarch64-linux" ];

    kernelModules = [ "acpi_call" ];
    extraModulePackages = with config.boot.kernelPackages; [ acpi_call ];
    blacklistedKernelModules = [ "snd_hda_intel" "snd_soc_skl" ];
    plymouth.enable = true;
    tmpOnTmpfs = true;
    runSize = "50%"; # Size of tmpOnTmpfs defaults to 50% of RAM
    cleanTmpDir = true;
  };

  # Systemd /run/user increase size
  services.logind.extraConfig = "RuntimeDirectorySize=50%";

  powerManagement.enable = true;
  powerManagement.powertop.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
  ];

  services = {
    tlp = {
      enable = true;
      settings = {
        START_CHARGE_THRESH_BAT0 = 85;
        STOP_CHARGE_THRESH_BAT0 = 90;
      };
    };
    blueman.enable = true;
  };

  networking = {
    hostName = "bolt-nixos";
    interfaces.wlp0s20f3.useDHCP = true;
    interfaces.enp0s31f6.useDHCP = true;
    interfaces.enp45s0u2.useDHCP = true;

    defaultGateway = "192.168.1.254";
    nameservers = [ "192.168.1.73" "1.1.1.1" "192.168.1.254" ];
  };

  # Enable WireGuard
  networking.firewall.enable = true;
  networking.firewall.trustedInterfaces = [ "wg0" ];
  networking.firewall.allowedUDPPorts = [ 51820 ];

  networking.wireguard.interfaces = {
    # "wg0" is the network interface name. You can name the interface arbitrarily.
    wg0 = {
      # Determines the IP address and subnet of the client's end of the tunnel interface.
      ips = [ "10.100.0.2/24" ];
      listenPort = 51820; # to match firewall allowedUDPPorts (without this wg uses random port numbers)

      # Path to the private key file.
      #
      # Note: The private key can also be included inline via the privateKey option,
      # but this makes the private key world-readable; thus, using privateKeyFile is
      # recommended.
      privateKeyFile = "/home/bolt/wireguard-keys/private";

      peers = [
        # For a client configuration, one peer entry for the server will suffice.

        {
          # Public key of the server (not a file path).
          publicKey = "zhuXCQYECo/myiKKVHMBPGfbb49JnwifRfsQdHJK9y4=";

          # Forward all the traffic via VPN.
          allowedIPs = [ "0.0.0.0/0" "::0/0" ];
          # Or forward only particular subnets
          #allowedIPs = [ "10.100.0.1" "91.108.12.0/22" ];

          # Set this to the server IP and port.
          endpoint = "rpi-nixos.ddns.net:51820"; # ToDo: route to endpoint not automatically configured https://wiki.archlinux.org/index.php/WireGuard#Loop_routing https://discourse.nixos.org/t/solved-minimal-firewall-setup-for-wireguard-client/7577

          # Send keepalives every 25 seconds. Important to keep NAT tables alive.
          persistentKeepalive = 25;
        }
      ];
    };
  };


  # Intel UHD 620 Hardware Acceleration
  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
    extraPackages = with pkgs; [
      vaapiIntel
      vaapiVdpau
      libvdpau-va-gl
      intel-media-driver # only available starting nixos-19.03 or the current nixos-unstable
    ];
  };

  hardware.pulseaudio.extraConfig = ''
    load-module module-alsa-sink   device=hw:0,0 channels=4
    load-module module-alsa-source device=hw:0,6 channels=4
  '';
}
