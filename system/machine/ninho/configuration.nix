{ config, lib, pkgs, inputs, system, ... }@attrs:

# ============================================================================
# Ninho Server Configuration
# ============================================================================
# Home server with AMD Ryzen 9 9950X3D, 128GB RAM, RTX 5090
# Multi-user setup (bolt, pollard) with ZFS RAID storage
# ============================================================================

let
  unstable = import inputs.nixpkgs-unstable {
    overlays = [];
    system = system;
  };
in
{
  imports = [
    ./hardware-configuration.nix
    ./services  # All service modules (Caddy, Nextcloud, Immich, Ollama, etc.)
    inputs.home-manager.nixosModules.home-manager
  ];

  # ==========================================================================
  # SYSTEM INFO
  # ==========================================================================

  system.stateVersion = "25.05";

  networking = {
    hostName = "nixos-ninho";
    # Required for ZFS (generated with: head -c4 /dev/urandom | od -A none -t x4)
    hostId = "d8e24c1d";
  };

  time.timeZone = "Europe/Lisbon";
  i18n.defaultLocale = "en_US.UTF-8";

  # ==========================================================================
  # BOOT & KERNEL
  # ==========================================================================

  boot = {
    # Supported filesystems
    supportedFilesystems = [ "zfs" ];

    # Kernel modules - Load NVIDIA modules on boot (required for headless)
    kernelModules = [ "kvm-amd" ];

    # Force load NVIDIA modules early in boot (critical for headless servers)
    initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];

    # Kernel parameters
    kernelParams = [
      # ZFS ARC cache: With 128GB RAM, default (50%) = 64GB is fine
      # Uncomment to limit for GPU workloads:
      # "zfs.zfs_arc_max=34359738368"  # 32GB in bytes

      # NVIDIA configuration
      "nvidia-drm.modeset=1"
      "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
    ];

    # ZFS configuration
    zfs = {
      forceImportRoot = false;
      forceImportAll = false;
      # extraPools = [ "storage" ];  # Auto-import additional pools if needed
    };

    # LUKS encrypted devices
    initrd.luks.devices = {
      # Root pool (NVMe mirror)
      "luks-rpool-nvme0n1-part2" = {
        device = "/dev/disk/by-uuid/e3b307b9-0ab9-4032-8db0-9674ebd53e00";
        preLVM = true;
      };
      "luks-rpool-nvme1n1-part2" = {
        device = "/dev/disk/by-uuid/c1ac5b9e-734e-413c-b8c7-8054ef32e9aa";
        preLVM = true;
      };

      # Storage pool (HDD RAIDZ1)
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
        enableCryptodisk = true;
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
  };

  # ==========================================================================
  # HARDWARE
  # ==========================================================================

  hardware = {
    # Bluetooth
    bluetooth = {
      enable = true;
      hsphfpd.enable = false;
      settings = {
        General.Enable = lib.concatStringsSep "," [ "Source" "Sink" "Media" "Socket" ];
      };
    };

    # Graphics/GPU
    graphics = {
      enable = true;
      enable32Bit = true;  # For Steam and 32-bit applications
    };

    # NVIDIA RTX 5090 Configuration
    nvidia = {
      # Use latest driver for RTX 5090 (Blackwell architecture requires 565+)
      package = config.boot.kernelPackages.nvidiaPackages.latest;

      # Enable modesetting (required for Wayland)
      modesetting.enable = true;

      # Power management
      powerManagement = {
        enable = true;
        # finegrained = true;  # Experimental - uncomment for better Blackwell power control
      };

      # Use open-source kernel module (better for RTX 40/50 series)
      open = true;

      # Persistence daemon (required for headless)
      nvidiaPersistenced = true;
    };
  };

  # Enable NVIDIA drivers for headless server (no X11/Wayland)
  # This ensures the kernel modules are loaded and available
  services.xserver = {
    enable = true;  # Required for videoDrivers to work
    videoDrivers = [ "nvidia" ];

    # Headless configuration - no display manager
    displayManager.startx.enable = false;
    desktopManager.gnome.enable = false;
  };

  # ==========================================================================
  # NETWORKING
  # ==========================================================================

  networking = {
    networkmanager = {
      enable = true;
      dns = "none";
    };

    # DNS servers
    nameservers = [
      "10.100.0.1"  # RPI 5 VPN gateway
      "1.1.1.1"
      "8.8.8.8"
      "8.8.4.4"
    ];

    # Firewall
    firewall = {
      enable = true;
      trustedInterfaces = [ "wg0" ];
      allowedTCPPorts = [
        20    # FTP
        21    # FTP
        80    # HTTP
        2283  # Immich
        3000  # Grafana
        7000  # Emanote
        8000  # OnlyOffice
        8080  # Open-WebUI
        8081  # Nextcloud
        8082  # Homepage Dashboard
        8384  # Syncthing web UI
        11434 # Ollama
        11987 # CoolerControl
        22000 # Syncthing file transfers
      ];
      allowedUDPPorts = [
        51820 # WireGuard
        22000 # Syncthing discovery
        21027 # Syncthing discovery
      ];
    };

    # WireGuard VPN
    wireguard.interfaces.wg0 = {
      ips = [ "10.100.0.100/24" ];
      listenPort = 51820;
      privateKeyFile = "/home/wireguard-keys/private";

      peers = [
        {
          publicKey = "2OIP77a10/Fas+eCvYQNa3ixFNOq0JqZIuSk1tY/QTM=";
          allowedIPs = [ "0.0.0.0/0" ];  # Full tunnel
          endpoint = "rpi-nixos.ddns.net:51820";
          persistentKeepalive = 25;
        }
      ];
    };
  };

  # ==========================================================================
  # STORAGE & ZFS
  # ==========================================================================

  services.zfs = {
    # Auto-scrub pools weekly
    autoScrub = {
      enable = true;
      pools = [ "rpool" "storage" ];
      interval = "Sun *-*-* 02:00:00";  # Sunday 2 AM
    };
  };

  # Advanced snapshot management with Sanoid
  services.sanoid = {
    enable = true;
    interval = "*:00,15,30,45";  # Every 15 minutes

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
        recursive = true;
      };

      # Storage data - daily snapshots with long retention
      "storage/data" = {
        useTemplate = [ "storage" ];
        recursive = true;
      };
    };

    templates = {
      # System datasets (root)
      system = {
        frequently = 0;
        hourly = 24;      # 24 hours
        daily = 7;        # 7 days
        weekly = 4;       # 4 weeks
        monthly = 3;      # 3 months
        yearly = 0;
        autosnap = true;
        autoprune = true;
      };

      # User data (home)
      production = {
        frequently = 4;   # 4 x 15min = 1 hour
        hourly = 48;      # 2 days
        daily = 14;       # 2 weeks
        weekly = 8;       # 2 months
        monthly = 12;     # 1 year
        yearly = 2;       # 2 years
        autosnap = true;
        autoprune = true;
      };

      # Bulk storage
      storage = {
        frequently = 0;
        hourly = 0;
        daily = 30;       # 1 month
        weekly = 8;       # 2 months
        monthly = 24;     # 2 years
        yearly = 5;       # 5 years
        autosnap = true;
        autoprune = true;
      };
    };

    extraArgs = [ "--verbose" ];
  };

  # ==========================================================================
  # SERVICES
  # ==========================================================================

  services = {
    # SSH server
    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        X11Forwarding = true;
      };
      extraConfig = ''
        ClientAliveInterval 60
        ClientAliveCountMax 3
      '';
    };

    # Getty (login banner)
    getty.helpLine = ''
      ╔═══════════════════════════════════════════════════╗
      ║             Welcome to Ninho Server               ║
      ╚═══════════════════════════════════════════════════╝
    '';
  };

  # ==========================================================================
  # VIRTUALIZATION
  # ==========================================================================

  virtualisation.docker.enable = true;

  # ==========================================================================
  # USERS
  # ==========================================================================

  users = {
    groups = {
      storage-users = {};
    };

    users = {
      bolt = {
        isNormalUser = true;
        description = "Armando";
        extraGroups = [
          "wheel"           # sudo access
          "networkmanager"
          "docker"
          "audio"
          "video"
          "sway"
          "plugdev"
          "storage-users"
          "media"
        ];
        initialPassword = "ninho";  # CHANGE AFTER FIRST LOGIN
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHKTf4Bb2BBymwZvxPtxEefspOPTACPn3HqrRiWAMJEJ armandoifsantos@gmail.com"
        ];
      };

      pollard = {
        isNormalUser = true;
        description = "Claudia";
        extraGroups = [
          "wheel"           # sudo access
          "networkmanager"
          "docker"
          "audio"
          "video"
          "sway"
          "plugdev"
          "storage-users"
          "media"
        ];
        initialPassword = "ninho";  # CHANGE AFTER FIRST LOGIN

        # openssh.authorizedKeys.keys = [
        #   "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... pollard@computer"
        # ];
      };
    };
  };

  # This creates the dir if missing, sets ownership, and sets the SGID bit.
  systemd.tmpfiles.rules = [
    "d /storage 2775 root storage-users - -"
    "d /storage/backup 2775 root storage-users - -"
    "d /storage/media 2775 root storage-users - -"
    "d /storage/data 2775 root storage-users - -"
  ];

  # ==========================================================================
  # HOME-MANAGER
  # ==========================================================================

  home-manager = {
    useGlobalPkgs = false;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs system; };

    users.bolt = { nixpkgs, ... }: {
      imports = [ ../../../home-manager/users/bolt/home.nix ];
    };

    users.pollard = { nixpkgs, ... }: {
      imports = [ ../../../home-manager/users/pollard/home.nix ];
    };
  };

  # ==========================================================================
  # NIX CONFIGURATION
  # ==========================================================================

  nix = {
    channel.enable = true;

    settings = {
      auto-optimise-store = true;
      trusted-users = [ "root" "bolt" "pollard" ];
      experimental-features = [ "nix-command" "flakes" ];

      # Parallel builds
      max-jobs = "auto";
      cores = 0;

      # Build log settings
      keep-going = true;
      log-lines = 25;
    };

    # Garbage collection
    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 30d";
      persistent = true;
    };

    # Store optimization
    optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };
  };

  nixpkgs.config.allowUnfree = true;

  # ==========================================================================
  # SYSTEM PACKAGES
  # ==========================================================================

  environment.systemPackages = with pkgs; [
    # Essential utilities
    vim
    wget
    git
    htop
    tmux
    tree
    nss
    nssTools
    liquidctl

    # ZFS tools
    zfs
    zfstools

    # System monitoring
    iotop
    ncdu

    # NVIDIA tools
    nvtopPackages.nvidia     # GPU monitoring
    cudaPackages.cudatoolkit # CUDA toolkit
  ];

  # ==========================================================================
  # FONTS
  # ==========================================================================

  fonts = {
    fontDir.enable = true;
    enableGhostscriptFonts = true;
    enableDefaultPackages = true;
  };

  # ==========================================================================
  # SHELL CONFIGURATION
  # ==========================================================================

  programs = {
    bash.interactiveShellInit = ''
      # Run MOTD for interactive shells (SSH or login)
      if [[ $- == *i* ]] && [ -z "$TMUX" ]; then
        bash /etc/nixos/ninho-motd.sh | less
      fi
    '';

    # Runs on port 11987
    coolercontrol.enable = true;
  };

  # Configure CoolerControl to listen on all interfaces
  # CoolerControl uses a config file, not environment variables
  systemd.services.coolercontrold = {
    preStart = ''
      # Create config directory if it doesn't exist
      mkdir -p /etc/coolercontrol

      # Add API binding configuration if not present
      if [ -f /etc/coolercontrol/config.toml ]; then
        # Check if ipv4_address is already configured
        if ! grep -q "^ipv4_address" /etc/coolercontrol/config.toml; then
          # Add network settings to the [settings] section
          sed -i '/^\[settings\]/a ipv4_address = "0.0.0.0"\nipv6_address = "::"' /etc/coolercontrol/config.toml
        fi
      fi
    '';
  };

  # Install MOTD scripts
  environment = {
    etc = {
      "scripts/ninho-logo.ansi".source = ./scripts/ninho-logo.ansi;
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
  };

  # ==========================================================================
  # SECURITY
  # ==========================================================================

  security.sudo = {
    enable = true;
    wheelNeedsPassword = true;
  };
}
