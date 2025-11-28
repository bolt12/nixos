{ config, pkgs, ... }:
{
  # AIO LCD GIF Carousel Service
  # Displays GIFs from a folder on the AIO cooler LCD screen
  # Each GIF rotates every 6 seconds with 180-degree orientation

  # Add udev rules for liquidctl to access USB devices
  services.udev.packages = [ pkgs.liquidctl ];

  systemd.services.aio-lcd-carousel = {
    description = "AIO LCD GIF Carousel";
    after = [ "network.target" "systemd-udev-settle.service" ];
    wants = [ "systemd-udev-settle.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.bash}/bin/bash /etc/scripts/aio-gif-carousel.sh";
      Restart = "always";
      RestartSec = "10s";

      # Run as root to access USB devices
      User = "root";
      Group = "root";

      # Security hardening (relaxed for USB access)
      PrivateTmp = true;

      # Full access to /dev for USB devices
      DevicePolicy = "auto";
    };

    # Ensure liquidctl can access USB devices
    path = with pkgs; [ liquidctl bash coreutils ];
  };
}
