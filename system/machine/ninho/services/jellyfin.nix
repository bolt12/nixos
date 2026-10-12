# Jellyfin media server with NVENC hardware transcoding (RTX 5090).
{
  constants,
  pkgs,
  ...
}:
{
  # 26.05 stable ships the hardwareAcceleration/transcoding options, so the
  # previous stable→unstable module swap is no longer needed.
  services = {
    jellyfin = {
      enable = true;
      package = pkgs.unstable.jellyfin;
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
  };

  # The module allowlists only hardwareAcceleration.device. CUDA also opens the
  # control and UVM nodes, and without them cuInit fails and every NVENC
  # transcode exits 187 while remuxes keep working.
  systemd.services.jellyfin.serviceConfig.DeviceAllow = [
    "/dev/nvidiactl rw"
    "/dev/nvidia-uvm rw"
  ];
}
