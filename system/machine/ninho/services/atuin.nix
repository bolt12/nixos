{ config, pkgs, constants, ... }:
let
  inherit (constants) ports;
in {
  services.atuin = {
    enable = true;
    port = ports.atuin;
    host = "0.0.0.0";
    openRegistration = true;
    openFirewall = true;
    database.createLocally = true;
    maxHistoryLength = 1000000;
  };
}
