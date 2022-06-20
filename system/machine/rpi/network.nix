{
  network.description = "My remote machines";

  # Each deployment creates a new profile generation to able to run nixops
  # rollback
  network.enableRollback = true;

  # Common configuration shared between all servers
  defaults = { config, pkgs, ... }: {
    imports = [
    ];

    # Packages to be installed system-wide. We need at least cardano-node
    environment = {
      systemPackages = with pkgs; [
      ];
    };
  };

  # Server definitions

  rpi = { config, ... }: {
    # Says we are going to deploy to an already existing NixOS machine
    deployment.targetHost = "192.168.1.73";

    nix.trustedUsers = [ "bolt" ];

    imports = [
      ./rpi.nix
    ];

    nixpkgs.localSystem = {
      system = "aarch64-linux";
      config = "aarch64-unknown-linux-gnu";
    };

  };
}
