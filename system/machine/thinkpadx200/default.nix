{ config, pkgs, inputs, ... }:

let

  unstable = import nixpkgs-unstable {
    overlays = [
    ];
    system = config.nixpkgs.system;
  };

in
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

  powerManagement = {
    enable          = true;
    powertop.enable = true;
  };


  services = {

    # Systemd /run/user increase size
    logind.extraConfig = "RuntimeDirectorySize=75%";

    dbus.enable = true;

    # Enable the OpenSSH daemon.
    openssh.enable = true;

    # Enable CUPS to print documents.
    printing.enable = true;

    # Firefox NixOs wiki recommends
    pipewire = {
      enable             = true;
      audio.enable       = true;
      alsa.enable        = true;
      alsa.support32Bit  = true;
      pulse.enable       = true;
      # jack.enable      = true;
      wireplumber.enable = true;
    };

    # USB Automounting
    gvfs.enable = true;

    udisks2.enable = true;

    devmon.enable = true;

    upower.enable = true;

    greetd = {
      enable   = true;
      settings = {
        default_session = {
          command = "cage -s -- gtkgreet";
          user    = "bolt";
        };
      };
    };

    xserver = {
      enable     = true;
      layout     = "us,pt";
      xkbOptions = "caps:escape, grp:shifts_toggle";

      libinput = {
        enable = true;
        touchpad.clickMethod = "clickfinger";
      };

      videoDrivers = [ "intel" ];
    };

    tlp = {
      enable   = true;
      settings = {
        START_CHARGE_THRESH_BAT0 = 85;
        STOP_CHARGE_THRESH_BAT0  = 90;
      };
    };

    blueman.enable = true;

    flatpak.enable = true;
  };

  networking = {
    hostName = "bolt-nixos";
    interfaces.wls1.useDHCP = true;
    interfaces.enp0s25.useDHCP = true;
  };

  security = {
    pam.services.swaylock.text = ''
      # PAM configuration file for the swaylock screen locker. By default, it includes
      # the 'login' configuration file (see /etc/pam.d/login)
      auth include login
    '';

    polkit.enable = true;

    rtkit.enable = true;
  };

}
