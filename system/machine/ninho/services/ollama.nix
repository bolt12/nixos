{ config, pkgs, ... }:
{
  services = {
    ollama = {
      enable = true;
      acceleration = "cuda";  # RTX 5090
      host = "0.0.0.0";
      port = 11434;
    };

    open-webui = {
      enable = true;
      openFirewall = true;
    };
  };


  # Ensure GPU is ready
  systemd.services.ollama = {
    after = [ "nvidia-persistenced.service" ];
    requires = [ "nvidia-persistenced.service" ];
  };
}
