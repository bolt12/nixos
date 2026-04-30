{ inputs, ... }:
{
  # Global overlays applied to all systems.
  # Machine-specific package overrides live in
  # system/machine/<name>/package-overrides.nix.
  nixpkgs.overlays = [
    (import ./unstable-overlay.nix { inherit inputs; })
  ];
}
