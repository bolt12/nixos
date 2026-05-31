# Unstable nixpkgs overlay — exposes `pkgs.unstable.*`.
#
# Imported by:
#   - system/common/overlays.nix (for NixOS systems via the module system)
#   - flake.nix (for homeConfigurations via the `pkgsFor` builder)
#
# One source of truth for the unstable channel definition.
{ inputs }:
# `_final` is the conventional overlay first-arg name when only `prev` is
# referenced (nixpkgs requires the (final: prev: ...) shape regardless).
_final: prev: {
  unstable = import inputs.nixpkgs-unstable {
    # 26.05 deprecated `pkgs.system`; read the platform from stdenv instead.
    system = prev.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
}
