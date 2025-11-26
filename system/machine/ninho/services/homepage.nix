{ config, ... }:
{
  services = {
    homepage-dashboard = {
      enable = true;

      settings = {
        title = "Ninho Server";
        theme = "dark";
      };

      allowedHosts = "localhost:8082,127.0.0.1:8082,10.100.0.100,10.100.0.100:8082";

      services = [
        {
          Services = [
            {
              Nextcloud = {
                href = "10.100.0.100:8081";
                description = "Files & Sync";
              };
            }
            {
              OnlyOffice = {
                href = "10.100.0.100:8000";
                description = "Documents";
              };
            }
            {
              Immich = {
                href = "10.100.0.100:2283";
                description = "Photos";
              };
            }
            {
              Emanote = {
                href = "10.100.0.100:7000";
                description = "Journal";
              };
            }
            {
              Syncthing = {
                href = "https://syncthing.ninho.local";
                description = "P2P Sync";
              };
            }
            {
              Ollama = {
                href = "10.100.0.100:8080";
                description = "LLM API";
              };
            }
            {
              Grafana = {
                href = "10.100.0.100:3000";
                description = "Monitoring";
              };
            }
            {
              CoolerControl = {
                href = "10.100.0.100:11987";
                description = "Monitoring";
              };
            }
          ];
        }
      ];

      widgets = [
        {
          resources = {
            cpu = true;
            memory = true;
            disk = "/";
          };
        }
      ];
    };

    nginx = {
      enable = true;
      virtualHosts."10.100.0.100" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:8082";
        };
      };
    };
  };

}
