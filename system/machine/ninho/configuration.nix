{ config, lib, pkgs, inputs, system, constants, ... }@attrs:

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
    # Use 6.18 kernel for native r8126 driver (fixes RTL8126A NETDEV WATCHDOG timeouts)
    # 6.19 breaks NVIDIA 580.x (vm_area_struct.__vm_flags removed)
    kernelPackages = pkgs.linuxPackages_6_18;

    # Supported filesystems
    supportedFilesystems = [ "zfs" ];

    # Override hardware-configuration.nix to add r8169 (needed for initrd networking → Clevis)
    initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "thunderbolt" "usbhid" "usb_storage" "sd_mod" "r8169" ];

    # Kernel modules - Load NVIDIA modules on boot (required for headless)
    # intel_rapl_common: Despite the name, supports AMD Zen via RAPL-compatible MSRs (used by Scaphandre)
    # zstd for decompressing Bluetooth firmware
    # NVIDIA modules loaded here (NOT in initrd) to prevent boot hangs with dummy HDMI
    kernelModules = [ "kvm-amd" "intel_rapl_common" "zstd" "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" "sp5100_tco" ];

    # Emulate aarch64 for building RPi packages via Colmena (like x1-g8)
    binfmt.emulatedSystems = [ "aarch64-linux" ];

    # Kernel parameters
    kernelParams = [
      # NVIDIA configuration
      "nvidia-drm.modeset=1"
      "nvidia-drm.fbdev=1"       # Enable NVIDIA framebuffer device (improves KMS capture, driver 560+)

      # PCI/PCIe power management - Disable ASPM to prevent network/SATA lockups
      "pcie_aspm=off"

      "iommu=pt"          # IOMMU passthrough (avoids swiotlb bounce buffer faults on AHCI)

      # Initrd networking for Clevis/Tang LUKS auto-unlock
      "ip=:::::enp11s0:dhcp"
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

    # Initrd networking for Clevis/Tang auto-unlock
    initrd.network = {
      enable = true;
      flushBeforeStage2 = true;  # Clean slate for NetworkManager in stage 2

      # SSH fallback — if Tang is unreachable, SSH in to type the passphrase
      # Port 2222 (not 22) because the initrd uses a different host key
      # Usage: ssh -p 2222 root@<ninho-lan-ip>
      ssh = {
        enable = true;
        port = 2222;
        authorizedKeys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHKTf4Bb2BBymwZvxPtxEefspOPTACPn3HqrRiWAMJEJ armandoifsantos@gmail.com"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICBqERTS3WbTIgNxGLVMNMNoI5qN277fDAkGeAboztJU claudiacorreiaa7@gmail.com"
        ];
        hostKeys = [ "/etc/secrets/initrd/ssh_host_ed25519_key" ];
      };

      postCommands = ''
        echo 'cryptsetup-askpass' >> /root/.profile
      '';
    };

    # Clevis/Tang auto-unlock for all LUKS devices
    initrd.clevis = {
      enable = true;
      devices = {
        "luks-rpool-nvme0n1-part2".secretFile = "/etc/secrets/initrd/luks-rpool-nvme0n1-part2.jwe";
        "luks-rpool-nvme1n1-part2".secretFile = "/etc/secrets/initrd/luks-rpool-nvme1n1-part2.jwe";
        "luks-storage-sda-part2".secretFile = "/etc/secrets/initrd/luks-storage-sda-part2.jwe";
        "luks-storage-sdb-part2".secretFile = "/etc/secrets/initrd/luks-storage-sdb-part2.jwe";
        "luks-storage-sdc-part2".secretFile = "/etc/secrets/initrd/luks-storage-sdc-part2.jwe";
      };
    };

    # Inject secrets into initrd (avoids world-readable Nix store paths)
    initrd.secrets = {
      "/etc/secrets/initrd/luks-rpool-nvme0n1-part2.jwe" = "/etc/secrets/initrd/luks-rpool-nvme0n1-part2.jwe";
      "/etc/secrets/initrd/luks-rpool-nvme1n1-part2.jwe" = "/etc/secrets/initrd/luks-rpool-nvme1n1-part2.jwe";
      "/etc/secrets/initrd/luks-storage-sda-part2.jwe" = "/etc/secrets/initrd/luks-storage-sda-part2.jwe";
      "/etc/secrets/initrd/luks-storage-sdb-part2.jwe" = "/etc/secrets/initrd/luks-storage-sdb-part2.jwe";
      "/etc/secrets/initrd/luks-storage-sdc-part2.jwe" = "/etc/secrets/initrd/luks-storage-sdc-part2.jwe";
      "/etc/secrets/initrd/ssh_host_ed25519_key" = "/etc/secrets/initrd/ssh_host_ed25519_key";
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
        22     # SSH
        80     # HTTP
        8920   # Jellyfin HTTPS
        22000  # Syncthing file transfers
      ] ++ (with constants.ports; [
        immich grafana emanote llamaswap nextcloud
        homepage jellyfin prowlarr radarr sonarr lidarr readarr
        bitmagnet deluge jellyseerr syncthing coolercontrol
      ]) ++ builtins.attrValues constants.wyoming;
      allowedUDPPorts = [
        51820  # WireGuard
        22000  # Syncthing discovery
        21027  # Syncthing discovery
        1900   # Jellyfin SSDP
        7359   # Jellyfin discovery
      ];
    };

    # WireGuard VPN
    wireguard.interfaces.wg0 = {
      ips = [ "${constants.network.ninho.vpnIp}/24" ];
      listenPort = 51820;
      privateKeyFile = "/etc/wireguard/private";

      peers = [
        {
          publicKey = constants.network.wireguard.rpiServerPubKey;
          allowedIPs = [ "0.0.0.0/0" ];  # Full tunnel
          endpoint = "${constants.network.rpi.lanIp}:${toString constants.network.wireguard.port}";
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
        X11Forwarding = false;
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

    # Udev rules
    udev.extraRules = ''
      # Keep MediaTek MT7922 Bluetooth powered on (fixes EBUSY error)
      ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="0489", ATTRS{idProduct}=="e13a", ATTR{power/control}="on"

      # Disable SATA link power management on HDD controller (PCI 0000:11:00.0, ata7-12)
      # med_power_with_dipm causes CRC/handshake errors on Seagate IronWolf drives
      ACTION=="add", SUBSYSTEM=="scsi_host", KERNELS=="0000:11:00.0", ATTR{link_power_management_policy}="max_performance"
    '';

    # Journald - prevent log exhaustion that can cause disk space issues
    journald = {
      extraConfig = ''
        SystemMaxUse=2G
        SystemMaxFileSize=100M
        MaxFileSec=1week
      '';
    };

    # logind - session management for long-running sessions
    logind.settings.Login = {
      RuntimeDirectorySize = "75%";
      KillUserProcesses = false;
      HandleLidSwitch = "ignore";
      HandleLidSwitchDocked = "ignore";
    };
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
        linger = true;      # Keep user services running after logout
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

        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICBqERTS3WbTIgNxGLVMNMNoI5qN277fDAkGeAboztJU claudiacorreiaa7@gmail.com"
        ];
      };
    };
  };

  systemd.tmpfiles.rules = [
    # Storage directories — SGID so new files inherit storage-users.
    "d ${constants.storage.root}   2775 root storage-users - -"
    "d ${constants.storage.backup} 2775 root storage-users - -"
    "d ${constants.storage.media}  2775 root storage-users - -"
    "d ${constants.storage.data}   2775 root storage-users - -"

    # CoolerControl config seed — programs.coolercontrol exposes only
    # {enable, nvidiaSupport}; the daemon writes device settings back to
    # config.toml, so `C` (create-if-missing) seeds the bind addresses
    # once and leaves daemon-managed state untouched on later boots.
    "d /etc/coolercontrol 0755 root root - -"
    "C /etc/coolercontrol/config.toml 0644 root root - ${pkgs.writeText "coolercontrol-seed.toml" ''
      [settings]
      ipv4_address = "0.0.0.0"
      ipv6_address = "::"
    ''}"
  ];

  # ==========================================================================
  # HOME-MANAGER
  # ==========================================================================

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = { inherit inputs system constants; };

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
      extra-platforms = [ "aarch64-linux" ];  # Allow building/evaluating aarch64 derivations (binfmt)

      # Binary caches - CUDA cache significantly reduces compilation times
      substituters = [
        "https://cache.nixos.org"
        "https://cache.nixos-cuda.org"  # CUDA packages pre-built
        "https://nix-community.cachix.org"
        "http://127.0.0.1:8090/main"  # Local Attic cache
      ];

      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "main:VdiNUDiBDk2MHuiyWAVxrF8npWlaYA8PrnlXmKxjzbM="
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

    # Store optimization — auto-optimise-store (above) handles this on every build
  };

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.cudaSupport = true;

  # ==========================================================================
  # SYSTEM PACKAGES
  # ==========================================================================

  environment.systemPackages = with pkgs; [
    # Safe rebuild wrapper — delegates to install.sh from the user's checkout
    (pkgs.writeShellApplication {
      name = "nixos-rebuild-safe";
      runtimeInputs = [ pkgs.git ];
      text = ''
        cd "$HOME/nixos"
        exec ./install.sh "$@"
      '';
    })

    # Emergency/root tools only — user tools are in home-manager profiles
    vim

    # System administration
    nss
    nssTools
    liquidctl

    # ZFS tools
    zfs
    zfstools

    # NVIDIA tools
    nvtopPackages.nvidia     # GPU monitoring
    cudaPackages.cudatoolkit # CUDA toolkit

    # LLM inference with CUDA acceleration (RTX 5090)
    # Note: Full CUDA+CPU optimizations defined in system/common/overlays.nix
    llama-cpp-cuda

    # Speech recognition with word-level timestamps & diarization (CUDA via cudaSupport)
    whisperx

    # Network diagnostics
    ethtool

    # Clevis — needed for JWE enrollment and key rotation (Tang/LUKS auto-unlock)
    clevis
  ];

  # ==========================================================================
  # FONTS
  # ==========================================================================

  fonts = {
    fontDir.enable = true;
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

  # Cap RTX 5090 power to 450W (the efficiency knee: -22% power, ~0% LLM decode loss)
  # Token generation is GDDR7 bandwidth-bound; -pl only throttles core clocks.
  systemd.services.nvidia-power-limit = {
    description = "Set NVIDIA GPU power limit to 450W";
    wantedBy = [ "multi-user.target" ];
    after = [ "nvidia-persistenced.service" ];
    requires = [ "nvidia-persistenced.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = let
        nvidia-smi = "${config.hardware.nvidia.package.bin}/bin/nvidia-smi";
      in
        "${nvidia-smi} -pl 450";
    };
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
