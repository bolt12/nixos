{ config, lib, pkgs, inputs, system, ... }@attrs:

# ============================================================================
# Ninho Server Configuration
# ============================================================================
# Home server with AMD Ryzen 9 9950X3D, 128GB RAM, RTX 5090
# Multi-user setup (bolt, pollard) with ZFS RAID storage
# ============================================================================

{
  imports = [
    ./hardware-configuration.nix
    ./services  # All service modules (Caddy, Nextcloud, Immich, Ollama, etc.)
    ./package-overrides.nix  # Custom package overrides and patches
    inputs.home-manager.nixosModules.home-manager
  ];

  # ==========================================================================
  # SYSTEM INFO
  # ==========================================================================

  system.stateVersion = "25.05";

  time.timeZone = "Europe/Lisbon";
  i18n.defaultLocale = "en_US.UTF-8";

  # ==========================================================================
  # BOOT & KERNEL
  # ==========================================================================

  boot = {
    # Supported filesystems
    supportedFilesystems = [ "zfs" ];

    # Kernel modules - Load NVIDIA modules on boot (required for headless)
    # Also load rapl for energy consumption analysis
    # zstd for decompressing Bluetooth firmware
    # NVIDIA modules loaded here (NOT in initrd) to prevent boot hangs with dummy HDMI
    kernelModules = [ "kvm-amd" "intel_rapl_common" "zstd" "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];

    # Don't load NVIDIA in initrd - causes boot hang when dummy HDMI is connected
    # initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];

    # Kernel parameters
    kernelParams = [
      # ZFS ARC cache: With 128GB RAM, default (50%) = 64GB is fine
      # Uncomment to limit for GPU workloads:
      # "zfs.zfs_arc_max=34359738368"  # 32GB in bytes

      # NVIDIA configuration
      "nvidia-drm.modeset=1"
      "nvidia.NVreg_PreserveVideoMemoryAllocations=1"

      # PCI/PCIe power management - Disable ASPM to prevent network/SATA lockups
      "pcie_aspm=off"

      # Alternative: Allow fallback to BIOS ASPM settings if needed
      # "pcie_aspm.policy=performance"

      # Realtek RTL8126A network driver stability (r8169)
      "r8169.use_dac=1"   # Enable DAC (Dual Address Cycle)
      "r8169.aspm=0"      # Disable ASPM at driver level
      "iommu=soft"        # Software IOMMU (may help with DMA issues)
    ];

    # Bluetooth module configuration - Disable autosuspend for MediaTek adapters
    extraModprobeConfig = ''
      options btusb enable_autosuspend=0
      options btmtk enable_autosuspend=0

      # AMD SATA controller fixes - Disable aggressive power management
      options ahci ignore_sss=1
    '';

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
    # Hardware firmware
    firmware = with pkgs; [
      linux-firmware  # Include latest network driver firmware (RTL8126A)
    ];

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

  # Enable NVIDIA drivers (required for game streaming with Sunshine)
  # Display manager and desktop are configured in services/gaming.nix
  services.xserver = {
    enable = true;
    videoDrivers = [ "nvidia" ];
  };

  # ==========================================================================
  # NETWORKING
  # ==========================================================================

  networking = {
    hostName = "nixos-ninho";
    # Required for ZFS (generated with: head -c4 /dev/urandom | od -A none -t x4)
    hostId = "d8e24c1d";

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
        22    # SSH - Remote access
        20    # FTP
        21    # FTP
        80    # HTTP
        2283  # Immich
        3000  # Grafana
        7000  # Emanote
        8000  # OnlyOffice
        8080  # Llama swap
        8081  # Nextcloud
        8082  # Homepage Dashboard
        8096  # Jellyfin
        8920  # Jellyfin
        8097  # Prowlarr
        8098  # Radarr
        8199  # Sonarr
        8100  # Lidarr
        8101  # Readarr
        3333  # Bitmagnet
        8103  # Deluge
        8200  # Jellyseer
        8384  # Syncthing web UI
        11987 # CoolerControl
        22000 # Syncthing file transfers
        10200 # Whisper
        10201 # Whisper
        10300 # Whisper
        10301 # Whisper
      ];
      allowedUDPPorts = [
        51820 # WireGuard
        22000 # Syncthing discovery
        21027 # Syncthing discovery
        1900  # Jellyfin
        7359  # Jellyfin
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

  # Network performance tuning for game streaming (Sunshine)
  boot.kernel.sysctl = {
    # UDP buffer optimization (Sunshine uses UDP for video streaming)
    "net.core.rmem_max" = 134217728;      # 128MB read buffer
    "net.core.wmem_max" = 134217728;      # 128MB write buffer
    "net.core.rmem_default" = 1048576;    # 1MB default
    "net.core.wmem_default" = 1048576;

    # Reduce bufferbloat for lower latency
    "net.core.netdev_max_backlog" = 5000;

    # TCP optimization for control channel
    "net.ipv4.tcp_fastopen" = 3;
    "net.ipv4.tcp_notsent_lowat" = 16384;

    # TCP buffer tuning
    "net.ipv4.tcp_rmem" = "8192 1048576 134217728";
    "net.ipv4.tcp_wmem" = "8192 1048576 134217728";

    # Emergency kernel recovery - Magic SysRq key
    # Usage: Alt+SysRq+<command> or echo <command> > /proc/sysrq-trigger
    # REISUB sequence for safe emergency reboot: R E I S U B
    "kernel.sysrq" = 1;
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
      # System datasets (root) - Reduced retention to prevent disk space issues
      system = {
        frequently = 0;
        hourly = 6;       # 6 hours (reduced from 24)
        daily = 3;        # 3 days (reduced from 7)
        weekly = 2;       # 2 weeks (reduced from 4)
        monthly = 2;      # 2 months (reduced from 3)
        yearly = 0;
        autosnap = true;
        autoprune = true;
      };

      # User data (home) - Reduced retention to prevent disk space issues
      production = {
        frequently = 0;   # Disabled (reduced from 4)
        hourly = 12;      # 12 hours (reduced from 48)
        daily = 7;        # 1 week (reduced from 14)
        weekly = 4;       # 1 month (reduced from 8)
        monthly = 6;      # 6 months (reduced from 12)
        yearly = 0;       # Disabled (reduced from 2)
        autosnap = true;
        autoprune = true;
      };

      # Bulk storage - Reduced retention to prevent disk space issues
      storage = {
        frequently = 0;
        hourly = 0;
        daily = 14;       # 2 weeks (reduced from 30)
        weekly = 4;       # 1 month (reduced from 8)
        monthly = 6;      # 6 months (reduced from 24)
        yearly = 1;       # 1 year (reduced from 5)
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

    # Udev rules for Bluetooth - Disable USB autosuspend for MediaTek MT7922
    udev.extraRules = ''
      # Keep MediaTek MT7922 Bluetooth powered on (fixes EBUSY error)
      ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="0489", ATTRS{idProduct}=="e13a", ATTR{power/control}="on"
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
          "root"
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
          "root"
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

      # Binary caches - CUDA cache significantly reduces compilation times
      substituters = [
        "https://cache.nixos.org"
        "https://cache.nixos-cuda.org"  # CUDA packages pre-built
        "https://nix-community.cachix.org"
      ];

      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "cache.nixos-cuda.org-1:2Mm/sgz0GJsJ6Gr6j1B0aZfOj4HwfcgWO/PEHNS1/NY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];

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
  nixpkgs.config.cudaSupport = true;

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

    # LLM inference with CUDA acceleration (RTX 5090)
    # Note: Full CUDA+CPU optimizations defined in system/common/overlays.nix
    llama-cpp-cuda
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
    # Runs on port 11987
    coolercontrol.enable = true;

    # Enable nix-ld to run non-Nix packaged executables (AppImages, pre-built binaries)
    # Useful for running upstream binaries that expect standard library paths
    nix-ld.enable = true;
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

    # Allow llama-swap to control Wyoming services for VRAM management
    # Full-power models stop Wyoming to free ~3GB VRAM, restart on exit
    extraRules = [
      {
        users = [ "llama-swap" ];
        commands = [
          { command = "/run/current-system/sw/bin/systemctl stop wyoming-faster-whisper-en"; options = [ "NOPASSWD" ]; }
          { command = "/run/current-system/sw/bin/systemctl stop wyoming-faster-whisper-pt"; options = [ "NOPASSWD" ]; }
          { command = "/run/current-system/sw/bin/systemctl stop wyoming-piper-en"; options = [ "NOPASSWD" ]; }
          { command = "/run/current-system/sw/bin/systemctl stop wyoming-piper-pt"; options = [ "NOPASSWD" ]; }
          { command = "/run/current-system/sw/bin/systemctl start wyoming-faster-whisper-en"; options = [ "NOPASSWD" ]; }
          { command = "/run/current-system/sw/bin/systemctl start wyoming-faster-whisper-pt"; options = [ "NOPASSWD" ]; }
          { command = "/run/current-system/sw/bin/systemctl start wyoming-piper-en"; options = [ "NOPASSWD" ]; }
          { command = "/run/current-system/sw/bin/systemctl start wyoming-piper-pt"; options = [ "NOPASSWD" ]; }
        ];
      }
    ];
  };
}
