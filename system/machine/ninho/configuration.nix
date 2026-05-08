{
  config,
  lib,
  pkgs,
  inputs,
  system,
  constants,
  ...
}@attrs:

# ============================================================================
# Ninho Server Configuration
# ============================================================================
# Home server with AMD Ryzen 9 9950X3D, 128GB RAM, RTX 5090
# Multi-user setup (bolt, pollard) with ZFS RAID storage
# ============================================================================

{
  imports = [
    ./hardware-configuration.nix
    ./boot.nix # Kernel, initrd, LUKS auto-unlock, GRUB, watchdog
    ./networking.nix # NetworkManager, DNS, firewall, WireGuard
    ./storage.nix # ZFS, sanoid, storage directory seeds
    ./users.nix # bolt + pollard user declarations
    ./services # All service modules (Caddy, Nextcloud, Immich, Ollama, etc.)
    ./package-overrides.nix # Custom package overrides and patches
    inputs.home-manager.nixosModules.home-manager
  ];

  # ==========================================================================
  # SYSTEM INFO
  # ==========================================================================

  system.stateVersion = "25.05";

  time.timeZone = "Europe/Lisbon";
  i18n.defaultLocale = "en_US.UTF-8";

  # ==========================================================================
  # HARDWARE
  # ==========================================================================

  hardware = {
    # Hardware firmware
    firmware = with pkgs; [
      linux-firmware
    ];

    # Bluetooth
    bluetooth = {
      enable = true;
      settings = {
        General.Enable = lib.concatStringsSep "," [
          "Source"
          "Sink"
          "Media"
          "Socket"
        ];
      };
    };

    # Graphics/GPU
    graphics = {
      enable = true;
      enable32Bit = true; # For Steam and 32-bit applications
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

  systemd.tmpfiles.rules = [
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
    # alerts.json must be valid JSON — a zero-byte file makes the daemon
    # bail out of init before binding the API on 11987 (silent on INFO).
    "C /etc/coolercontrol/alerts.json 0644 root root - ${pkgs.writeText "coolercontrol-alerts-seed.json" ''{"alerts":[]}''}"
  ];

  # ==========================================================================
  # HOME-MANAGER
  # ==========================================================================

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = { inherit inputs system constants; };

    users.bolt =
      { nixpkgs, ... }:
      {
        imports = [ ../../../home-manager/users/bolt/home.nix ];
      };

    users.pollard =
      { nixpkgs, ... }:
      {
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
      trusted-users = [
        "root"
        "bolt"
        "pollard"
      ];
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      extra-platforms = [ "aarch64-linux" ]; # Allow building/evaluating aarch64 derivations (binfmt)

      # Binary caches - CUDA cache significantly reduces compilation times
      substituters = [
        "https://cache.nixos.org"
        "https://cache.nixos-cuda.org" # CUDA packages pre-built
        "https://nix-community.cachix.org"
        "http://127.0.0.1:8090/main" # Local Attic cache
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
    nvtopPackages.nvidia # GPU monitoring
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
      ExecStart =
        let
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
