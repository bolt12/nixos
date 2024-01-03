{
  network = {
    description = "My remote machines";

    storage.legacy = {};

    # Each deployment creates a new profile generation to able to run nixops
    # rollback
    enableRollback = true;
  };

  # Common configuration shared between all servers
  defaults = { config, pkgs, ... }: {
    imports = [
    ];

    # Packages to be installed system-wide.
    environment = {
      systemPackages = with pkgs; [
      ];
    };
  };

  # Server definitions

  rpi = { config, pkgs, ... }: {
    # Says we are going to deploy to an already existing NixOS machine
    deployment.targetHost = "192.168.1.73";

    nix.settings.trusted-users = [ "bolt" ];

    imports = [
      ./rpi.nix
    ];

    deployment.keys.unbound-ads = {
      keyFile = ./unbound-ads/unbound_ad_servers;
    };

    nixpkgs.localSystem = {
      system = "aarch64-linux";
      config = "aarch64-unknown-linux-gnu";
      hostPlatform = "aarch64-linux";
    };

  };
}
