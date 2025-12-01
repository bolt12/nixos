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

  # Configure Nginx to listen on all interfaces
  services.nginx.virtualHosts."grocy.ninho.local" = {
    # Listen on all interfaces (0.0.0.0) on port 8081
    listen = [
      { addr = "0.0.0.0"; port = 8085; }
      { addr = "[::]"; port = 8085; }  # IPv6 support
    ];
  };

  services.grocy = {
    enable = true;
    hostName = "grocy.ninho.local";
    nginx.enableSSL = false;
    settings = {
      currency = "EUR";
      calendar.firstDayOfWeek = 1;
    };
  };
}

