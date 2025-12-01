{ config, pkgs, inputs, ... }:
let
  # Import unstable packages for latest ollama
  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs) system;
    overlays = [];
    config.allowUnfree = true;
  };
in
{
  services = {
    jellyfin = {
      enable = true;
      openFirewall = true;
    };
  };
}


