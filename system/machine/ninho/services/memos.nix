{ config, pkgs, lib, constants, ... }:
let
  inherit (constants) ports storage;
  memosHome = "${storage.data}/memos";
in
{
  services.memos = {
    enable = true;
    package = pkgs.unstable.memos;
    dataDir = memosHome;

    settings = {
      # Server configuration
      MEMOS_PORT = toString ports.memos;
      MEMOS_ADDR = "0.0.0.0";
      MEMOS_MODE = "prod";

      # Storage configuration
      MEMOS_DATA = memosHome;
    };
  };

  # Create data directories
  systemd.tmpfiles.rules = [
    "d ${memosHome} 0750 memos memos - -"
  ];
}
