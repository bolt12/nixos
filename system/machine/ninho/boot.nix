# Boot, kernel, initrd, LUKS auto-unlock, GRUB, hardware watchdog.
# Pinned kernel 6.18 — 6.19 breaks NVIDIA 580.x (vm_area_struct.__vm_flags removed).
{ pkgs, ... }:
{
  boot = {
    # Pinned to 6.18 — 6.19 breaks NVIDIA 580.x (vm_area_struct.__vm_flags removed)
    kernelPackages = pkgs.linuxPackages_6_18;

    # Supported filesystems
    supportedFilesystems = [ "zfs" ];

    # systemd-based stage 1 (default in 26.05); required by clevisLuksAskpass.
    initrd.systemd.enable = true;

    # Override hardware-configuration.nix to add r8169 (needed for initrd networking → Clevis)
    initrd.availableKernelModules = [
      "nvme"
      "xhci_pci"
      "ahci"
      "thunderbolt"
      "usbhid"
      "usb_storage"
      "sd_mod"
      "r8169"
    ];

    # Kernel modules - Load NVIDIA modules on boot (required for headless)
    # intel_rapl_common: Despite the name, supports AMD Zen via RAPL-compatible MSRs (used by Scaphandre)
    # zstd for decompressing Bluetooth firmware
    # NVIDIA modules loaded here (NOT in initrd) to prevent boot hangs with dummy HDMI
    kernelModules = [
      "kvm-amd"
      "intel_rapl_common"
      "zstd"
      "nvidia"
      "nvidia_modeset"
      "nvidia_uvm"
      "nvidia_drm"
      "sp5100_tco"
    ];

    # Emulate aarch64 for building RPi packages via Colmena (like x1-g8)
    binfmt.emulatedSystems = [ "aarch64-linux" ];

    # Kernel parameters
    kernelParams = [
      # NVIDIA configuration
      "nvidia-drm.modeset=1"
      "nvidia-drm.fbdev=1" # Enable NVIDIA framebuffer device (improves KMS capture, driver 560+)

      # PCI/PCIe power management - Disable ASPM to prevent network/SATA lockups
      "pcie_aspm=off"

      "iommu=pt" # IOMMU passthrough (avoids swiotlb bounce buffer faults on AHCI)
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
      flushBeforeStage2 = true; # Clean slate for NetworkManager in stage 2

      # SSH fallback — if Tang is unreachable, SSH in to type the passphrase.
      # Port 2222 (not 22) because the initrd uses a different host key.
      # Usage: ssh -p 2222 root@<ninho-lan-ip>
      #        then: systemd-tty-ask-password-agent --query
      ssh = {
        enable = true;
        port = 2222;
        authorizedKeys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHKTf4Bb2BBymwZvxPtxEefspOPTACPn3HqrRiWAMJEJ armandoifsantos@gmail.com"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICBqERTS3WbTIgNxGLVMNMNoI5qN277fDAkGeAboztJU claudiacorreiaa7@gmail.com"
        ];
        # Host key is injected into the initrd automatically by this module
        # (boot.initrd.network.ssh adds it to boot.initrd.secrets).
        hostKeys = [ "/etc/secrets/initrd/ssh_host_ed25519_key" ];
      };
    };

    # DHCP on enp11s0 inside the systemd initrd, so Tang is reachable for
    # clevisLuksAskpass (hands off cleanly to stage-2 NetworkManager).
    initrd.systemd.network.networks."10-enp11s0" = {
      matchConfig.Name = "enp11s0";
      networkConfig.DHCP = "yes";
    };

    # Clevis/Tang auto-unlock: answers each device's systemd LUKS prompt from a
    # clevis token bound into the LUKS2 header — no JWE files, no
    # boot.initrd.secrets. Runs in parallel with, and falls back to, the
    # passphrase prompt. Enroll once per device above on the running system:
    #   sudo clevis luks bind -d /dev/disk/by-uuid/<uuid> tang '{"url":"http://192.168.1.110:7654"}'
    initrd.clevisLuksAskpass = {
      enable = true;
      useTang = true;
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

  # Hardware watchdog (sp5100_tco): auto-reboot on hard kernel lockups.
  # Module loaded via boot.kernelModules above.
  systemd.settings.Manager = {
    RuntimeWatchdogSec = "60s";
    RebootWatchdogSec = "10min";
  };
}
