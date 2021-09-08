# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, lib, pkgs, ... }:

{

  nixpkgs.overlays = [
    (self: super: {
      firmwareLinuxNonfree = super.firmwareLinuxNonfree.overrideAttrs (old: {
        version = "2020-12-18";
        src = pkgs.fetchgit {
          url =
            "https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git";
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
    ];

  # Use the extlinux boot loader. (NixOS wants to enable GRUB by default)
  boot.loader.grub.enable = false;
  # Enables the generation of /boot/extlinux/extlinux.conf
  boot.loader.generic-extlinux-compatible.enable = true;
  # if you have a Raspberry Pi 2 or 3, pick this:
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # A bunch of boot parameters needed for optimal runtime on RPi 3b+
  boot.kernelParams = ["cma=256M"];
  boot.loader.raspberryPi.enable = true;
  boot.loader.raspberryPi.version = 3;
  boot.loader.raspberryPi.uboot.enable = true;

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
  networking.useDHCP = false;
  networking.interfaces.eth0.useDHCP = true;

  networking.hostName = "rpi-nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.wireless.interfaces = [ "wlan0" ];
  networking.interfaces.wlan0.ipv4.addresses = [{
    # I used static IP over WLAN because I want to use it as local DNS resolver
    address = "192.168.1.10";
    prefixLength = 24;
  }];

  systemd.services.iwd.serviceConfig.Restart = "always";
  networking.networkmanager.enable = true;
  networking.networkmanager.wifi.backend = "iwd";
  networking.wireless.iwd.enable = true;

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
  hardware.enableRedistributableFirmware = true;

  # Configure keymap in X11
  services.xserver.layout = "us";
  services.xserver.xkbOptions = "eurosign:e";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable Avahi for service discovery
  services.avahi = {
      enable = true;
      publish = {
          enable = true;
          addresses = true;
          workstation = true;
      };
  };

  # Docker container services

  virtualisation.docker.enable = true;

  virtualisation.oci-containers.containers = {
    rainloop = {
      image = "martadinata666/rainloop";
      ports = [ "8085:80" ];
      volumes = [ "data:/var/www/localhost/htdocs/data" ];
    };
    pihole = {
      image = "pihole/pihole:latest";
      ports = [ "53:53/tcp" "53:53/udp" "67:67/udp" "8086:80/tcp" ];
      volumes = [ "./etc-pihole/:/etc/pihole/" "./etc-dnsmasq.d/:/etc/dnsmasq.d/" ];
      extraOptions = [ "--cap-add=NET_ADMIN" "--dns=127.0.0.1" "--dns=1.1.1.1" "-e TZ:'Europe/Lisbon'" ];
    };
  };


  # Enable sound.
  sound.enable = true;
  hardware.pulseaudio.enable = true;

  boot.loader.raspberryPi.firmwareConfig = ''
    dtparam=audio=on
  '';

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  # users.mutableUsers = false;     # Remove any users not defined in here
  users.users.bolt = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "docker" ]; # Enable ‘sudo’ for the user.
    openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHKTf4Bb2BBymwZvxPtxEefspOPTACPn3HqrRiWAMJEJ armandoifsantos@gmail.com" ];
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    libraspberrypi
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    git
    noip
    rainloop-standard
    unzip
    nginx
  ];

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

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Swap
  swapDevices = [ { device = "/swapfile"; size = 1024; } ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.05"; # Did you read the comment?

}
