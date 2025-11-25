{ config, lib, pkgs, inputs, system, ... }@attrs:

let

  unstable = import inputs.nixpkgs-unstable {
    overlays = [
    ];
    system = system;
  };

in
{
  imports = [
    ./hardware-configuration.nix
    inputs.home-manager.nixosModules.home-manager
  ];

  # ===== BOOT CONFIGURATION =====
  boot = {
    # Support ZFS
    supportedFilesystems = [ "zfs" ];

    # ZFS-specific settings
    zfs = {
      forceImportRoot = false;

      # Recommended: Don't force import all pools at boot
      # Only import pools that are configured in hardware-configuration.nix
      forceImportAll = false;

      # ZFS kernel module parameters (optional tuning)
      # Limit ARC cache to prevent OOM on systems with limited RAM
      # Default is 50% of RAM, adjust based on your needs
      # extraPools = [ "storage" ];  # Auto-import additional pools
    };

    # LUKS devices (decrypt at boot)
    initrd.luks.devices = {
      # OS pool devices
      "luks-rpool-nvme0n1-part2" = {
        device = "/dev/disk/by-uuid/e3b307b9-0ab9-4032-8db0-9674ebd53e00";
        preLVM = true;
      };
      "luks-rpool-nvme1n1-part2" = {
        device = "/dev/disk/by-uuid/c1ac5b9e-734e-413c-b8c7-8054ef32e9aa";
        preLVM = true;
      };

      # Storage pool devices
      "luks-storage-sda-part2" = {
        device = "/dev/disk/by-uuid/23001c3e-c434-4ca3-a289-22942510bfca";
        preLVM = true;
      };
      "luks-storage-sdb-part2" = {
        device = "/dev/disk/by-uuid/7c8fdd14-f2a8-4506-a4c5-8fcad05d7320";
        preLVM = true;
      };
      "luks-storage-sdc-part2" = {
        device = "/dev/disk/by-uuid/4396e7a6-bfba-413a-8370-f892f9129521";
        preLVM = true;
      };
    };

    # GRUB bootloader with mirrored boot support
    loader = {
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };

      grub = {
        enable = true;
        device = "nodev";
        efiSupport = true;
        enableCryptodisk = true;  # Required for LUKS
        zfsSupport = true;

        # Mirror boot to second drive for redundancy
        mirroredBoots = [
          {
            devices = [ "nodev" ];
            path = "/boot-fallback";
            efiSysMountPoint = "/boot-fallback";
          }
        ];
      };
    };

    # Kernel parameters
    kernelParams = [
      # Optional: Limit ZFS ARC cache (useful if you have limited RAM)
      # "zfs.zfs_arc_max=4294967296"  # 4GB in bytes
    ];
  };

  nix = {
    channel.enable = true;
    settings = {
      auto-optimise-store = true;
      trusted-users = [ "root" "bolt" "pollard" ];
      experimental-features = [ "nix-command" "flakes" ];

      # Parallel builds
      max-jobs = "auto";
      cores = 0;

      # Keep build logs small
      keep-going = true;
      log-lines = 25;
    };

    # Daily garbage collection (aggressive)
    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 30d";
      persistent = true;  # Run even if system was off
    };

    # Weekly optimization
    optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };
  };

  # ===== NETWORK CONFIGURATION =====
  networking = {
    # Required: Unique ID for ZFS
    # Generate with: head -c4 /dev/urandom | od -A none -t x4
    hostId = "d8e24c1d";  # e.g., "a1b2c3d4"

    hostName = "nixos-ninho";  # Change as desired
    networkmanager.enable = true;  # Or use systemd-networkd

    nameservers =
    [ "10.100.0.1" # RPI 5 VPN IP
      "1.1.1.1"
      "8.8.8.8"
      "8.8.4.4"
    ];

    # Enable WireGuard
    firewall = {
      enable            = true;
      trustedInterfaces = [ "wg0" ];
      allowedTCPPorts   = [ 20 21 8000 ];
      allowedUDPPorts   = [ 51820 ];
    };

    wireguard.interfaces = {
      # "wg0" is the network interface name. You can name the interface arbitrarily.
      wg0 = {
        # Determines the IP address and subnet of the client's end of the tunnel interface.
        ips = [ "10.100.0.100/24" ];
        listenPort = 51820; # to match firewall allowedUDPPorts (without this wg uses random port numbers)

        # Path to the private key file.
        #
        # Note: The private key can also be included inline via the privateKey option,
        # but this makes the private key world-readable; thus, using privateKeyFile is
        # recommended.
        privateKeyFile = "/home/wireguard-keys/private";

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

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  # Set your time zone.
  time.timeZone = "Europe/Lisbon";

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
    graphics = {
      enable      = true;
      enable32Bit = true;
    };
  };

  # Making fonts accessible to applications.
  fonts = {
    fontDir.enable         = true;
    enableGhostscriptFonts = true;
    enableDefaultPackages  = true;
  };

  # Home Manager Configuration:
  home-manager = {
    useGlobalPkgs   = false;
    useUserPackages = true;

    extraSpecialArgs = {
      inherit inputs system;
    };

    users.bolt = { nixpkgs, ... }: {
      imports = [ ../../../home-manager/users/bolt/home.nix ];
    };

    users.pollard = { nixpkgs, ... }: {
      imports = [ ../../../home-manager/users/pollard/home.nix ];
    };
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # ===== SERVICES =====
  services = {
    # Enable ZFS services
    zfs = {
      autoScrub = {
        enable = true;
        pools = [ "rpool" "storage" ];
        interval = "Sun *-*-* 02:00:00";  # Weekly on Sunday at 2 AM
      };

      # Optional: Automatic snapshots
      # autoSnapshot = {
      #   enable = true;
      #   frequent = 4;  # Keep 4 15-minute snapshots
      #   hourly = 24;   # Keep 24 hourly snapshots
      #   daily = 7;     # Keep 7 daily snapshots
      #   weekly = 4;    # Keep 4 weekly snapshots
      #   monthly = 12;  # Keep 12 monthly snapshots
      # };
    };

    # Optional: Sanoid - more advanced snapshot management
    # Uncomment if you want more control than autoSnapshot provides
   sanoid = {
      enable = true;

      # Snapshot intervals (in minutes for frequent, hours for hourly, etc.)
      interval = "*:00,15,30,45";  # Run every 15 minutes

      # Dataset configurations
      datasets = {
        # Root filesystem - conservative snapshots
        "rpool/root" = {
          useTemplate = [ "system" ];
          recursive = false;
        };

        # Nix store - no snapshots (reproducible)
        "rpool/nix" = {
          autosnap = false;
          autoprune = false;
        };

        # Home directories - frequent snapshots
        "rpool/home" = {
          useTemplate = [ "production" ];
          recursive = true;  # Includes any per-user datasets
        };

        # Storage data - daily snapshots with long retention
        "storage/data" = {
          useTemplate = [ "storage" ];
          recursive = true;
        };
      };

      # Snapshot retention templates
      templates = {
        # For system datasets (root)
        system = {
          frequently = 0;      # No frequent snapshots
          hourly = 24;         # Keep 24 hours
          daily = 7;           # Keep 7 days
          weekly = 4;          # Keep 4 weeks
          monthly = 3;         # Keep 3 months
          yearly = 0;          # No yearly
          autosnap = true;
          autoprune = true;
        };

        # For user data (home)
        production = {
          frequently = 4;      # Keep 4 x 15min = 1 hour
          hourly = 48;         # Keep 48 hours = 2 days
          daily = 14;          # Keep 14 days = 2 weeks
          weekly = 8;          # Keep 8 weeks = 2 months
          monthly = 12;        # Keep 12 months = 1 year
          yearly = 2;          # Keep 2 years
          autosnap = true;
          autoprune = true;
        };

        # For bulk storage
        storage = {
          frequently = 0;      # No frequent snapshots
          hourly = 0;          # No hourly
          daily = 30;          # Keep 30 days = 1 month
          weekly = 8;          # Keep 8 weeks = 2 months
          monthly = 24;        # Keep 24 months = 2 years
          yearly = 5;          # Keep 5 years
          autosnap = true;
          autoprune = true;
        };
      };

      # Extra Sanoid config options
      extraArgs = [ "--verbose" ];
    };

    # Show issue (pre-login banner)
    getty.helpLine = ''
      ╔═══════════════════════════════════════════════════╗
      ║             Welcome to Ninho Server               ║
      ╚═══════════════════════════════════════════════════╝
    '';

    # Enable SSH for remote management
    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        X11Forwarding = true;
        UseDNS = "no";
      };

      # Keep connections alive - important for remote management
      extraConfig = ''
        ClientAliveInterval 60
        ClientAliveCountMax 3
      '';
    };
  };

  environment.etc = {
    "scripts/ninho-logo.ansi" = {
      source = ./scripts/ninho-logo.ansi;
      mode = "0755";
    };
    "scripts/ninho-banner.sh" = {
      source = ./scripts/ninho-banner.sh;
      mode = "0755";
    };
    "scripts/ninho-motd.sh" = {
      source = ./scripts/ninho-motd.sh;
      mode = "0755";
    };
    "scripts/ninho-cheat.sh" = {
      source = ./scripts/ninho-cheat.sh;
      mode = "0755";
    };
    "scripts/ninho-status.sh" = {
      source = ./scripts/ninho-status.sh;
      mode = "0755";
    };
  };

  programs.bash = {
    interactiveShellInit = ''
      # Run MOTD for interactive shells (SSH or login)
      if [[ $- == *i* ]] && [ -z "$TMUX" ]; then
        bash /etc/nixos/ninho-motd.sh | less
      fi
    '';
  };

  # ===== SYSTEM PACKAGES =====
  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    htop
    tmux
    zfs  # ZFS utilities
    tree

    # ZFS management tools
    zfstools

    # Optional: useful for ZFS monitoring
    # zfs-auto-snapshot  # If not using services.zfs.autoSnapshot

    # System monitoring
    iotop
    ncdu  # Disk usage analyzer
  ];

  # ===== USER CONFIGURATION =====
    users.users = {
      bolt = {
        isNormalUser = true;
        description = "Armando";
        extraGroups = [
          "audio"
          "sound"
          "video"
          "wheel"
          "networkmanager"
          "docker"
          "podman"
          "sway"
          "plugdev"
          "root"
        ];

        # IMPORTANT: Change this password after first login!
        initialPassword = "ninho";

        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHKTf4Bb2BBymwZvxPtxEefspOPTACPn3HqrRiWAMJEJ armandoifsantos@gmail.com"
        ];

      };

      pollard = {
        isNormalUser = true;
        description = "Claudia";
        extraGroups = [
          "audio"
          "sound"
          "video"
          "wheel"
          "networkmanager"
          "docker"
          "podman"
          "sway"
          "plugdev"
          "root"
        ];

        # IMPORTANT: Change this password after first login!
        initialPassword = "ninho";

        # Recommended: Add SSH public key for secure access
        # openssh.authorizedKeys.keys = [
        #   "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... pollard@computer"
        # ];
      };
  };

  # ===== SECURITY =====
  security = {
    sudo = {
      enable = true;
      wheelNeedsPassword = true;  # Require password for sudo
    };
  };

  # ===== MISC =====
  # NixOS release
  system.stateVersion = "25.05";
}
