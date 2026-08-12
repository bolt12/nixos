{
  config,
  pkgs,
  inputs,
  ...
}:

# NOTE: this machine is an incomplete stub. It has no hardware-configuration.nix
# (no fileSystems / root filesystem), so its toplevel does not build and it is
# excluded from flake checks. Run `nixos-generate-config` on the X200 and add the
# result before deploying or enabling CI for it.

{
  # Use the GRUB 2 boot loader.
  boot = {
    # linuxPackages_4_19 was removed from nixpkgs 26.05 (EOL upstream), which
    # left this config un-evaluable. The X200 (Core 2 Duo, GM45) has no special
    # kernel needs, so track the current 6.12 LTS.
    kernelPackages = pkgs.linuxPackages_6_12;
    loader = {
      grub = {
        enable = true;
        device = "/dev/sda"; # or "nodev" for efi only
      };
    };
    tmp.cleanOnBoot = true;
  };

  powerManagement = {
    enable = true;
    powertop.enable = true;
  };

  services = {

    # Systemd /run/user increase size
    logind.settings.Login.RuntimeDirectorySize = "75%";

    dbus.enable = true;

    # Enable the OpenSSH daemon.
    openssh.enable = true;

    # Enable CUPS to print documents.
    printing.enable = true;

    # Firefox NixOs wiki recommends
    pipewire = {
      enable = true;
      audio.enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      # jack.enable      = true;
      wireplumber.enable = true;
    };

    # USB Automounting
    gvfs.enable = true;

    udisks2.enable = true;

    devmon.enable = true;

    upower.enable = true;

    greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "cage -s -- gtkgreet";
          user = "bolt";
        };
      };
    };

    xserver = {
      enable = true;
      xkb = {
        layout = "us,pt";
        options = "caps:escape, grp:shifts_toggle";
      };

      videoDrivers = [ "intel" ];
    };

    libinput = {
      enable = true;
      touchpad.clickMethod = "clickfinger";
    };

    tlp = {
      enable = true;
      settings = {
        START_CHARGE_THRESH_BAT0 = 85;
        STOP_CHARGE_THRESH_BAT0 = 90;
      };
    };

    blueman.enable = true;

    flatpak.enable = true;
  };

  # Flatpak requires XDG desktop portals with an implementation (asserted by the
  # flatpak module). gtk covers this X11/greetd session.
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  networking = {
    hostName = "bolt-x200";
    useDHCP = true;
  };

  # The desktop home-manager config is attached for user bolt (flake.nix
  # mkSystem hmUser), and greetd logs bolt in, so the account must exist.
  users.users.bolt = {
    isNormalUser = true;
    home = "/home/bolt";
    description = "Armando Santos";
    extraGroups = [
      "wheel"
      "networkmanager"
      "audio"
      "video"
    ];
  };

  security = {
    # Empty attrset gives swaylock the NixOS default PAM stack (auth include
    # login), matching x1-g8; no need for the deprecated raw `.text` form.
    pam.services.swaylock = { };

    polkit.enable = true;

    rtkit.enable = true;
  };

}
