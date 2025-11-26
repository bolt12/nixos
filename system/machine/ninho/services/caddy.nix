{ config, ... }:
{
  services.caddy = {
    enable = true;

    virtualHosts = {
      # Default landing page - accessible via IP or base hostname
      "10.100.0.100".extraConfig = ''
        reverse_proxy localhost:8082
        tls internal
      '';

      # Also make homepage accessible via specific name
      "homepage.ninho.local".extraConfig = ''
        reverse_proxy localhost:8082
        tls internal
      '';

      "nextcloud.ninho.local".extraConfig = ''
        reverse_proxy localhost:8080
        tls internal
      '';

      "onlyoffice.ninho.local".extraConfig = ''
        reverse_proxy localhost:8000
        tls internal
      '';

      "immich.ninho.local".extraConfig = ''
        reverse_proxy localhost:2283
        tls internal
      '';

      "emanote.ninho.local".extraConfig = ''
        reverse_proxy localhost:7000
        tls internal
      '';

      "ollama.ninho.local".extraConfig = ''
        reverse_proxy localhost:11434
        tls internal
      '';

      "syncthing.ninho.local".extraConfig = ''
        reverse_proxy localhost:8384
        tls internal
      '';

      "grafana.ninho.local".extraConfig = ''
        reverse_proxy localhost:3000
        tls internal
      '';

      "coolercontrol.ninho.local".extraConfig = ''
        reverse_proxy localhost:11987
        tls internal
      '';
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
