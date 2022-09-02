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
  };

  # Intel UHD 620 Hardware Acceleration
  hardware.opengl = {
    enable = true;
    driSupport = true;
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
