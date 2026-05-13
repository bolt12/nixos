# Home Assistant — slim core + HACS. Config domains live under home-assistant/.
{
  config,
  pkgs,
  lib,
  constants,
  ...
}:
let
  inherit (constants) ports storage network;
  hassHome = "${storage.data}/home-assistant";

  # HACS - Home Assistant Community Store
  hacs = pkgs.buildHomeAssistantComponent rec {
    owner = "hacs";
    domain = "hacs";
    version = "2.0.5";
    src = pkgs.fetchzip {
      url = "https://github.com/hacs/integration/releases/download/${version}/hacs.zip";
      stripRoot = false;
      hash = "sha256-iMomioxH7Iydy+bzJDbZxt6BX31UkCvqhXrxYFQV8Gw=";
    };
    dependencies = with pkgs.home-assistant.python.pkgs; [ aiogithubapi ];
  };
in
{
  # Declarative config domains (template/sensor/rest_command/automation/script/lovelace)
  # live one-per-file under ./home-assistant/ and module-merge into this service.
  imports = [ ./home-assistant ];

  services.home-assistant = {
    enable = true;
    package = pkgs.unstable.home-assistant;
    openFirewall = true;
    configDir = hassHome;

    config = {
      # Required configuration
      default_config = { };

      # HTTP server - use centralized port
      http = {
        server_host = "0.0.0.0";
        server_port = ports.home-assistant;
        trusted_proxies = [
          "127.0.0.1"
          "::1"
          network.wireguard.subnet
        ];
        use_x_forwarded_for = true;
      };

      # HomeKit integration for Apple devices
      homekit = { };

      # Enable the Home Assistant frontend
      frontend = { };

      # Enable configuration UI
      config = { };

      # Enable mobile app support
      mobile_app = { };

      # Excludes target per-minute high-cardinality sensors that have no
      # analytical value: network counters, *arr queue depths, system_monitor
      # gauges, and the phone battery poll.
      recorder = {
        db_url = "sqlite:///${hassHome}/home-assistant_v2.db";
        purge_keep_days = 365;
        commit_interval = 5;
        auto_purge = true;
        auto_repack = true;
        exclude = {
          entity_globs = [
            "sensor.*_packets_*"
            "sensor.*_throughput_*"
            "sensor.*_app_rx_*"
            "sensor.*_app_tx_*"
            "sensor.*_mobile_rx_*"
            "sensor.*_mobile_tx_*"
            "sensor.*_total_rx_*"
            "sensor.*_total_tx_*"
            "sensor.system_monitor_*"
            "sensor.21091116ug_battery_*"
          ];
          entities = [
            "sensor.sonarr_queue"
            "sensor.radarr_queue"
            "sensor.lidarr_wanted"
            "sensor.lidarr_albums"
          ];
        };
      };

      # History and logbook
      history = { };
      logbook = { };

      # Energy monitoring dashboard
      energy = { };

      # Scenes (managed via UI)
      scene = "!include scenes.yaml";
    };

    extraComponents = [
      # ─────────────────────────────────────────────────────────────
      # Core & System
      # ─────────────────────────────────────────────────────────────
      "default_config"
      "hassio" # Home Assistant Supervisor
      "homeassistant_alerts" # HA security alerts
      "isal" # Fast compression

      # ─────────────────────────────────────────────────────────────
      # Communication Protocols
      # ─────────────────────────────────────────────────────────────
      "bluetooth" # Bluetooth
      "bluetooth_adapters" # Bluetooth adapter support
      "mqtt" # MQTT for IoT
      "websocket_api" # WebSocket API
      "rest" # REST API
      "webhook" # Webhooks
      "knx" # KNX home automation bus

      # ─────────────────────────────────────────────────────────────
      # Smart Home Standards
      # ─────────────────────────────────────────────────────────────
      "homekit" # Apple HomeKit bridge
      "homekit_controller" # Control HomeKit devices
      "matter" # Matter protocol
      "thread" # Thread network
      "zha" # Zigbee Home Automation
      "zwave_js" # Z-Wave JS

      # ─────────────────────────────────────────────────────────────
      # Climate & Appliances
      # ─────────────────────────────────────────────────────────────
      "gree" # Gree AC
      "generic_thermostat" # Generic thermostat
      "anova" # Anova Sous Vide
      "meater" # Meater meat thermometer
      "eufy" # Eufy devices

      # ─────────────────────────────────────────────────────────────
      # Media & Entertainment
      # ─────────────────────────────────────────────────────────────
      "cast" # Google Cast
      "dlna_dmr" # DLNA renderer
      "dlna_dms" # DLNA media server
      "jellyfin" # Jellyfin
      "plex" # Plex
      "spotify" # Spotify
      "mpd" # Music Player Daemon
      "webostv" # LG WebOS TV
      "radio_browser" # Internet radio
      "steam_online" # Steam presence

      # ─────────────────────────────────────────────────────────────
      # Media Management (Servarr)
      # ─────────────────────────────────────────────────────────────
      "sonarr" # TV shows
      "radarr" # Movies
      "lidarr" # Music
      "deluge" # Torrent client

      # ─────────────────────────────────────────────────────────────
      # Cloud & Self-Hosted Services
      # ─────────────────────────────────────────────────────────────
      "nextcloud" # Nextcloud
      "immich" # Immich photos
      "syncthing" # Syncthing
      "uptime_kuma" # Uptime monitoring
      "github" # GitHub

      # ─────────────────────────────────────────────────────────────
      # AI & Voice
      # ─────────────────────────────────────────────────────────────
      "anthropic" # Anthropic Claude
      "ollama" # Ollama local LLM
      "whisper" # Whisper speech-to-text
      "wyoming" # Wyoming protocol
      "stt" # Speech-to-text
      "tts" # Text-to-speech
      "google_translate" # Google Translate TTS

      # ─────────────────────────────────────────────────────────────
      # Notifications & Messaging
      # ─────────────────────────────────────────────────────────────
      "notify" # Notification system
      "persistent_notification" # Persistent notifications
      "ntfy" # ntfy.sh
      "discord" # Discord
      "signal_messenger" # Signal
      "facebook" # Facebook Messenger

      # ─────────────────────────────────────────────────────────────
      # Network & Discovery
      # ─────────────────────────────────────────────────────────────
      "upnp" # UPnP
      "ssdp" # SSDP
      "dhcp" # DHCP
      "network" # Network utilities
      "ping" # Ping tracker
      "speedtestdotnet" # Internet speed test
      "no_ip" # No-IP DDNS

      # ─────────────────────────────────────────────────────────────
      # Presence & Location
      # ─────────────────────────────────────────────────────────────
      "person" # Person tracking
      "device_tracker" # Device tracking
      "mobile_app" # HA mobile app
      "waze_travel_time" # Waze travel time

      # ─────────────────────────────────────────────────────────────
      # Weather & Environment
      # ─────────────────────────────────────────────────────────────
      "met" # Met.no weather
      "sun" # Sun position
      "moon" # Moon phase
      "forecast_solar" # Solar forecast

      # ─────────────────────────────────────────────────────────────
      # Energy & Monitoring
      # ─────────────────────────────────────────────────────────────
      "energy" # Energy dashboard
      "systemmonitor" # System monitor
      "prometheus" # Prometheus metrics

      # ─────────────────────────────────────────────────────────────
      # Automation & Scripting
      # ─────────────────────────────────────────────────────────────
      "automation" # Automations
      "scene" # Scenes
      "script" # Scripts
      "schedule" # Scheduling
      "shell_command" # Shell commands
      "command_line" # Command line sensors

      # ─────────────────────────────────────────────────────────────
      # History & Recording
      # ─────────────────────────────────────────────────────────────
      "recorder" # State recorder
      "history" # History
      "logbook" # Logbook

      # ─────────────────────────────────────────────────────────────
      # Data & Logging
      # ─────────────────────────────────────────────────────────────
      "google_sheets" # Google Sheets (OAuth setup required post-deploy)
      "history_stats" # History-based statistics sensors

      # ─────────────────────────────────────────────────────────────
      # Utilities & Other
      # ─────────────────────────────────────────────────────────────
      "calendar" # Calendar
      "google" # google
      "shopping_list" # Shopping list
      "xiaomi" # Xiaomi devices
    ];

    customComponents = [
      hacs # Home Assistant Community Store
    ]
    ++ (with pkgs.unstable.home-assistant-custom-components; [
      prometheus_sensor
      xiaomi_home
      garmin_connect
    ]);

    # Custom Lovelace modules for modern UI dashboard
    customLovelaceModules = with pkgs.home-assistant-custom-lovelace-modules; [
      # Essential card libraries
      bubble-card # Modern nice cards
      mini-graph-card # Compact graphs
      mushroom # Modern card collection (chips, entity, climate, media player)
      button-card # Customizable buttons

      # Specialized cards
      lg-webos-remote-control # LG WebOS TV Remote
      universal-remote-card # Universal remote

      # Advanced functionality
      auto-entities # Dynamic entity filtering for cards
      card-mod # CSS customization for any card
      apexcharts-card # Advanced charting
    ];

    # Extra Python packages for recorder
    extraPackages =
      python3Packages: with python3Packages; [
        psycopg2 # PostgreSQL support (optional)
      ];

    # ─────────────────────────────────────────────────────────────────
    # Declarative Fancy Dashboard (Lovelace YAML Mode)
    # ─────────────────────────────────────────────────────────────────
  };

  # Create config directory with proper structure
  # Note: automations and scripts are now managed declaratively in Nix
  # Only scenes.yaml is needed for UI-managed scenes
  systemd.tmpfiles.rules = [
    "d ${hassHome} 0750 hass hass - -"
    "f ${hassHome}/scenes.yaml 0640 hass hass - -"
  ];
}
