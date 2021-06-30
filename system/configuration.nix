# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, lib, pkgs, ... }:

let
  customFonts = pkgs.nerdfonts.override {
    fonts = [
      "JetBrainsMono"
      "FiraCode"
    ];
  };

in
{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      # Machine-specific configuration
      ./machine/x1-g8.nix
      # Window manager
      ./wm/sway.nix
    ];

  networking = {
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
    vim
    git
    sof-firmware
  ];

  # Needed for java apps/fonts
  environment.variables._JAVA_OPTIONS = "-Dawt.useSystemAAFontSettings=on -Dswing.aatext=true -Dsun.java2d.xrender=true";
  environment.variables._JAVA_AWT_WM_NONREPARENTING = "1";

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable           = true;
    enableSSHSupport = true;
  };

  # List services that you want to enable:

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = false;

  # Enable Docker support.
  virtualisation = {
    docker = {
      enable = true;
    };
  };

  # Enable sound.
  sound = {
    enable = true;
    mediaKeys.enable = true;
    mediaKeys.volumeStep = "5%";
  };

  hardware = {
      bluetooth = {
        enable = true;
        settings = {
          General.Enable = lib.concatStringsSep "," [ "Source" "Sink" "Media" "Socket" ];
        };
      };
      pulseaudio = {
        enable = true;
        # 32 bit support for steam.
        support32Bit = true;
        package = pkgs.pulseaudioFull;
        extraConfig = ''
          load-module module-switch-on-connect
          '';
      };
      opengl.enable = true;
      enableRedistributableFirmware = true;
      enableAllFirmware = true;
      cpu.intel.updateMicrocode = true;
    };

    nixpkgs.config.pulseaudio = true; # Explicit PulseAudio support in applications

  # Enable the X11 windowing system.
  services = {
    # Enable the OpenSSH daemon.
    openssh.enable = true;

    # Enable CUPS to print documents.
    printing.enable = true;

    # Enable compton
    compton.enable = true;

    # Firefox NixOs wiki recommends
    pipewire = {
      enable = true;
    };

    # USB Automounting
    gvfs.enable = true;
    udisks2.enable = true;
    devmon.enable = true;
  };

  # Making fonts accessible to applications.
  fonts = {
    fontDir.enable = true;
    enableGhostscriptFonts = true;
    enableDefaultFonts = true;
    fonts = [
      customFonts
      pkgs.font-awesome-ttf
      pkgs.ubuntu_font_family
      pkgs.emojione
      pkgs.noto-fonts
      pkgs.noto-fonts-cjk
      pkgs.noto-fonts-extra
      pkgs.hack-font
      pkgs.inconsolata
      pkgs.material-icons
      pkgs.liberation_ttf
      pkgs.dejavu_fonts
      pkgs.terminus_font
      pkgs.siji
      pkgs.unifont
    ];
    fontconfig = {
      enable = true;
      defaultFonts = {
        monospace = [ "JetBrainsMono" "FiraCode" ];
        serif = [ "DejaVu Serif" "Ubuntu" ];
        sansSerif = [ "DejaVu Sans" "Ubuntu" ];
      };
      antialias = true;
    };
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
      };
    };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Firefox NixOS wiki recommends
  xdg = {
    portal = {
      enable = true;
      gtkUsePortal = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-wlr
        xdg-desktop-portal-gtk
      ];
    };
  };

  # Nix daemon config
  nix = {
    # Automate `nix-store --optimise`
    autoOptimiseStore = true;

    # Automate garbage collection
    gc = {
      automatic = true;
      dates     = "weekly";
      options   = "--delete-older-than 7d";
    };

    # Avoid unwanted garbage collection when using nix-direnv
    extraOptions = ''
      keep-outputs     = true
      keep-derivations = true
    '';

    # Required by Cachix to be used as non-root user
    trustedUsers = [ "root" "bolt" ];
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.05"; # Did you read the comment?

}
