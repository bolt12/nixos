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
  imports = [ ../../common/services/unbound-adblock.nix ];
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
    # Provision the journal dir outside the service sandbox. emanote's
    # ProtectHome=tmpfs hides /home and BindReadOnlyPaths=journalDir fails if the
    # dir is absent, so an in-sandbox ExecStartPre mkdir cannot create it.
    tmpfiles.rules = [
      "d ${journalDir} 0755 ${emanoteUser} users - -"
    ];
    services = {
      iwd.serviceConfig.Restart = "always";

      # Emanote LAN journal gateway (see let-binding for scoping rationale)
      emanote = {
        enable = true;
        description = "Emanote web server";
        after = [ "network.target" ];
        wantedBy = [ "default.target" ];

        serviceConfig = {
          Type = "simple";
          User = emanoteUser;
          Group = "users";
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

      # Wake ninho on boot: when mains power returns the RPi auto-reboots, so
      # send a WoL magic packet to bring the home server back up unattended.
      # Fires on every boot; a packet to an already-on ninho is simply ignored.
      wake-ninho = {
        description = "Send Wake-on-LAN magic packet to ninho";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStartPre = "${pkgs.coreutils}/bin/sleep 5";
          ExecStart = "${pkgs.wakeonlan}/bin/wakeonlan ${constants.network.ninho.lanMac}";
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
      libraspberrypi
      neovim
      unbound-full
      unzip
      wakeonlan # send WoL magic packets (wake-ninho service)
      wget
      # Add emanote to system packages as well for manual use
      emanotePackage
    ];

  };

  services = {
    # Tang server for Clevis/LUKS auto-unlock on ninho
    # Serves key advertisement on port 7654 for initrd Clevis clients
    tang = {
      enable = true;
      listenStream = [ (toString constants.ports.tang) ];
      ipAddressAllow = [
        "127.0.0.0/8"
        constants.network.lan.subnet
      ];
    };

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
  };

  # LAN adblock recursive DNS (Tang clients + local devices). Binds all
  # interfaces because the LAN is trusted; the public tunnel-facing copy of this
  # resolver runs on the hub.
  services.adblockDns = {
    enable = true;
    user = "bolt";
    interfaces = [ "0.0.0.0" ];
    accessControl = [
      "192.168.0.0/16 allow"
    ];
  };

  networking = {
    nameservers = [
      "127.0.0.1"
      "1.1.1.1"
      constants.network.lan.gateway
    ];

    # Open ports in the firewall.
    firewall = {
      enable = true;
      allowedTCPPorts = [
        22
        53
        constants.ports.emanote
        constants.ports.tang # Tang server (Clevis/LUKS auto-unlock advertisement)
      ];
      allowedUDPPorts = [
        53
      ];
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
