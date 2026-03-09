# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, lib, pkgs, raspberry-pi-nix, inputs, ... }@attrs:

{
  # bcm2712 for rpi 5
  raspberry-pi-nix.board = "bcm2712";

  # Disable libcamera (not compiling)
  raspberry-pi-nix.libcamera-overlay.enable = false;

  networking = {
    hostName = "rpi-nixos";
    wireless = {
      interfaces = [ "wlan0" ];
      iwd.enable = true;
    };

    networkmanager = {
      enable = true;
      wifi.backend = "iwd";
      wifi.powersave = false;
    };

  };

  # Set your time zone.
  time.timeZone = "Europe/Lisbon";

  users = {
    users = {
      bolt = {
        initialPassword = "tlob";
        isNormalUser = true;
        extraGroups = [
          "audio"
          "video"
          "wheel"
          "networkmanager"
          "docker"
          "podman"
          "root"
        ];

        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHKTf4Bb2BBymwZvxPtxEefspOPTACPn3HqrRiWAMJEJ armandoifsantos@gmail.com"
        ];
      };

      root = {
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHKTf4Bb2BBymwZvxPtxEefspOPTACPn3HqrRiWAMJEJ armandoifsantos@gmail.com"
        ];
      };
    };
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

  hardware = {
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

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}
