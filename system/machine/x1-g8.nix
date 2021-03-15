{ config, pkgs, ... }:

{
  # imports = [
  #   "${builtins.fetchGit { url = "https://github.com/NixOS/nixos-hardware.git"; }}/lenovo/thinkpad/x1/7th-gen"
  # ];

  # Use the GRUB 2 boot loader.
  boot = {
    # kernelPackages = pkgs.linuxPackages_4_19;
    kernelPackages = pkgs.linuxPackages_latest;
    loader = {
      efi = {
        canTouchEfiVariables = true;
        systemd-boot.enable = true;
        # efiSysMountPoint = "/boot/efi";
      };
      # grub = {
      #   enable = true;
      #   device = "/dev/nvme0n1p1";
      #   efiSupport = true;
      #   memtest86.enable = true;
      # };
    };
    extraModulePackages = with config.boot.kernelPackages; [ acpi_call ];
    plymouth.enable = true;
    tmpOnTmpfs = true;
    cleanTmpDir = true;
  };

  powerManagement.enable = true;
  powerManagement.powertop.enable = true;

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
    interfaces.wls1.useDHCP = true;
    interfaces.enp0s25.useDHCP = true;
  };


  # Intel UHD 620 Hardware Acceleration
  hardware.opengl = {
    extraPackages = with pkgs; [
      vaapiIntel
      vaapiVdpau
      libvdpau-va-gl
      intel-media-driver # only available starting nixos-19.03 or the current nixos-unstable
    ];
  };
}
