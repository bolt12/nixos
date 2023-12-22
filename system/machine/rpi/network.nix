{ config, pkgs, inputs, ... }:

let

  unstable = import nixpkgs-unstable {
    overlays = [
    ];
    system = config.nixpkgs.system;
  };

in
{
  network.description = "My remote machines";

  # Each deployment creates a new profile generation to able to run nixops
  # rollback
  network.enableRollback = true;

  # Common configuration shared between all servers
  defaults = { config, ... }: {
    imports = [
    ];

    # Packages to be installed system-wide.
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

    deployment.keys.unbound-ads = {
      keyFile = ./unbound-ads/unbound_ad_servers;
    };

    nixpkgs.localSystem = {
      system = "aarch64-linux";
      config = "aarch64-unknown-linux-gnu";
    };

  };
}
