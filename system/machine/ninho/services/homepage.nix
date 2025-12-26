{ config, constants, ... }:
let
  inherit (constants) network ports storage;
  ninhoIp = network.ninho.vpnIp;
in
{
  services = {
    homepage-dashboard = {
      enable = true;

      # Listen on all interfaces
      listenPort = ports.homepage;

      settings = {
        title = "Ninho Server";
        theme = "dark";
      };

      allowedHosts = "localhost:${toString ports.homepage},127.0.0.1:${toString ports.homepage},${ninhoIp},${ninhoIp}:${toString ports.homepage}";

      services = [
        {
          Services = [
            {
              Nextcloud = {
                href = "http://${ninhoIp}:${toString ports.nextcloud}";
                description = "Files & Sync";
              };
            }
            {
              Immich = {
                href = "http://${ninhoIp}:${toString ports.immich}";
                description = "Photos";
                widget = {
                  type = "immich";
                  url = "http://${ninhoIp}:${toString ports.immich}";
                  # Create API key in Immich: Account Settings > API Keys
                  # Requires "server.statistics" permission
                  # TODO: Move to secret management (user will handle separately)
                  key = "415bvASyoUx0AhP157r3rbRzufa9Y76CXXvCRy88OrE";
                  version = 2;
                  fields = ["photos" "videos" "storage" "users"];
                };
              };
            }
            {
              Bitmagnet = {
                href = "http://${ninhoIp}:${toString ports.bitmagnet}";
                description = "Self Hosted Torrent Indexer";
              };
            }
            {
              Deluge = {
                href = "http://${ninhoIp}:${toString ports.deluge}";
                description = "Torrent Download Client";
              };
            }
            {
              Jellyfin = {
                href = "http://${ninhoIp}:${toString ports.jellyfin}";
                description = "Jellyfin Media Server";
              };
            }
            {
              Jellyseer = {
                href = "http://${ninhoIp}:${toString ports.jellyseerr}";
                description = "Media request tool for Jellyfin";
              };
            }
            {
              Prowlarr = {
                href = "http://${ninhoIp}:${toString ports.prowlarr}";
                description = "*Arr services indexer";
              };
            }
            {
              Radarr = {
                href = "http://${ninhoIp}:${toString ports.radarr}";
                description = "Usenet/BitTorrent movie downloader";
              };
            }
            {
              Sonarr = {
                href = "http://${ninhoIp}:${toString ports.sonarr}";
                description = "Smart PVR for newsgroup and bittorrent users (TV)";
              };
            }
            {
              Lidarr = {
                href = "http://${ninhoIp}:${toString ports.lidarr}";
                description = "Usenet/BitTorrent music downloader";
              };
            }
            {
              Readarr = {
                href = "http://${ninhoIp}:${toString ports.readarr}";
                description = "Usenet/BitTorrent ebook downloader";
              };
            }
            {
              Grocy = {
                href = "http://${ninhoIp}:8085";
                description = "Groceries";
              };
            }
            {
              Emanote = {
                href = "http://${ninhoIp}:${toString ports.emanote}";
                description = "Journal";
              };
            }
            {
              Syncthing = {
                href = "http://${ninhoIp}:${toString ports.syncthing}";
                description = "P2P Sync";
              };
            }
            {
              Ollama = {
                href = "http://${ninhoIp}:${toString ports.ollama}";
                description = "LLM API";
              };
            }
            {
              Grafana = {
                href = "http://${ninhoIp}:${toString ports.grafana}";
                description = "Monitoring";
              };
            }
            {
              CoolerControl = {
                href = "http://${ninhoIp}:${toString ports.coolercontrol}";
                description = "Monitoring";
              };
            }
            {
              Sunshine = {
                href = "https://${ninhoIp}:47990";
                description = "Game Streaming Server";
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
            disk = storage.root;
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
      virtualHosts."${ninhoIp}" = {
        listen = [
          { addr = ninhoIp; port = 80; }
        ];
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString ports.homepage}";
          proxyWebsockets = true;
        };
      };
    };
  };
}
