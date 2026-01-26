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
        title = "Ninho";
        theme = "dark";
        color = "slate";
        headerStyle = "clean";
        iconStyle = "theme";
        statusStyle = "dot";
        hideVersion = false;
        quicklaunch = {
          searchDescriptions = true;
          hideInternetSearch = true;
          hideVisit = true;
        };
      };

      allowedHosts = "localhost:${toString ports.homepage},127.0.0.1:${toString ports.homepage},${ninhoIp},${ninhoIp}:${toString ports.homepage}";

      # Organized bookmarks with icons
      bookmarks = [
        {
          Media = [
            {
              Jellyfin = [
                {
                  href = "http://${ninhoIp}:${toString ports.jellyfin}";
                  icon = "jellyfin";
                }
              ];
              Navidrome = [
                {
                  href = "http://${ninhoIp}:${toString ports.navidrome}";
                  icon = "navidrome";
                }
              ];
              Immich = [
                {
                  href = "http://${ninhoIp}:${toString ports.immich}";
                  icon = "immich";
                }
              ];
            }
          ];
        }
        {
          Downloads = [
            {
              Deluge = [
                {
                  href = "http://${ninhoIp}:${toString ports.deluge}";
                  icon = "deluge";
                }
              ];
              Bitmagnet = [
                {
                  href = "http://${ninhoIp}:${toString ports.bitmagnet}";
                  icon = "magnet";
                }
              ];
            }
          ];
        }
        {
          "Media Automation" = [
            {
              Prowlarr = [
                {
                  href = "http://${ninhoIp}:${toString ports.prowlarr}";
                  icon = "prowlarr";
                }
              ];
              Radarr = [
                {
                  href = "http://${ninhoIp}:${toString ports.radarr}";
                  icon = "radarr";
                }
              ];
              Sonarr = [
                {
                  href = "http://${ninhoIp}:${toString ports.sonarr}";
                  icon = "sonarr";
                }
              ];
            }
          ];
        }
      ];

      # Organized services by category with widgets
      services = [
        {
          Media = [
            {
              Jellyfin = {
                href = "http://${ninhoIp}:${toString ports.jellyfin}";
                description = "Media Server";
                icon = "jellyfin";
                widget = {
                  type = "jellyfin";
                  url = "http://${ninhoIp}:${toString ports.jellyfin}";
                  enableBlocks = true; # Shows continue watching
                  enableNowPlaying = true;
                  key = "bf2ee1145fae42b196768fea4cbe2c38";
                };
              };
            }
            {
              Navidrome = {
                href = "http://${ninhoIp}:${toString ports.navidrome}";
                description = "Music Streaming";
                icon = "navidrome";
              };
            }
            {
              Immich = {
                href = "http://${ninhoIp}:${toString ports.immich}";
                description = "Photo Management";
                icon = "immich";
                widget = {
                  type = "immich";
                  url = "http://${ninhoIp}:${toString ports.immich}";
                  # Create API key in Immich: Account Settings > API Keys
                  # Requires "server.statistics" permission
                  key = "415bvASyoUx0AhP157r3rbRzufa9Y76CXXvCRy88OrE";
                  version = 2;
                  fields = ["photos" "videos" "storage" "users"];
                };
              };
            }
          ];
        }
        {
          "Media Requests" = [
            {
              Jellyseer = {
                href = "http://${ninhoIp}:${toString ports.jellyseerr}";
                description = "Request Movies/TV";
                icon = "jellyseerr";
                widget = {
                  type = "jellyseerr";
                  url = "http://${ninhoIp}:${toString ports.jellyseerr}";
                  enable = true; # Shows pending requests
                  key = "MTc2NDYzMDg5OTM5ODc0ZTM1NGRiLTViYTQtNDYzNS05Njg1LTdlN2M4YTI3Mzg0MA==";
                };
              };
            }
          ];
        }
        {
          Downloads = [
            {
              Deluge = {
                href = "http://${ninhoIp}:${toString ports.deluge}";
                description = "Torrent Client";
                icon = "deluge";
                widget = {
                  type = "deluge";
                  url = "http://${ninhoIp}:${toString ports.deluge}";
                  # Deluge password configured in service
                  password = "deluge";
                };
              };
            }
            {
              Bitmagnet = {
                href = "http://${ninhoIp}:${toString ports.bitmagnet}";
                description = "Torrent Indexer";
                icon = "magnet";
              };
            }
          ];
        }
        {
          "Media Automation" = [
            {
              Prowlarr = {
                href = "http://${ninhoIp}:${toString ports.prowlarr}";
                description = "Indexer Manager";
                icon = "prowlarr";
                widget = {
                  type = "prowlarr";
                  url = "http://${ninhoIp}:${toString ports.prowlarr}";
                  key = "dd35049b7bfa4e5390483a6e3fddb47b"; # From Prowlarr Settings > API Key

                };
              };
            }
            {
              Radarr = {
                href = "http://${ninhoIp}:${toString ports.radarr}";
                description = "Movie Collection";
                icon = "radarr";
                widget = {
                  type = "radarr";
                  url = "http://${ninhoIp}:${toString ports.radarr}";
                  key = "150535e0e27d457f91b8f5c9082c0e78"; # From Radarr Settings > General

                };
              };
            }
            {
              Sonarr = {
                href = "http://${ninhoIp}:${toString ports.sonarr}";
                description = "TV Series";
                icon = "sonarr";
                widget = {
                  type = "sonarr";
                  url = "http://${ninhoIp}:${toString ports.sonarr}";
                  key = "482ae55fc7f94b2386c5b8c883d817c5"; # From Sonarr Settings > General
                };
              };
            }
            {
              Lidarr = {
                href = "http://${ninhoIp}:${toString ports.lidarr}";
                description = "Music Collection";
                icon = "lidarr";
                widget = {
                  type = "lidarr";
                  url = "http://${ninhoIp}:${toString ports.lidarr}";
                  key = "4753f76dd50740dfab278af99c60e5ae"; # From Lidarr Settings > General

                };
              };
            }
            {
              Readarr = {
                href = "http://${ninhoIp}:${toString ports.readarr}";
                description = "Book Collection";
                icon = "readarr";
                widget = {
                  type = "readarr";
                  url = "http://${ninhoIp}:${toString ports.readarr}";
                  key = "f322453d3b4f464dbb585bb4d83a9a9f"; # From Readarr Settings > General

                };
              };
            }
            {
              Bazarr = {
                href = "http://${ninhoIp}:${toString ports.bazarr}";
                description = "Subtitle Manager";
                icon = "bazarr";
                widget = {
                  type = "bazarr";
                  url = "http://${ninhoIp}:${toString ports.bazarr}";
                  key = "cb7f44e91365d0e8b490d0c670cc0b79"; # From Bazarr Settings > General
                };
              };
            }
          ];
        }
        {
          Cloud = [
            {
              Nextcloud = {
                href = "http://${ninhoIp}:${toString ports.nextcloud}";
                description = "Files & Collaboration";
                icon = "nextcloud";
              };
            }
            {
              Syncthing = {
                href = "http://${ninhoIp}:${toString ports.syncthing}";
                description = "P2P File Sync";
                icon = "syncthing";
                widget = {
                  url = "http://${ninhoIp}:${toString ports.syncthing}";
                };
              };
            }
          ];
        }
        {
          Notes = [
            {
              Emanote = {
                href = "http://${ninhoIp}:${toString ports.emanote}";
                description = "Zettelkasten Journal";
                icon = "emanote";
              };
            }
            {
              Memos = {
                href = "http://${ninhoIp}:${toString ports.memos}";
                description = "Quick Notes";
                icon = "memos";
              };
            }
            {
              Miniflux = {
                href = "http://${ninhoIp}:${toString ports.miniflux}";
                description = "RSS Reader";
                icon = "miniflux";
                widget = {
                  type = "miniflux";
                  url = "http://${ninhoIp}:${toString ports.miniflux}";
                  username = "bolt";
                  password = "038788dd442a4d6a57304c9404c6767f9cb2ae8e6f1b2ceb49148d8574c7b7f7";
                };
              };
            }
            {
              Kavita = {
                href = "http://${ninhoIp}:${toString ports.kavita}";
                description = "Ebook & Manga Reader";
                icon = "kavita";
                widget = {
                  type = "kavita";
                  url = "http://${ninhoIp}:${toString ports.kavita}";
                  # apiKey from Kavita Settings
                  key = "4d581159-3a4d-41b0-8d76-6bfa57801ea2";

                };
              };
            }
            {
              "Anki Sync" = {
                href = "#";
                description = "Flashcard Sync Server";
                icon = "anki";
              };
            }
          ];
        }
        {
          Monitoring = [
            {
              "Uptime Kuma" = {
                href = "http://${ninhoIp}:${toString ports.uptime-kuma}";
                description = "Status Page";
                icon = "uptime-kuma";
                widget = {
                  type = "uptimekuma";
                  url = "http://${ninhoIp}:${toString ports.uptime-kuma}";
                  # slug from Uptime Kuma monitor slug
                  slug = "ninho";
                };
              };
            }
            {
              Grafana = {
                href = "http://${ninhoIp}:${toString ports.grafana}";
                description = "Metrics Dashboard";
                icon = "grafana";
                widget = {
                  type = "grafana";
                  url = "http://${ninhoIp}:${toString ports.grafana}";
                  username = "admin";
                  password = "admin";
                };
              };
            }
            {
              CoolerControl = {
                href = "http://${ninhoIp}:${toString ports.coolercontrol}";
                description = "Fan Curves & Cooling";
                icon = "coolero";
              };
            }
            {
              Prometheus = {
                href = "http://${ninhoIp}:${toString ports.prometheus}";
                description = "Metrics Collection";
                icon = "prometheus";
                widget = {
                  type = "prometheus";
                  url = "http://${ninhoIp}:${toString ports.prometheus}";
                };
              };
            }
          ];
        }
        {
          AI = [
            {
              "llama-swap" = {
                href = "http://${ninhoIp}:${toString ports.llamaswap}";
                description = "LLM Inference (RTX 5090)";
                icon = "ollama";
              };
            }
          ];
        }
        {
          Gaming = [
            {
              Sunshine = {
                href = "https://${ninhoIp}:47990";
                description = "Game Streaming";
                icon = "sunshine";
              };
            }
          ];
        }
        {
          Home = [
            {
              "Home Assistant" = {
                href = "http://${ninhoIp}:${toString ports.home-assistant}";
                description = "Home Automation";
                icon = "home-assistant";
              };
            }
            {
              Ntfy = {
                href = "http://${ninhoIp}:${toString ports.ntfy}";
                description = "Push Notifications";
                icon = "ntfy";
              };
            }
          ];
        }
      ];

      widgets = [
        # Logo/Header
        {
          logo = {
            icon = "md-home_automation"; # Material Design icon
            title = "Ninho";
          };
        }
        # Quick Search
        {
          search = {
            provider = "google";
            target = "_blank";
            suggest = true;
            history = true;
            showSearchSuggestions = true;
          };
        }
        # System Resources
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
        # Storage Pool
        {
          resources = {
            label = "Storage";
            disk = storage.root;
            diskUnits = "bytes";
          };
        }
        # Weather (Braga, Portugal)
        {
          openmeteo = {
            label = "Weather";
            latitude = 41.5503;
            longitude = -8.4200;
            units = "metric";
            cache = 5;
          };
        }
        # Date and Time
        {
          datetime = {
            text_size = "xl";
            format = {
              timeStyle = "short";
              dateStyle = "full";
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
