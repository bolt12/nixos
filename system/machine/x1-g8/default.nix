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
    kernelPackages = pkgs.linuxPackages_6_12;
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
    # extraModprobeConfig = ''
    #   options snd-hda-intel model=generic
    #   options snd slots=snd-hda-intel
    #   options snd-intel-dspcfg dsp_driver=1
    #   options snd_sof sof_debug=128
    # '';
    blacklistedKernelModules = [ ]; # "snd_soc_skl" ];
    plymouth.enable          = true;
    tmp = {
      useTmpfs    = true;
      cleanOnBoot = true;
    };
    runSize = "75%"; # Size of useTmpfs defaults to 50% of RAM
  };

  i18n.inputMethod.fcitx5 = {
    waylandFrontend = true;
    settings.globalOptions = {
      SwitchKey = "Shift_L+Shift_R";
    };
    quickPhraseFiles = {
      latex = ../../../home-manager/programs/fcitx5/latex.mb;
    };
  };

  # Intel UHD 620 Hardware Acceleration
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
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
    variables.WLR_DRM_NO_MODIFIERS                = "1";
    variables.SDL_IM_MODULE                       = "fcitx5";

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
      xkb = {
        layout  = "us,pt";
        options = "caps:escape, grp:shifts_toggle";
      };

      videoDrivers = [ "intel" ];
    };

    libinput = {
      enable = true;
      touchpad.clickMethod = "clickfinger";
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
            publicKey = "2OIP77a10/Fas+eCvYQNa3ixFNOq0JqZIuSk1tY/QTM=";

            # Forward all the traffic via VPN.
            allowedIPs = [ "0.0.0.0/0" ];
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
