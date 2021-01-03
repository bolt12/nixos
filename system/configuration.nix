# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, lib, pkgs, ... }:

let
  customFonts = pkgs.nerdfonts.override {
    fonts = [
      "JetBrainsMono"
    ];
  };

in
{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      # Machine-specific configuration
      ./machine/thinkpadx200.nix
      # Window manager
      ./wm/sway.nix
    ];

  networking = {
    # Enables wireless support and openvpn via network manager.
    networkmanager = {
      enable = true;
    };

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
  console = {
    font = "Lat2-Terminus16";
    keyMap = "pt-latin1";
  };

  # Set your time zone.
  time.timeZone = "Europe/Lisbon";

  location.provider = "geoclue2";

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
   vim git
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable           = true;
    # enableSSHSupport = true;
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
  };
  hardware = {
      bluetooth = {
        enable = true;
        config = {
          General.Enable = lib.concatStringsSep "," [ "Source" "Sink" "Media" "Socket" ];
        };
      };
      pulseaudio = {
        enable = true;
        package = pkgs.pulseaudioFull;
        extraConfig = "load-module module-switch-on-connect";
      };
      opengl.enable = true;
      enableRedistributableFirmware = true;
      cpu.intel.updateMicrocode = true;
    };

  # Enable the X11 windowing system.
  services = {
    # Enable the OpenSSH daemon.
    # openssh.enable = true;

    # Enable CUPS to print documents.
    printing.enable = true;

    # Enable compton
    compton.enable = true;
  };

  # Making fonts accessible to applications.
  fonts = {
    enableDefaultFonts = true;
    fonts = [
      customFonts
      pkgs.font-awesome-ttf
      pkgs.ubuntu_font_family
    ];
    fontconfig = {
      enable = true;
      defaultFonts = {
        serif = [ "Ubuntu" ];
        sansSerif = [ "Ubuntu" ];
        monospace = [ "JetBrainsMono" ];
      };
    };
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users = {
      users.bolt = {
        isNormalUser = true;
        home = "/home/bolt";
        description = "Armando Santos";
        extraGroups = [ "audio" "wheel" "networkmanager" "docker" ];
      };
    };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

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
  system.stateVersion = "20.09"; # Did you read the comment?

}
