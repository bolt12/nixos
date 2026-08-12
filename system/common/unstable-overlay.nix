# Unstable nixpkgs overlay: exposes `pkgs.unstable.*`.
#
# Imported by:
#   - system/common/overlays.nix (for NixOS systems via the module system)
#   - flake.nix (for homeConfigurations via the `pkgsFor` builder)
#
# One source of truth for the unstable channel definition.
{ inputs }:
# `_final` is the conventional overlay first-arg name when only `prev` is
# referenced (nixpkgs requires the (final: prev: ...) shape regardless).
_final: prev:
let
  unstable = import inputs.nixpkgs-unstable {
    # 26.05 deprecated `pkgs.system`; read the platform from stdenv instead.
    system = prev.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
in
{
  inherit unstable;

  # Base (26.05) and unstable currently ship the same luajit date-version
  # (2.1.<epoch>), so wrapping the unstable neovim-unwrapped (programs/neovim)
  # with base-pkgs vim plugins drops two different derivations of the same
  # libluajit .so into the wrapper's lua buildEnv, which refuses the conflicting
  # subpath. Pin luajit to the unstable build so the neovim wrapper, whichever
  # package set a plugin comes from, only ever sees one luajit.
  inherit (unstable) luajit;
}
