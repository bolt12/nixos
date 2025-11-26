{ config, ... }:
{
  services.homepage-dashboard = {
    enable = true;
    listenPort = 8082;

    settings = {
      title = "Ninho Server";
      theme = "dark";
    };

    services = [
      {
        Services = [
          {
            Nextcloud = {
              href = "https://nextcloud.ninho.local";
              description = "Files & Sync";
            };
          }
          {
            OnlyOffice = {
              href = "https://onlyoffice.ninho.local";
              description = "Documents";
            };
          }
          {
            Immich = {
              href = "https://immich.ninho.local";
              description = "Photos";
            };
          }
          {
            Emanote = {
              href = "https://emanote.ninho.local";
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
              href = "https://ollama.ninho.local";
              description = "LLM API";
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
}
