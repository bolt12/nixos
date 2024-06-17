# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, lib, pkgs, raspberry-pi-nix, inputs, ... }@attrs:

{
  nixpkgs = {
    config.allowUnfree = true;
  };

  # Disable libcamera (not compiling)
  raspberry-pi-nix.libcamera-overlay.enable = false;

  networking = {
    hostName = "rpi-nixos";
    wireless = {
      interfaces = [ "wlan0" ];
      iwd.enable = true;
    };

    nameservers = [ "127.0.0.1" "1.1.1.1" "192.168.1.254" ];

    networkmanager = {
      enable = true;
      wifi.backend = "iwd";
    };

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

  # Set your time zone.
  time.timeZone = "Europe/Lisbon";

  hardware = {
    bluetooth.enable = true;

    raspberry-pi = {
      config = {
        all = {
          base-dt-params = {
            # enable autoprobing of bluetooth driver
            # https://github.com/raspberrypi/linux/blob/c8c99191e1419062ac8b668956d19e788865912a/arch/arm/boot/dts/overlays/README#L222-L224
            krnbt = {
              enable = true;
              value = "on";
            };
          };
        };
      };
    };
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Docker container services

  # virtualisation.docker.enable = true;
  virtualisation = {
    oci-containers.backend = "podman";
    oci-containers.containers = {
    };
  };

  # Enable sound.
  sound.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users = {
    users = {
      bolt = {
        initialPassword = "tlob";
        isNormalUser = true;
        extraGroups =
          [ "audio"
            "video"
            "wheel"
            "networkmanager"
            "docker"
            "podman"
            "root"
          ];

        openssh.authorizedKeys.keys =
            [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHKTf4Bb2BBymwZvxPtxEefspOPTACPn3HqrRiWAMJEJ armandoifsantos@gmail.com" ];
    };
      root = {
        openssh.authorizedKeys.keys =
          [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHKTf4Bb2BBymwZvxPtxEefspOPTACPn3HqrRiWAMJEJ armandoifsantos@gmail.com" ];
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
        neovim
        unbound-full
        wireguard-tools
      ];

    etc."unbound/unbound-ads".text = builtins.readFile ./unbound-ads/unbound_ad_servers;
  };

  services = {
    # Enable the OpenSSH daemon.
    openssh = {
      enable          = true;
      settings = {
        X11Forwarding = true;
        PermitRootLogin = "yes";
      };
    };

  };

  # Swap
  swapDevices = [{ device = "/swapfile"; size = 8192; }];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?
}
