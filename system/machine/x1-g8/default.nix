{ config, pkgs, inputs, ... }:

let

  unstable = import inputs.nixpkgs-unstable {
    overlays = [
    ];
    system = config.nixpkgs.system;
  };

in
{
  # Use the GRUB 2 boot loader.
  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    loader         = {
      efi = {
        canTouchEfiVariables = true;
      };
      systemd-boot.enable = true;
    };

    # Emulate ARM on my system. Useful to deploy NixOS on ARM via nixops
    binfmt.emulatedSystems = [ "aarch64-linux" ];

    kernelModules       = [ "acpi_call" ];
    extraModulePackages =
      with config.boot.kernelPackages; [ acpi_call ];
    extraModprobeConfig = ''
      options snd-intel-dspcfg dsp_driver=3
      options snd_sof sof_debug=128
    '';
    blacklistedKernelModules = [ "snd_soc_skl" ];
    plymouth.enable          = true;
    tmp = {
      useTmpfs    = true;
      cleanOnBoot = true;
    };
    runSize = "75%"; # Size of useTmpfs defaults to 50% of RAM
  };

  # Intel UHD 620 Hardware Acceleration
  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
    extraPackages = with pkgs; [
      vaapiIntel
      vaapiVdpau
      libvdpau-va-gl
      intel-media-driver # only available starting nixos-19.03 or the current nixos-unstable
    ];
  };

  powerManagement = {
    enable          = true;
    powertop.enable = true;
  };

  environment = {
    etc = {
    "greetd/environments".text = ''
      sway
      bash
    '';
    };

    # Needed for java apps/fonts
    variables._JAVA_OPTIONS                       =
      "-Dawt.useSystemAAFontSettings = on -Dswing.aatext = true -Dsun.java2d.xrender = true";
    variables._JAVA_AWT_WM_NONREPARENTING         = "1";
    variables.MOZ_DISABLE_RDD_SANDBOX             = "1";
    variables.MOZ_ENABLE_WAYLAND                  = "1";
    variables.XDG_CURRENT_DESKTOP                 = "sway";
    variables.XDG_SESSION_TYPE                    = "wayland";
    variables.SDL_VIDEODRIVER                     = "wayland";
    variables.QT_QPA_PLATFORM                     = "wayland";
    variables.QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    variables.ECORE_EVAS_ENGINE                   = "wayland_egl";
    variables.ELM_ENGINE                          = "wayland_egl";
    variables.EDITOR                              = "nvim";
    variables.VISUAL                              = "nvim";
    variables.NIXOS_OZONE_WL                      = "1";

    # List packages installed in system profile. To search, run:
    # $ nix search wget
    systemPackages = with pkgs; [
    ];
  };

  programs = {
    light.enable = true;
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

    # Fix obinskit permissions
    udev.extraRules = ''
      SUBSYSTEM=="input", GROUP="input", MODE="0666"

      # For ANNE PRO 2
      SUBSYSTEM=="usb", ATTRS{idVendor}=="04d9", ATTRS{idProduct}=="8008", MODE="0666", GROUP="plugdev"
      KERNEL=="hidraw*", ATTRS{idVendor}=="04d9", ATTRS{idProduct}=="8008", MODE="0666", GROUP="plugdev"
      SUBSYSTEM=="usb", ATTRS{idVendor}=="04d9", ATTRS{idProduct}=="8009", MODE="0666", GROUP="plugdev"
      KERNEL=="hidraw*", ATTRS{idVendor}=="04d9", ATTRS{idProduct}=="8009", MODE="0666", GROUP="plugdev"

      ## For ANNE PRO
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="5710", MODE="0666", GROUP="plugdev"
      KERNEL=="hidraw*", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="5710", MODE="0666", GROUP="plugdev"
    '';

    flatpak.enable = true;
  };

  # Firefox NixOS wiki recommends
  xdg = {
    portal = {
      enable = true;
      configPackages = [
        pkgs.xdg-desktop-portal
        pkgs.xdg-desktop-portal-gtk
        pkgs.xdg-desktop-portal-wlr
        pkgs.xdg-desktop-portal-gnome
      ];
      wlr.enable = true;
    };
  };

  sound.enable = true;

  networking = {
    interfaces.wlp0s20f3.useDHCP = true;
    interfaces.enp0s31f6.useDHCP = true;
    interfaces.enp45s0u2.useDHCP = true;

    wireguard.interfaces = {
      # "wg0" is the network interface name. You can name the interface arbitrarily.
      wg0 = {
        # Determines the IP address and subnet of the client's end of the tunnel interface.
        ips = [ "10.100.0.2/24" ];
        listenPort = 51820; # to match firewall allowedUDPPorts (without this wg uses random port numbers)

        # Path to the private key file.
        #
        # Note: The private key can also be included inline via the privateKey option,
        # but this makes the private key world-readable; thus, using privateKeyFile is
        # recommended.
        privateKeyFile = "/home/bolt/wireguard-keys/private";

        peers = [
          # For a client configuration, one peer entry for the server will suffice.

          {
            # Public key of the server (not a file path).
            publicKey = "MOdy/dZZKa4Ra4zGoQZ30FtXkZxHdpLgBH+DTG2YQRc=";

            # Forward all the traffic via VPN.
            allowedIPs = [ "0.0.0.0/0" "::0/0" ];
            # Or forward only particular subnets
            #allowedIPs = [ "10.100.0.1" "91.108.12.0/22" ];

            # Set this to the server IP and port.
            endpoint = "rpi-nixos.ddns.net:51820";

            # Send keepalives every 25 seconds. Important to keep NAT tables alive.
            persistentKeepalive = 25;
          }
        ];
      };
    };
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
