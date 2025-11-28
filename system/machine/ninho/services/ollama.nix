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
    ollama = {
      enable = true;
      package = unstable.ollama;
      acceleration = "cuda";  # RTX 5090
      host = "0.0.0.0";
      port = 11434;
    };

    open-webui = {
      enable = true;
      package = unstable.open-webui;
      openFirewall = true;
      host = "0.0.0.0";  # Listen on all interfaces
      port = 8080;
    };
  };


  # Ensure GPU is ready
  systemd.services.ollama = {
    after = [ "nvidia-persistenced.service" ];
    requires = [ "nvidia-persistenced.service" ];
  };
}
