{ inputs, ... }:
{
  # Global overlays applied to all systems
  # Machine-specific package overrides are in system/machine/<name>/package-overrides.nix
  nixpkgs.overlays = [
    # Unstable overlay - makes pkgs.unstable available everywhere
    # This eliminates the need for duplicate unstable imports across modules
    (final: prev: {
      unstable = import inputs.nixpkgs-unstable {
        inherit (prev) system;
        config.allowUnfree = true;
      };
    })
  ];
}
