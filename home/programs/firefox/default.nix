{ config, pkgs, ... }:
let

  sources = import ../../nix/sources.nix;

  unstable = import sources.nixpkgs-unstable {
    overlays = [
      (import sources.nixpkgs-wayland)
    ];
  };

in
{
programs.firefox = {
  enable = true;
  package = unstable.wrapFirefox unstable.firefox-unwrapped {
    forceWayland = true;
    extraPolicies = {
      ExtensionSettings = {};
    };
  };
};

}
