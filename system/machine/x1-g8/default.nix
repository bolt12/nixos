{ config, pkgs, inputs, ... }:

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

    # Emulate ARM on my system. Useful to deploy NixOS on ARM via Colmena
    binfmt.emulatedSystems = [ "aarch64-linux" ];

    kernelModules       = [ "acpi_call" ];
    extraModulePackages =
      with config.boot.kernelPackages; [ acpi_call ];
    blacklistedKernelModules = [ ];
    plymouth.enable          = true;
    tmp = {
      useTmpfs    = true;
      cleanOnBoot = true;
    };
    runSize = "75%"; # Size of useTmpfs defaults to 50% of RAM
  };

  # Performance optimizations for better system responsiveness and SSD longevity
  boot.kernel.sysctl = {
    # Reduce SSD wear by writing dirty pages less frequently (1.5s vs default 5s)
    # Better for systems with sufficient RAM - improves I/O performance
    "vm.dirty_writeback_centisecs" = 1500;

    # Disable NMI watchdog to save CPU cycles and improve power efficiency
    # Trade-off: slightly less debugging capability if system hard-locks
    "kernel.nmi_watchdog" = 0;
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
      intel-vaapi-driver
      libva-vdpau-driver
      libvdpau-va-gl
      intel-media-driver
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

    # Most variables moved to home-manager modules/wayland.nix for centralization
    # Keeping only system-level Java configuration here
    variables._JAVA_OPTIONS                       =
      "-Dawt.useSystemAAFontSettings=on -Dswing.aatext=true -Dsun.java2d.xrender=true";
    variables._JAVA_AWT_WM_NONREPARENTING         = "1";

    # List packages installed in system profile. To search, run:
    # $ nix search wget
    systemPackages = with pkgs; [
    ];
  };

  programs = {
    sway.enable = true;
    nix-ld.enable = true;
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

    libinput = {
      enable = true;
      touchpad.clickMethod = "clickfinger";
    };

    tlp = {
      enable   = true;
      settings = {
        # Battery charge thresholds to preserve battery longevity
        START_CHARGE_THRESH_BAT0 = 85;        # Start charging when battery drops below 85%
        STOP_CHARGE_THRESH_BAT0  = 90;        # Stop charging at 90% to reduce battery wear

        # CPU scaling governors for optimal performance vs battery life balance
        CPU_SCALING_GOVERNOR_ON_AC  = "performance"; # Max performance when plugged in
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";   # Conserve battery when unplugged

        # Runtime power management - automatically manages device power states
        RUNTIME_PM_ON_AC  = "on";   # Enable power management on AC (small savings)
        RUNTIME_PM_ON_BAT = "auto"; # Aggressive power management on battery

        # Additional power saving tweaks for better battery life
        WIFI_PWR_ON_AC = "off";               # Keep WiFi at full power on AC
        WIFI_PWR_ON_BAT = "on";               # Enable WiFi power saving on battery
        SOUND_POWER_SAVE_ON_AC = 0;           # Disable audio power saving on AC
        SOUND_POWER_SAVE_ON_BAT = 1;          # Enable audio power saving on battery
      };
    };

    blueman.enable = true;

    flatpak.enable = true;

    fwupd.enable = true;
  };

  # Firefox NixOS wiki recommends
  xdg = {
    portal = {
      enable = true;
      configPackages = [
        pkgs.xdg-desktop-portal
        pkgs.xdg-desktop-portal-gtk
        pkgs.xdg-desktop-portal-wlr
      ];
      wlr.enable = true;
    };
  };

  networking = {
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
    pam.services.swaylock = {};

    polkit.enable = true;

    rtkit.enable = true;
  };

}
