# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, lib, pkgs, inputs, ... }@attrs:

let

  unstable = import inputs.nixpkgs-unstable {
    overlays = [
    ];
    system = config.nixpkgs.system;
  };

in
{
  imports =
    [
      # Include the results of the hardware scan.
      ./machine/x1-g8/hardware-configuration.nix
      # Machine-specific configuration
      ./machine/x1-g8/default.nix
      # Include IOHK related configs
      ./iohk/caches.nix
      ./iohk/ssh.nix

      # Import nixos home manager module
      inputs.home-manager.nixosModules.home-manager
    ];

  networking = {
    hostName = "bolt-nixos";
    # Enables wireless support and openvpn via network manager.
    networkmanager = {
      enable = true;
      dns    = "none";
    };
    nameservers =
    [ "192.168.1.73"
      "1.1.1.1"
      "8.8.8.8"
      "8.8.4.4"
    ];

    # The global useDHCP flag is deprecated, therefore explicitly set to false here.
    # Per-interface useDHCP will be mandatory in the future, so this generated config
    # replicates the default behaviour.
    useDHCP = false;

    # Enable WireGuard
    firewall = {
      enable            = true;
      trustedInterfaces = [ "wg0" ];
      allowedTCPPorts   = [ 20 21 8000 ];
      allowedUDPPorts   = [ 51820 ];
    };

  };

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  # Set your time zone.
  time.timeZone = "Europe/Lisbon";

  location.provider = "geoclue2";

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    cage
    greetd.gtkgreet
    shared-mime-info
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable           = true;
    enableSSHSupport = true;
  };

  # Enable Docker support.
  virtualisation = {
    docker = {
      enable = true;
    };
  };

  hardware = {
    bluetooth = {
      enable         = true;
      hsphfpd.enable = false;
      settings       = {
        General.Enable =
          lib.concatStringsSep "," [ "Source" "Sink" "Media" "Socket" ];
      };
    };
    opengl = {
      enable          = true;
      driSupport32Bit = true;
    };
    enableRedistributableFirmware = true;
    enableAllFirmware             = true;
    cpu.intel.updateMicrocode     = true;
  };

  # Making fonts accessible to applications.
  fonts = {
    fontDir.enable         = true;
    enableGhostscriptFonts = true;
    enableDefaultPackages  = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users = {
    users.bolt = {
      isNormalUser = true;
      home         = "/home/bolt";
      description  = "Armando Santos";
      extraGroups  = [
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
      openssh.authorizedKeys.keys =
        [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOK8UTLb9TxZdIEX5wU4d4qkJhE+i94TnucxtZmdl+ZM bolt@rpi-nixos" ];
    };

  };

  # Home Manager Configuration:
  home-manager = {
    useGlobalPkgs   = false;
    useUserPackages = true;

    extraSpecialArgs = {
      inherit inputs;
    };

    users.bolt = { nixpkgs, ... }: {

      imports = [ ../home-manager/home.nix ];
    };
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Nix daemon config
  nix = {
    # Automate garbage collection
    gc = {
      automatic = true;
      dates     = "monthly";
      options   = "--delete-older-than 7d";
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
  system.stateVersion = "23.11"; # Did you read the comment?
}
