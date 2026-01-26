{ config, pkgs, constants, ... }:
{
  # ===========================================================================
  # Wyoming Voice Services - Speech-to-Text & Text-to-Speech
  # ===========================================================================
  # Optimized for RTX 5090 32GB + 128GB RAM
  # Uses ~3GB VRAM total (allows coexistence with LLM -hass models)
  #
  # Models chosen for speed/quality balance:
  # - Whisper: turbo model (6x faster than large-v3, ~1-2% accuracy loss)
  # - Piper: medium quality (CPU is faster than GPU for small ONNX models)

  services.wyoming.faster-whisper.servers = {
    # English - turbo model for best speed/accuracy balance
    # turbo: 809M params, 6x faster than large-v3, ~6GB VRAM shared
    "en" = {
      enable = true;
      model = "turbo";
      language = "en";
      device = "cuda";
      uri = "tcp://0.0.0.0:10300";
    };

    # Portuguese - fine-tuned model for better accuracy
    # dwhoelz/whisper-medium-pt-ct2: Portuguese fine-tuned, pre-converted to CTranslate2
    # Based on pierreguillou/whisper-medium-portuguese trained on Common Voice
    "pt" = {
      enable = true;
      model = "dwhoelz/whisper-medium-pt-ct2";
      language = "pt";
      device = "cuda";
      uri = "tcp://0.0.0.0:10301";
    };
  };

  # Piper TTS - CPU inference is faster than GPU for small ONNX models
  # Research shows ~5x speedup on CPU due to memory transfer overhead on GPU
  services.wyoming.piper.servers = {
    en = {
      enable = true;
      voice = "en-us-ryan-medium";
      uri = "tcp://0.0.0.0:10200";
      useCUDA = false;  # CPU is faster for Piper
    };
    pt = {
      enable = true;
      voice = "pt_PT-tugão-medium";
      uri = "tcp://0.0.0.0:10201";
      useCUDA = false;  # CPU is faster for Piper
    };
  };

  # Open firewall for Wyoming protocol (STT and TTS ports)
  networking.firewall.allowedTCPPorts = [ 10200 10201 10202 10300 10301 10302 ];

  # Ensure CUDA drivers are available for all instances
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

  systemd.services."wyoming-faster-whisper-pt" = {
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
