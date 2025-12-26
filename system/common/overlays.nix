{ inputs, ... }:
{
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
