# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{
  config,
  lib,
  pkgs,
  inputs,
  ...
}@attrs:

{
  # The Pi firmware loads u-boot from the FAT partition, and u-boot reads
  # extlinux.conf from the ext4 root. sd-image-aarch64.nix sets these when
  # building the image, but the colmena node does not import that module, so
  # without them a deploy asserts on boot.loader.grub.devices. mkDefault keeps
  # the image module authoritative where both apply.
  boot.loader = {
    grub.enable = lib.mkDefault false;
    generic-extlinux-compatible.enable = lib.mkDefault true;
  };

  # Serial and HDMI console both, so a stall during boot is visible either way.
  boot.kernelParams = [
    "console=ttyAMA0,115200"
    "console=tty1"
  ];

  networking = {
    hostName = "rpi-nixos";

    # Ethernet only, and deliberately without NetworkManager. NM pulls in
    # wpa_supplicant regardless of any wifi config here: with its default
    # backend it sets networking.wireless.enable itself
    # (nixpkgs networkmanager.nix, the `mkIf (!delegateWireless && !enableIwd)`
    # branch), so the radio stack comes back unless NM goes too. This box sits
    # on a cable next to the router and its address is load-bearing for ninho's
    # clevis unlock, so it has no use for either.
    #
    # DHCP comes from networking.useDHCP in hardware-configuration.nix. That is
    # what the stock sd-image does, and it is how this Pi picked up its lease
    # before any of this config was deployed.
    useDHCP = true;
  };

  # Set your time zone.
  time.timeZone = "Europe/Lisbon";

  users = {
    users = {
      bolt = {
        initialPassword = "tlob";
        isNormalUser = true;
        # No "root" (gid 0): wheel already grants sudo on this Tang keyserver.
        extraGroups = [
          "audio"
          "video"
          "wheel"
          "docker"
          "podman"
        ];

        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHKTf4Bb2BBymwZvxPtxEefspOPTACPn3HqrRiWAMJEJ armandoifsantos@gmail.com"
        ];
      };

      root = {
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHKTf4Bb2BBymwZvxPtxEefspOPTACPn3HqrRiWAMJEJ armandoifsantos@gmail.com"
        ];
      };
    };
  };

  services = {

    # Enable the OpenSSH daemon.
    openssh = {
      enable = true;
      settings = {
        X11Forwarding = true;
        PermitRootLogin = "yes";
      };
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}
