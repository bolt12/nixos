# Disk layout for the Hetzner Cloud VM, applied by disko during the
# nixos-anywhere install. THIS WIPES THE TARGET DISK.
#
# This VM boots in LEGACY BIOS mode (pre-flight confirmed: /sys/firmware/efi
# absent, and its GPT carries a BIOS-boot partition). So the layout is GPT + a
# 1M EF02 BIOS-boot partition + ext4 root, with GRUB (see configuration.nix).
# A UEFI/systemd-boot layout would leave this VM unbootable.
#
# Single disk, enumerated as /dev/sda (virtio-scsi,
# /dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_124945215). /dev/sda is unambiguous
# here; swap in the by-id path if this box ever gains a second disk.
_: {
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/sda";
    content = {
      type = "gpt";
      partitions = {
        boot = {
          # BIOS-boot partition: GRUB embeds core.img here on GPT. No filesystem,
          # no mountpoint. Must be first.
          type = "EF02";
          size = "1M";
          priority = 1;
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
