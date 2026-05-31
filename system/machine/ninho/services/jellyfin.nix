# Jellyfin media server with NVENC hardware transcoding (RTX 5090).
{
  constants,
  ...
}:
{
  # 26.05 stable ships the hardwareAcceleration/transcoding options, so the
  # previous stable→unstable module swap is no longer needed.
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

    # 26.05 renamed services.jellyseerr → services.seerr (jellyseerr pkg removed).
    # Data dir stays at /var/lib/jellyseerr/config (move guarded by stateVersion
    # >= 26.05; ours is 25.05). Stable pkgs.seerr is current → no unstable pin.
    seerr = {
      enable = true;
      openFirewall = true;
      port = constants.ports.jellyseerr;
    };
  };
}
