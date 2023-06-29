# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, lib, pkgs, ... }:

{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      # Machine-specific configuration
      ./machine/x1-g8.nix
      # Include IOHK related configs
      ./iohk/caches.nix
      ./iohk/ssh.nix
      # ./iohk/systemd.nix
    ];

  networking = {
    hostName = "bolt-nixos";
    # Enables wireless support and openvpn via network manager.
    networkmanager = {
      enable = true;
      dns = "none";
    };
    nameservers = [ "1.1.1.1" "8.8.8.8" "8.8.4.4" ];

    # The global useDHCP flag is deprecated, therefore explicitly set to false here.
    # Per-interface useDHCP will be mandatory in the future, so this generated config
    # replicates the default behaviour.
    useDHCP = false;
  };

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  #console = {
  #  font = "Lat2-Terminus16";
  #  keyMap = "pt-latin1";
  #};

  # Set your time zone.
  time.timeZone = "Europe/Lisbon";

  location.provider = "geoclue2";

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    cage
    greetd.gtkgreet
  ];

  # Needed for java apps/fonts
  environment.variables._JAVA_OPTIONS="-Dawt.useSystemAAFontSettings=on -Dswing.aatext=true -Dsun.java2d.xrender=true";
  environment.variables._JAVA_AWT_WM_NONREPARENTING="1";
  environment.variables.MOZ_DISABLE_RDD_SANDBOX="1";
  environment.variables.MOZ_ENABLE_WAYLAND="1";
  environment.variables.XDG_CURRENT_DESKTOP="sway";
  environment.variables.XDG_SESSION_TYPE="wayland";
  environment.variables.SDL_VIDEODRIVER="wayland";
  environment.variables.QT_QPA_PLATFORM="wayland";
  environment.variables.QT_WAYLAND_DISABLE_WINDOWDECORATION="1";
  environment.variables.ECORE_EVAS_ENGINE="wayland_egl";
  environment.variables.ELM_ENGINE="wayland_egl";
  environment.variables.EDITOR="nvim";
  environment.variables.VISUAL="nvim";
  environment.variables.NIXOS_OZONE_WL="1";

  environment.etc = {
    "greetd/environments".text = ''
      sway
      bash
    '';
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable           = true;
    enableSSHSupport = true;
  };

  programs.light.enable = true;

  # List services that you want to enable:

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Enable Docker support.
  virtualisation = {
    docker = {
      enable = true;
    };
  };

  hardware = {
    bluetooth = {
      enable = true;
      hsphfpd.enable = true;
      settings = {
        General.Enable = lib.concatStringsSep "," [ "Source" "Sink" "Media" "Socket" ];
      };
    };
    opengl = {
      enable = true;
      driSupport32Bit = true;
    };
    enableRedistributableFirmware = true;
    enableAllFirmware = true;
    cpu.intel.updateMicrocode = true;
  };

  security.pam.services.swaylock.text = ''
    # PAM configuration file for the swaylock screen locker. By default, it includes
    # the 'login' configuration file (see /etc/pam.d/login)
    auth include login
  '';
  security.polkit.enable = true;
  security.rtkit.enable = true;
  # Enable the X11 windowing system.
  services = {
    # Enable the OpenSSH daemon.
    openssh.enable = true;

    # Enable CUPS to print documents.
    printing.enable = true;

    # Firefox NixOs wiki recommends
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = false;
      wireplumber.enable = false;
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
      layout = "us,pt";
      xkbOptions = "caps:escape, grp:shifts_toggle";
      libinput.enable = true;
      libinput.touchpad.clickMethod = "clickfinger";
      videoDrivers = [ "intel" ];
    };
  };

  # Making fonts accessible to applications.
  fonts = {
    fontDir.enable = true;
    enableGhostscriptFonts = true;
    enableDefaultFonts = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users = {
    users.bolt = {
      isNormalUser = true;
      home = "/home/bolt";
      description = "Armando Santos";
      extraGroups = [
        "audio"
        "sound"
        "video"
        "wheel"
        "networkmanager"
        "docker"
        "sway"
        "plugdev"
        "root"
      ];
    openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOK8UTLb9TxZdIEX5wU4d4qkJhE+i94TnucxtZmdl+ZM bolt@rpi-nixos" ];
    };

  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Firefox NixOS wiki recommends
  xdg = {
    portal = {
      enable = true;
      extraPortals = [
        pkgs.xdg-desktop-portal-wlr
        pkgs.xdg-desktop-portal-gtk
        pkgs.xdg-desktop-portal-kde
      ];
    };
  };

  # Nix daemon config
  nix = {
    # Automate garbage collection
    gc = {
      automatic = true;
      dates = "monthly";
      options = "--delete-older-than 7d";
    };

    # Avoid unwanted garbage collection when using nix-direnv
    extraOptions = ''
      keep-outputs     = true
      keep-derivations = true
    '';

    settings = {
      # Automate `nix-store --optimise`
      auto-optimise-store = true;

      # Required by Cachix to be used as non-root user
      trusted-users = [ "root" "bolt" ];
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?
}
