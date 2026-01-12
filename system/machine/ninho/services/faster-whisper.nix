{ config, pkgs, constants, ... }:
{
  # faster-whisper speech-to-text service
  # Uses Wyoming protocol for network communication
  # Optimized for RTX 5090 32GB with CUDA acceleration

  services.wyoming.faster-whisper.servers = {
    # English model - primary for dictation
    "en" = {
      enable = true;
      model = "large-v3-turbo";
      language = "en";
      device = "cuda";
      uri = "tcp://0.0.0.0:10300";
    };
    "pt" = {
      enable = true;
      model = "large-v3-turbo";
      language = "pt";
      device = "cuda";
      uri = "tcp://0.0.0.0:10301";
    };
  };

  services.wyoming.piper.servers = {
    en = {
      enable = true;
      voice = "en-us-ryan-high";
      uri = "tcp://0.0.0.0:10200";
      useCUDA = true;
    };
    pt = {
      enable = true;
      voice = "pt_PT-tugão-medium";
      uri = "tcp://0.0.0.0:10201";
      useCUDA = true;
    };
  };

  # Open firewall for Wyoming protocol
  networking.firewall.allowedTCPPorts = [ 10300 ];

  # Ensure CUDA drivers are available
  systemd.services."wyoming-faster-whisper-en" = {
    after = [ "nvidia-persistenced.service" ];
    requires = [ "nvidia-persistenced.service" ];

    serviceConfig = {
      PrivateDevices = false;  # Allow GPU access
    };

    environment = {
      CUDA_VISIBLE_DEVICES = "0";  # RTX 5090
    };
  };
}
