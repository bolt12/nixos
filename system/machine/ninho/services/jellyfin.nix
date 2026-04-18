{ config, pkgs, inputs, constants, ... }:
{
  # Swap stable Jellyfin module for unstable (has hardwareAcceleration options)
  disabledModules = [ "${inputs.nixpkgs}/nixos/modules/services/misc/jellyfin.nix" ];
  imports = [
    "${inputs.nixpkgs-unstable}/nixos/modules/services/misc/jellyfin.nix"
  ];

  services = {
    jellyfin = {
      enable = true;
      openFirewall = true;

      # NVENC hardware transcoding (RTX 5090)
      hardwareAcceleration = {
        enable = true;
        type = "nvenc";
        device = "/dev/nvidia0";
      };

      transcoding = {
        enableHardwareEncoding = true;

        hardwareDecodingCodecs = {
          h264 = true;
          hevc = true;
          hevc10bit = true;
          vp9 = true;
          av1 = true;
        };

        hardwareEncodingCodecs = {
          hevc = true;
          av1 = true;
        };

        enableToneMapping = true;
      };
    };

    jellyseerr = {
      enable = true;
      openFirewall = true;
      port = constants.ports.jellyseerr;
      package = pkgs.unstable.jellyseerr;
    };
  };
}
