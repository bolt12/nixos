{ config, pkgs, ... }:

{
  # Use the GRUB 2 boot loader.
  boot = {
    kernelPackages = pkgs.linuxPackages_4_19;
    loader = {
      grub = {
        enable  = true;
        version = 2;
        device = "/dev/sda"; # or "nodev" for efi only
      };
    };
    cleanTmpDir = true;
  };

  powerManagement.enable = true;
  powerManagement.powertop.enable = true;

  services = {
    tlp.enable = true;
    blueman.enable = true;
  };

  networking = {
    hostName = "bolt-nixos";
    interfaces.wls1.useDHCP = true;
    interfaces.enp0s25.useDHCP = true;
  };

}
