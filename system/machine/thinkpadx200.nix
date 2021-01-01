{ config, pkgs, ... }:

{
  # Use the GRUB 2 boot loader.
  boot = {
    # kernelPackages = pkgs.linuxPackages_5_8;
    loader = {
      grub = {
        enable  = true;
        version = 2;
        device = "/dev/sda"; # or "nodev" for efi only
      };
    };
  };

  networking = {
    hostName = "bolt-nixos";
    interfaces.wls1.useDHCP = true;
    interfaces.enp0s25.useDHCP = true;
  };

  services.xserver = {
    xrandrHeads = [
      { output = "HDMI-1";
        primary = true;
        monitorConfig = ''
          Option "PreferredMode" "1280x800"
          Option "Position" "0 0"
        '';
      }
      { output = "eDP-1";
        monitorConfig = ''
          Option "PreferredMode" "1280x800"
          Option "Position" "0 0"
        '';
      }
    ];
    resolutions = [
      { x = 1280; y = 800; }
      { x = 2048; y = 1152; }
      { x = 1920; y = 1080; }
      { x = 2560; y = 1440; }
      { x = 3072; y = 1728; }
      { x = 3840; y = 2160; }
    ];
  };
}
