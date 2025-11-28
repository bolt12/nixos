{ config, ... }:
{
  services = {
    homepage-dashboard = {
      enable = true;

      # Listen on all interfaces (default port 8082)
      listenPort = 8082;

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
                href = "http://10.100.0.100:8081";
                description = "Files & Sync";
              };
            }
            {
              OnlyOffice = {
                href = "http://10.100.0.100:8000";
                description = "Documents";
              };
            }
            {
              Immich = {
                href = "http://10.100.0.100:2283";
                description = "Photos";
                widget = {
                  type = "immich";
                  url = "http://10.100.0.100:2283";
                  # Create API key in Immich: Account Settings > API Keys
                  # Requires "server.statistics" permission
                  key = "71rEwGgElTLalNQJ3aQRJsqMYMWoGBJTfJGqBFIDotw";
                  version = 2;
                  fields = ["photos" "videos" "storage" "users"];
                };
              };
            }
            {
              Emanote = {
                href = "http://10.100.0.100:7000";
                description = "Journal";
              };
            }
            {
              Syncthing = {
                href = "http://10.100.0.100:8384";
                description = "P2P Sync";
              };
            }
            {
              Ollama = {
                href = "http://10.100.0.100:8080";
                description = "LLM API";
              };
            }
            {
              Grafana = {
                href = "http://10.100.0.100:3000";
                description = "Monitoring";
              };
            }
            {
              CoolerControl = {
                href = "http://10.100.0.100:11987";
                description = "Monitoring";
              };
            }
          ];
        }
      ];

      widgets = [
        {
          resources = {
            label = "System";
            cpu = true;
            memory = true;
            disk = "/";
            cputemp = true;
            uptime = true;
            units = "metric";
            expanded = true;
            diskUnits = "bytes";
          };
        }
        {
          resources = {
            label = "Storage Pool";
            disk = "/storage";
            diskUnits = "bytes";
          };
        }
        {
          datetime = {
            text_size = "xl";
            format = {
              timeStyle = "short";
              dateStyle = "short";
            };
          };
        }
      ];
    };

    # Nginx reverse proxy for convenient access via IP
    nginx = {
      enable = true;
      virtualHosts."10.100.0.100" = {
        listen = [
          { addr = "10.100.0.100"; port = 80; }
        ];
        locations."/" = {
          proxyPass = "http://127.0.0.1:8082";
          proxyWebsockets = true;
        };
      };
    };
  };
}
