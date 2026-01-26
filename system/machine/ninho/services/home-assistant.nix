{ config, pkgs, lib, constants, ... }:
let
  inherit (constants) ports storage;
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
  services.home-assistant = {
    enable = true;
    package = pkgs.unstable.home-assistant;
    openFirewall = true;
    configDir = hassHome;

    config = {
      # Required configuration
      default_config = {};

      # HTTP server - use centralized port
      http = {
        server_host = "0.0.0.0";
        server_port = ports.home-assistant;
        trusted_proxies = [ "127.0.0.1" "::1" "10.100.0.0/24" ];
        use_x_forwarded_for = true;
      };

      # HomeKit integration for Apple devices
      homekit = {};

      # Enable the Home Assistant frontend
      frontend = {};

      # Enable configuration UI
      config = {};

      # Enable mobile app support
      mobile_app = {};

      # Recorder for history (optimized for 128GB RAM)
      recorder = {
        db_url = "sqlite:///${hassHome}/home-assistant_v2.db";
        purge_keep_days = 30;
        commit_interval = 1;
      };

      # History and logbook
      history = {};
      logbook = {};

      # ─────────────────────────────────────────────────────────────────
      # System Monitor Integration (configured via extraComponents)
      # Note: System Monitor is auto-discovered in modern HA versions.
      # Sensors are created automatically when the integration is added.
      # ─────────────────────────────────────────────────────────────────

      # ─────────────────────────────────────────────────────────────────
      # Template Sensors for Dashboard
      # Note: These depend on System Monitor integration being configured
      # via the UI after first boot. Entity names may vary.
      # ─────────────────────────────────────────────────────────────────
      template = [
        {
          sensor = [
            {
              name = "Active AC Units";
              unique_id = "active_ac_units";
              state = "{{ [states('climate.ac_sala'), states('climate.ac_escritorio'), states('climate.ac_quarto'), states('climate.ac_quarto_hospedes')] | reject('in', ['off', 'unavailable', 'unknown']) | list | count }}";
              icon = "mdi:air-conditioner";
            }
            {
              name = "Time of Day";
              unique_id = "time_of_day";
              state = "{% set hour = now().hour %}{% if hour < 6 %}Night{% elif hour < 12 %}Morning{% elif hour < 18 %}Afternoon{% elif hour < 22 %}Evening{% else %}Night{% endif %}";
              icon = "mdi:clock-outline";
            }
          ];
        }
      ];

      # Energy monitoring dashboard
      energy = {};

      # Scenes (managed via UI)
      scene = "!include scenes.yaml";

      # ─────────────────────────────────────────────────────────────────
      # Climate Automations
      # ─────────────────────────────────────────────────────────────────
      automation = [
        # 1. Morning Office Pre-Heat
        {
          id = "office_preheat_morning";
          alias = "Office Pre-Heat Morning";
          description = "Start heating office at 8:30 AM so it's warm by 9 AM";
          trigger = [{
            platform = "time";
            at = "08:30:00";
          }];
          condition = [
            {
              condition = "state";
              entity_id = "person.armando";
              state = "home";
            }
            {
              condition = "time";
              weekday = ["mon" "tue" "wed" "thu" "fri" "sat" "sun"];
            }
            {
              condition = "numeric_state";
              entity_id = "climate.ac_escritorio";
              attribute = "current_temperature";
              below = 24;
            }
          ];
          action = [
            {
              action = "climate.set_hvac_mode";
              target.entity_id = "climate.ac_escritorio";
              data.hvac_mode = "heat";
            }
            { delay.seconds = 2; }
            {
              action = "climate.set_temperature";
              target.entity_id = "climate.ac_escritorio";
              data.temperature = 24;
            }
          ];
        }

        # 2. Evening Transition - Office to Living Room
        {
          id = "evening_transition_office_to_sala";
          alias = "Evening Transition - Office to Sala";
          description = "Turn off office AC and turn on living room AC at 6 PM";
          trigger = [{
            platform = "time";
            at = "18:00:00";
          }];
          condition = [{
            condition = "state";
            entity_id = "person.armando";
            state = "home";
          }];
          action = [
            {
              action = "climate.turn_off";
              target.entity_id = "climate.ac_escritorio";
            }
            {
              action = "climate.set_hvac_mode";
              target.entity_id = "climate.ac_sala";
              data.hvac_mode = "heat";
            }
            { delay.seconds = 2; }
            {
              action = "climate.set_temperature";
              target.entity_id = "climate.ac_sala";
              data.temperature = 24;
            }
          ];
        }

        # 3. Night Shutdown - All AC Off
        {
          id = "night_shutdown_all_ac";
          alias = "Night Shutdown All AC";
          description = "Turn off all AC at 11 PM for sleeping";
          trigger = [{
            platform = "time";
            at = "23:00:00";
          }];
          action = [{
            action = "climate.turn_off";
            target.entity_id = [
              "climate.ac_sala"
              "climate.ac_escritorio"
              "climate.ac_quarto"
              "climate.ac_quarto_hospedes"
            ];
          }];
        }

        # 4. Away Mode - Turn Off All
        {
          id = "away_mode_ac_off";
          alias = "Away Mode - All AC Off";
          description = "Turn off all AC when leaving home for more than 10 minutes";
          trigger = [{
            platform = "state";
            entity_id = "person.armando";
            from = "home";
            to = "not_home";
            "for".minutes = 10;
          }];
          action = [
            {
              action = "climate.turn_off";
              target.entity_id = [
                "climate.ac_sala"
                "climate.ac_escritorio"
                "climate.ac_quarto"
                "climate.ac_quarto_hospedes"
              ];
            }
            {
              action = "notify.ntfy";
              data = {
                message = "You left home - all AC units turned off";
                title = "Away Mode Activated";
              };
            }
          ];
        }

        # 5. Return Home - Smart Pre-Heat
        {
          id = "return_home_smart_preheat";
          alias = "Return Home - Smart Pre-Heat";
          description = "Turn on appropriate AC when arriving home based on time of day";
          trigger = [{
            platform = "state";
            entity_id = "person.armando";
            from = "not_home";
            to = "home";
          }];
          condition = [{
            condition = "time";
            after = "08:00:00";
            before = "23:00:00";
          }];
          action = [{
            choose = [
              # Work hours (8AM-6PM): Office
              {
                conditions = [{
                  condition = "time";
                  after = "08:00:00";
                  before = "18:00:00";
                }];
                sequence = [
                  {
                    action = "climate.set_hvac_mode";
                    target.entity_id = "climate.ac_escritorio";
                    data.hvac_mode = "heat";
                  }
                  { delay.seconds = 2; }
                  {
                    action = "climate.set_temperature";
                    target.entity_id = "climate.ac_escritorio";
                    data.temperature = 24;
                  }
                ];
              }
              # Evening (6PM-11PM): Living room
              {
                conditions = [{
                  condition = "time";
                  after = "18:00:00";
                  before = "23:00:00";
                }];
                sequence = [
                  {
                    action = "climate.set_hvac_mode";
                    target.entity_id = "climate.ac_sala";
                    data.hvac_mode = "heat";
                  }
                  { delay.seconds = 2; }
                  {
                    action = "climate.set_temperature";
                    target.entity_id = "climate.ac_sala";
                    data.temperature = 24;
                  }
                ];
              }
            ];
          }];
        }

        # 6a. Office Temperature Reached - Eco Mode
        {
          id = "office_temp_reached_eco";
          alias = "Office Temperature Reached - Eco Mode";
          description = "Switch to fan-only when office reaches target temperature";
          trigger = [{
            platform = "numeric_state";
            entity_id = "climate.ac_escritorio";
            attribute = "current_temperature";
            above = 24;
          }];
          condition = [{
            condition = "state";
            entity_id = "climate.ac_escritorio";
            state = "heat";
          }];
          action = [
            {
              action = "climate.set_hvac_mode";
              target.entity_id = "climate.ac_escritorio";
              data.hvac_mode = "fan_only";
            }
            {
              action = "notify.ntfy";
              data.message = "Office at 24°C - switched to fan mode";
            }
          ];
        }

        # 6b. Office Temperature Dropped - Reheat
        {
          id = "office_temp_dropped_reheat";
          alias = "Office Temperature Dropped - Reheat";
          description = "Resume heating when office drops below target";
          trigger = [{
            platform = "numeric_state";
            entity_id = "climate.ac_escritorio";
            attribute = "current_temperature";
            below = 22;
          }];
          condition = [
            {
              condition = "time";
              after = "08:30:00";
              before = "18:00:00";
            }
            {
              condition = "state";
              entity_id = "person.armando";
              state = "home";
            }
          ];
          action = [
            {
              action = "climate.set_hvac_mode";
              target.entity_id = "climate.ac_escritorio";
              data.hvac_mode = "heat";
            }
            { delay.seconds = 2; }
            {
              action = "climate.set_temperature";
              target.entity_id = "climate.ac_escritorio";
              data.temperature = 24;
            }
          ];
        }

        # 7. Seasonal Mode - Heat/Cool Auto Switch
        {
          id = "seasonal_mode_switch";
          alias = "Seasonal Mode - Heat/Cool Auto Switch";
          description = "Use cooling when outside is warm, heating when cold";
          trigger = [{
            platform = "state";
            entity_id = [
              "climate.ac_escritorio"
              "climate.ac_sala"
            ];
            attribute = "hvac_mode";
          }];
          condition = [{
            condition = "template";
            value_template = "{{ trigger.to_state.state not in ['off', 'unavailable'] }}";
          }];
          action = [{
            choose = [
              # Warm outside (>22°C) - use cooling
              {
                conditions = [
                  {
                    condition = "numeric_state";
                    entity_id = "weather.forecast_home";
                    attribute = "temperature";
                    above = 22;
                  }
                  {
                    condition = "template";
                    value_template = "{{ trigger.to_state.attributes.hvac_mode == 'heat' }}";
                  }
                ];
                sequence = [{
                  action = "climate.set_hvac_mode";
                  target.entity_id = "{{ trigger.entity_id }}";
                  data.hvac_mode = "cool";
                }];
              }
              # Cold outside (<18°C) - use heating
              {
                conditions = [
                  {
                    condition = "numeric_state";
                    entity_id = "weather.forecast_home";
                    attribute = "temperature";
                    below = 18;
                  }
                  {
                    condition = "template";
                    value_template = "{{ trigger.to_state.attributes.hvac_mode == 'cool' }}";
                  }
                ];
                sequence = [{
                  action = "climate.set_hvac_mode";
                  target.entity_id = "{{ trigger.entity_id }}";
                  data.hvac_mode = "heat";
                }];
              }
            ];
          }];
        }

        # 8. Low Temperature Alert
        {
          id = "low_temperature_alert";
          alias = "Low Temperature Alert";
          description = "Alert when any room drops below 18°C";
          trigger = [{
            platform = "numeric_state";
            entity_id = [ "climate.ac_sala" "climate.ac_escritorio" "climate.ac_quarto" ];
            attribute = "current_temperature";
            below = 18;
            "for".minutes = 10;
          }];
          action = [{
            action = "notify.ntfy";
            data = {
              title = "Low Temperature Alert";
              message = "{{ trigger.to_state.attributes.friendly_name }} is at {{ trigger.to_state.attributes.current_temperature }}°C";
            };
          }];
        }

        # 9. Weekly Summary (Sunday 9 AM)
        # Note: To add CPU/Memory alerts, configure System Monitor integration first
        {
          id = "weekly_summary";
          alias = "Weekly Summary";
          description = "Send weekly summary every Sunday at 9 AM";
          trigger = [{ platform = "time"; at = "09:00:00"; }];
          condition = [{ condition = "time"; weekday = ["sun"]; }];
          action = [{
            action = "notify.ntfy";
            data = {
              title = "Weekly Summary";
              message = "Active AC units: {{ states('sensor.active_ac_units') }}";
            };
          }];
        }

        # 10. Workday Start Comfort - Simple morning trigger
        {
          id = "workday_start_comfort";
          alias = "Workday Start Comfort";
          description = "Turn on office AC at 8:30 on weekdays regardless of current temp";
          trigger = [{
            platform = "time";
            at = "08:30:00";
          }];
          condition = [
            {
              condition = "state";
              entity_id = "person.armando";
              state = "home";
            }
            {
              condition = "time";
              weekday = ["mon" "tue" "wed" "thu" "fri"];
            }
          ];
          action = [
            {
              action = "climate.set_hvac_mode";
              target.entity_id = "climate.ac_escritorio";
              data.hvac_mode = "heat";
            }
            { delay.seconds = 2; }
            {
              action = "climate.set_temperature";
              target.entity_id = "climate.ac_escritorio";
              data.temperature = 24;
            }
          ];
        }

        # 11. Weekend Morning Comfort - Later start on weekends
        {
          id = "weekend_morning_comfort";
          alias = "Weekend Morning Comfort";
          description = "Turn on living room AC at 10:00 on weekends";
          trigger = [{
            platform = "time";
            at = "10:00:00";
          }];
          condition = [
            {
              condition = "state";
              entity_id = "person.armando";
              state = "home";
            }
            {
              condition = "time";
              weekday = ["sat" "sun"];
            }
            {
              condition = "numeric_state";
              entity_id = "climate.ac_sala";
              attribute = "current_temperature";
              below = 23;
            }
          ];
          action = [
            {
              action = "climate.set_hvac_mode";
              target.entity_id = "climate.ac_sala";
              data.hvac_mode = "heat";
            }
            { delay.seconds = 2; }
            {
              action = "climate.set_temperature";
              target.entity_id = "climate.ac_sala";
              data.temperature = 23;
            }
          ];
        }

        # 12. Lunch Break Eco Mode - Reduce heating during lunch
        {
          id = "lunch_break_eco";
          alias = "Lunch Break Eco Mode";
          description = "Switch to fan-only during lunch break (12:00-13:30)";
          trigger = [{
            platform = "time";
            at = "12:00:00";
          }];
          condition = [
            {
              condition = "state";
              entity_id = "climate.ac_escritorio";
              state = "heat";
            }
            {
              condition = "time";
              weekday = ["mon" "tue" "wed" "thu" "fri"];
            }
          ];
          action = [{
            action = "climate.set_hvac_mode";
            target.entity_id = "climate.ac_escritorio";
            data.hvac_mode = "fan_only";
          }];
        }

        # 13. Lunch Break End - Resume heating after lunch
        {
          id = "lunch_break_end";
          alias = "Lunch Break End";
          description = "Resume heating after lunch break";
          trigger = [{
            platform = "time";
            at = "13:30:00";
          }];
          condition = [
            {
              condition = "state";
              entity_id = "climate.ac_escritorio";
              state = "fan_only";
            }
            {
              condition = "state";
              entity_id = "person.armando";
              state = "home";
            }
            {
              condition = "time";
              weekday = ["mon" "tue" "wed" "thu" "fri"];
            }
            {
              condition = "numeric_state";
              entity_id = "climate.ac_escritorio";
              attribute = "current_temperature";
              below = 23;
            }
          ];
          action = [
            {
              action = "climate.set_hvac_mode";
              target.entity_id = "climate.ac_escritorio";
              data.hvac_mode = "heat";
            }
            { delay.seconds = 2; }
            {
              action = "climate.set_temperature";
              target.entity_id = "climate.ac_escritorio";
              data.temperature = 24;
            }
          ];
        }

        # 14. Night Bedroom Prep - Pre-heat bedroom before bedtime
        {
          id = "night_bedroom_prep";
          alias = "Night Bedroom Prep";
          description = "Pre-heat bedroom 30 minutes before typical bedtime";
          trigger = [{
            platform = "time";
            at = "22:30:00";
          }];
          condition = [
            {
              condition = "state";
              entity_id = "person.armando";
              state = "home";
            }
            {
              condition = "numeric_state";
              entity_id = "climate.ac_quarto";
              attribute = "current_temperature";
              below = 20;
            }
          ];
          action = [
            {
              action = "climate.set_hvac_mode";
              target.entity_id = "climate.ac_quarto";
              data.hvac_mode = "heat";
            }
            { delay.seconds = 2; }
            {
              action = "climate.set_temperature";
              target.entity_id = "climate.ac_quarto";
              data.temperature = 21;
            }
            {
              action = "notify.ntfy";
              data = {
                title = "Bedroom Prep";
                message = "Pre-heating bedroom for 30 minutes";
              };
            }
            { delay.minutes = 30; }
            {
              action = "climate.turn_off";
              target.entity_id = "climate.ac_quarto";
            }
          ];
        }

        # 15. Cold Weather Boost - Extra heating when very cold outside
        {
          id = "cold_weather_boost";
          alias = "Cold Weather Boost";
          description = "Turn on extra AC when outdoor temp drops below 10°C";
          trigger = [{
            platform = "numeric_state";
            entity_id = "weather.forecast_home";
            attribute = "temperature";
            below = 10;
          }];
          condition = [
            {
              condition = "state";
              entity_id = "person.armando";
              state = "home";
            }
            {
              condition = "time";
              after = "08:00:00";
              before = "22:00:00";
            }
          ];
          action = [
            {
              action = "notify.ntfy";
              data = {
                title = "Cold Weather Alert";
                message = "Outside temp dropped below 10°C - consider using multiple AC units";
              };
            }
          ];
        }
      ];

      # ─────────────────────────────────────────────────────────────────
      # Convenience Scripts
      # ─────────────────────────────────────────────────────────────────
      script = {
        all_ac_off = {
          alias = "All AC Off";
          description = "Turn off all AC units";
          sequence = [{
            action = "climate.turn_off";
            target.entity_id = [
              "climate.ac_sala"
              "climate.ac_escritorio"
              "climate.ac_quarto"
              "climate.ac_quarto_hospedes"
            ];
          }];
        };

        guest_room_on = {
          alias = "Guest Room Heat";
          description = "Turn on guest room heating";
          sequence = [
            {
              action = "climate.set_hvac_mode";
              target.entity_id = "climate.ac_quarto_hospedes";
              data.hvac_mode = "heat";
            }
            { delay.seconds = 2; }
            {
              action = "climate.set_temperature";
              target.entity_id = "climate.ac_quarto_hospedes";
              data.temperature = 22;
            }
          ];
        };

        bedroom_quick_heat = {
          alias = "Bedroom Quick Heat";
          description = "Heat bedroom for 30 minutes before bed";
          sequence = [
            {
              action = "climate.set_hvac_mode";
              target.entity_id = "climate.ac_quarto";
              data.hvac_mode = "heat";
            }
            { delay.seconds = 2; }
            {
              action = "climate.set_temperature";
              target.entity_id = "climate.ac_quarto";
              data.temperature = 22;
            }
            { delay.minutes = 30; }
            {
              action = "climate.turn_off";
              target.entity_id = "climate.ac_quarto";
            }
          ];
        };
      };

      # ─────────────────────────────────────────────────────────────────
      # Notification Configuration
      # ─────────────────────────────────────────────────────────────────
      notify = [{
        platform = "rest";
        name = "ntfy";
        resource = "http://10.100.0.100:8106/home-assistant";
        method = "POST_JSON";
        data.topic = "home-assistant";
        message_param_name = "message";
        title_param_name = "title";
      }];
    };

    extraComponents = [
      # ─────────────────────────────────────────────────────────────
      # Core & System
      # ─────────────────────────────────────────────────────────────
      "default_config"
      "hassio"                 # Home Assistant Supervisor
      "homeassistant_alerts"   # HA security alerts
      "isal"                   # Fast compression

      # ─────────────────────────────────────────────────────────────
      # Communication Protocols
      # ─────────────────────────────────────────────────────────────
      "bluetooth"              # Bluetooth
      "bluetooth_adapters"     # Bluetooth adapter support
      "mqtt"                   # MQTT for IoT
      "websocket_api"          # WebSocket API
      "rest"                   # REST API
      "webhook"                # Webhooks
      "knx"                    # KNX home automation bus

      # ─────────────────────────────────────────────────────────────
      # Smart Home Standards
      # ─────────────────────────────────────────────────────────────
      "homekit"                # Apple HomeKit bridge
      "homekit_controller"     # Control HomeKit devices
      "matter"                 # Matter protocol
      "thread"                 # Thread network
      "zha"                    # Zigbee Home Automation
      "zwave_js"               # Z-Wave JS

      # ─────────────────────────────────────────────────────────────
      # Climate & Appliances
      # ─────────────────────────────────────────────────────────────
      "gree"                   # Gree AC
      "generic_thermostat"     # Generic thermostat
      "anova"                  # Anova Sous Vide
      "meater"                 # Meater meat thermometer
      "eufy"                   # Eufy devices

      # ─────────────────────────────────────────────────────────────
      # Media & Entertainment
      # ─────────────────────────────────────────────────────────────
      "cast"                   # Google Cast
      "dlna_dmr"               # DLNA renderer
      "dlna_dms"               # DLNA media server
      "jellyfin"               # Jellyfin
      "plex"                   # Plex
      "spotify"                # Spotify
      "mpd"                    # Music Player Daemon
      "webostv"                # LG WebOS TV
      "radio_browser"          # Internet radio
      "steam_online"           # Steam presence

      # ─────────────────────────────────────────────────────────────
      # Media Management (Servarr)
      # ─────────────────────────────────────────────────────────────
      "sonarr"                 # TV shows
      "radarr"                 # Movies
      "lidarr"                 # Music
      "deluge"                 # Torrent client

      # ─────────────────────────────────────────────────────────────
      # Cloud & Self-Hosted Services
      # ─────────────────────────────────────────────────────────────
      "nextcloud"              # Nextcloud
      "immich"                 # Immich photos
      "syncthing"              # Syncthing
      "uptime_kuma"            # Uptime monitoring
      "github"                 # GitHub

      # ─────────────────────────────────────────────────────────────
      # AI & Voice
      # ─────────────────────────────────────────────────────────────
      "anthropic"              # Anthropic Claude
      "ollama"                 # Ollama local LLM
      "whisper"                # Whisper speech-to-text
      "wyoming"                # Wyoming protocol
      "stt"                    # Speech-to-text
      "tts"                    # Text-to-speech
      "google_translate"       # Google Translate TTS

      # ─────────────────────────────────────────────────────────────
      # Notifications & Messaging
      # ─────────────────────────────────────────────────────────────
      "notify"                 # Notification system
      "persistent_notification" # Persistent notifications
      "ntfy"                   # ntfy.sh
      "discord"                # Discord
      "signal_messenger"       # Signal
      "facebook"               # Facebook Messenger

      # ─────────────────────────────────────────────────────────────
      # Network & Discovery
      # ─────────────────────────────────────────────────────────────
      "upnp"                   # UPnP
      "ssdp"                   # SSDP
      "dhcp"                   # DHCP
      "network"                # Network utilities
      "ping"                   # Ping tracker
      "speedtestdotnet"        # Internet speed test
      "no_ip"                  # No-IP DDNS

      # ─────────────────────────────────────────────────────────────
      # Presence & Location
      # ─────────────────────────────────────────────────────────────
      "person"                 # Person tracking
      "device_tracker"         # Device tracking
      "mobile_app"             # HA mobile app
      "waze_travel_time"       # Waze travel time

      # ─────────────────────────────────────────────────────────────
      # Weather & Environment
      # ─────────────────────────────────────────────────────────────
      "met"                    # Met.no weather
      "sun"                    # Sun position
      "moon"                   # Moon phase
      "forecast_solar"         # Solar forecast

      # ─────────────────────────────────────────────────────────────
      # Energy & Monitoring
      # ─────────────────────────────────────────────────────────────
      "energy"                 # Energy dashboard
      "systemmonitor"          # System monitor
      "prometheus"             # Prometheus metrics

      # ─────────────────────────────────────────────────────────────
      # Automation & Scripting
      # ─────────────────────────────────────────────────────────────
      "automation"             # Automations
      "scene"                  # Scenes
      "script"                 # Scripts
      "schedule"               # Scheduling
      "shell_command"          # Shell commands
      "command_line"           # Command line sensors

      # ─────────────────────────────────────────────────────────────
      # History & Recording
      # ─────────────────────────────────────────────────────────────
      "recorder"               # State recorder
      "history"                # History
      "logbook"                # Logbook

      # ─────────────────────────────────────────────────────────────
      # Utilities & Other
      # ─────────────────────────────────────────────────────────────
      "calendar"               # Calendar
      "google"                 # google
      "shopping_list"          # Shopping list
      "xiaomi"                 # Xiaomi devices
    ];

    customComponents = [
      hacs  # Home Assistant Community Store
    ] ++ (with pkgs.home-assistant-custom-components; [
      prometheus_sensor
      xiaomi_home
      garmin_connect
    ]);

    # Custom Lovelace modules for modern UI dashboard
    customLovelaceModules = with pkgs.home-assistant-custom-lovelace-modules; [
      # Essential card libraries
      bubble-card             # Modern nice cards
      mini-graph-card         # Compact graphs
      mushroom                # Modern card collection (chips, entity, climate, media player)
      button-card             # Customizable buttons

      # Specialized cards
      lg-webos-remote-control # LG WebOS TV Remote
      universal-remote-card   # Universal remote

      # Advanced functionality
      auto-entities           # Dynamic entity filtering for cards
      card-mod                # CSS customization for any card
      apexcharts-card         # Advanced charting
    ];

    # Extra Python packages for recorder
    extraPackages = python3Packages: with python3Packages; [
      psycopg2               # PostgreSQL support (optional)
    ];

    # ─────────────────────────────────────────────────────────────────
    # Declarative Fancy Dashboard (Lovelace YAML Mode)
    # ─────────────────────────────────────────────────────────────────
    lovelaceConfig = {
      # Theme configuration
      background = "var(--lovelace-background)";
      title = "Ninho";

      # Main Dashboard Views
      views = [
        # ─────────────────────────────────────────────────────────────
        # HOME OVERVIEW - Quick status and actions
        # ─────────────────────────────────────────────────────────────
        {
          title = "Home";
          icon = "mdi:home";
          path = "home";
          badges = [
            { entity = "person.armando"; }
            { entity = "sun.sun"; }
            { entity = "sensor.time"; }
            { entity = "sensor.date"; }
            { entity = "sensor.uptime"; }
          ];
          cards = [
            # Header - Welcome (Dynamic greeting based on time of day)
            {
              type = "custom:button-card";
              entity = "sensor.time_of_day";
              name = "[[[ return 'Good ' + entity.state + ', Armando' ]]]";
              styles = {
                card = [
                  { "background" = "linear-gradient(135deg, #667eea 0%, #764ba2 100%)"; }
                  { "color" = "white"; }
                  { "font-size" = "24px"; }
                  { "font-weight" = "bold"; }
                  { "padding" = "20px"; }
                  { "border-radius" = "16px"; }
                ];
              };
            }
            # Presence & Status Row
            {
              type = "custom:mushroom-chips-card";
              alignment = "center";
              chips = [
                {
                  type = "entity";
                  entity = "person.armando";
                  content_info = "state";
                }
                {
                  type = "template";
                  icon = "mdi:air-conditioner";
                  content = "{{ states('sensor.active_ac_units') }} AC";
                  icon_color = "{% if states('sensor.active_ac_units')|int > 0 %}blue{% else %}grey{% endif %}";
                }
                {
                  type = "entity";
                  entity = "sensor.uptime";
                  icon = "mdi:clock-check";
                }
              ];
            }
            # Weather Card - Met.no
            {
              type = "weather-forecast";
              entity = "weather.forecast_home";
              show_forecast = true;
              forecast_type = "daily";
            }
            # Quick AC Controls
            {
              type = "custom:mushroom-title-card";
              title = "Climate";
              subtitle = "Quick AC controls";
            }
            {
              type = "horizontal-stack";
              cards = [
                {
                  type = "custom:mushroom-climate-card";
                  entity = "climate.ac_sala";
                  name = "Sala";
                  icon = "mdi:sofa";
                  show_temperature_control = true;
                  collapsible_controls = true;
                }
                {
                  type = "custom:mushroom-climate-card";
                  entity = "climate.ac_escritorio";
                  name = "Escritório";
                  icon = "mdi:desk";
                  show_temperature_control = true;
                  collapsible_controls = true;
                }
                {
                  type = "custom:mushroom-climate-card";
                  entity = "climate.ac_quarto";
                  name = "Quarto";
                  icon = "mdi:bed";
                  show_temperature_control = true;
                  collapsible_controls = true;
                }
              ];
            }
            # Quick Automation Chips
            {
              type = "custom:mushroom-chips-card";
              alignment = "center";
              chips = [
                {
                  type = "template";
                  icon = "mdi:power-off";
                  icon_color = "red";
                  content = "All AC Off";
                  tap_action = {
                    action = "call-service";
                    service = "script.all_ac_off";
                  };
                }
                {
                  type = "template";
                  icon = "mdi:weather-night";
                  icon_color = "blue";
                  content = "Night Mode";
                  tap_action = {
                    action = "call-service";
                    service = "script.all_ac_off";
                  };
                }
                {
                  type = "template";
                  icon = "mdi:home-automation";
                  icon_color = "green";
                  content = "Away Mode";
                  tap_action = {
                    action = "call-service";
                    service = "automation.trigger";
                    service_data = { entity_id = "automation.away_mode_ac_off"; };
                  };
                }
              ];
            }
            # Script Quick Actions
            {
              type = "grid";
              columns = 2;
              square = false;
              cards = [
                {
                  type = "custom:mushroom-entity-card";
                  entity = "script.all_ac_off";
                  name = "All AC Off";
                  icon = "mdi:power";
                  tap_action = {
                    action = "call-service";
                    service = "script.all_ac_off";
                  };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "script.guest_room_on";
                  name = "Guest Room Heat";
                  icon = "mdi:bed guest";
                  tap_action = {
                    action = "call-service";
                    service = "script.guest_room_on";
                  };
                }
              ];
            }
          ];
        }

        # ─────────────────────────────────────────────────────────────
        # CLIMATE - Detailed AC controls (Gree)
        # ─────────────────────────────────────────────────────────────
        {
          title = "Climate";
          icon = "mdi:thermostat";
          path = "climate";
          cards = [
            # Header with status
            {
              type = "custom:mushroom-title-card";
              title = "Climate Control";
              subtitle = "Gree AC units";
            }
            # Status chips - Active units, outdoor temp
            {
              type = "custom:mushroom-chips-card";
              alignment = "center";
              chips = [
                {
                  type = "template";
                  icon = "mdi:air-conditioner";
                  content = "{{ states('sensor.active_ac_units') }} Active";
                  icon_color = "{% if states('sensor.active_ac_units')|int > 0 %}blue{% else %}grey{% endif %}";
                }
                {
                  type = "weather";
                  entity = "weather.forecast_home";
                  show_conditions = true;
                  show_temperature = true;
                }
              ];
            }
            # Quick Actions
            {
              type = "custom:mushroom-chips-card";
              alignment = "center";
              chips = [
                {
                  type = "template";
                  icon = "mdi:power-off";
                  content = "All Off";
                  icon_color = "red";
                  tap_action = {
                    action = "call-service";
                    service = "script.all_ac_off";
                  };
                }
                {
                  type = "template";
                  icon = "mdi:snowflake";
                  content = "Cool All";
                  icon_color = "blue";
                  tap_action = {
                    action = "call-service";
                    service = "climate.set_temperature";
                    service_data = {
                      entity_id = [ "climate.ac_sala" "climate.ac_escritorio" "climate.ac_quarto" ];
                      temperature = 22;
                      hvac_mode = "cool";
                    };
                  };
                }
                {
                  type = "template";
                  icon = "mdi:fire";
                  content = "Heat All";
                  icon_color = "orange";
                  tap_action = {
                    action = "call-service";
                    service = "climate.set_temperature";
                    service_data = {
                      entity_id = [ "climate.ac_sala" "climate.ac_escritorio" "climate.ac_quarto" ];
                      temperature = 24;
                      hvac_mode = "heat";
                    };
                  };
                }
              ];
            }
            # Living Room - Full Thermostat Card
            {
              type = "thermostat";
              entity = "climate.ac_sala";
              name = "Sala (Living Room)";
              features = [
                { type = "climate-hvac-modes"; hvac_modes = [ "off" "cool" "heat" "fan_only" "auto" ]; }
                { type = "climate-fan-modes"; }
              ];
            }
            # Office - Full Thermostat Card
            {
              type = "thermostat";
              entity = "climate.ac_escritorio";
              name = "Escritório (Office)";
              features = [
                { type = "climate-hvac-modes"; hvac_modes = [ "off" "cool" "heat" "fan_only" "auto" ]; }
                { type = "climate-fan-modes"; }
              ];
            }
            # Bedroom with Quick Heat
            {
              type = "vertical-stack";
              cards = [
                {
                  type = "thermostat";
                  entity = "climate.ac_quarto";
                  name = "Quarto (Bedroom)";
                  features = [
                    { type = "climate-hvac-modes"; hvac_modes = [ "off" "cool" "heat" "fan_only" "auto" ]; }
                  ];
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "script.bedroom_quick_heat";
                  name = "Quick Heat (30 min)";
                  icon = "mdi:clock-fast";
                  tap_action = {
                    action = "call-service";
                    service = "script.bedroom_quick_heat";
                  };
                }
              ];
            }
            # Guest Room with Heat Script
            {
              type = "vertical-stack";
              cards = [
                {
                  type = "thermostat";
                  entity = "climate.ac_quarto_hospedes";
                  name = "Quarto de Hóspedes (Guest)";
                  features = [
                    { type = "climate-hvac-modes"; hvac_modes = [ "off" "cool" "heat" "fan_only" "auto" ]; }
                  ];
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "script.guest_room_on";
                  name = "Guest Room Heat";
                  icon = "mdi:fire";
                  tap_action = {
                    action = "call-service";
                    service = "script.guest_room_on";
                  };
                }
              ];
            }
            # Temperature History Graph (24h)
            {
              type = "custom:mini-graph-card";
              name = "Temperature History (24h)";
              icon = "mdi:thermometer";
              hours_to_show = 24;
              points_per_hour = 4;
              line_width = 2;
              animate = true;
              show = {
                labels = true;
                points = false;
                legend = true;
              };
              entities = [
                {
                  entity = "climate.ac_sala";
                  attribute = "current_temperature";
                  name = "Sala";
                  color = "#FF9800";
                }
                {
                  entity = "climate.ac_escritorio";
                  attribute = "current_temperature";
                  name = "Escritório";
                  color = "#2196F3";
                }
                {
                  entity = "climate.ac_quarto";
                  attribute = "current_temperature";
                  name = "Quarto";
                  color = "#9C27B0";
                }
                {
                  entity = "climate.ac_quarto_hospedes";
                  attribute = "current_temperature";
                  name = "Hóspedes";
                  color = "#4CAF50";
                }
              ];
            }
          ];
        }

        # ─────────────────────────────────────────────────────────────
        # SERVICES - Quick access to self-hosted services
        # ─────────────────────────────────────────────────────────────
        {
          title = "Services";
          icon = "mdi:apps";
          path = "services";
          cards = [
            {
              type = "custom:mushroom-title-card";
              title = "Self-Hosted Services";
              subtitle = "Quick access to all services";
            }
            # Media Services Row
            {
              type = "horizontal-stack";
              cards = [
                {
                  type = "custom:mushroom-template-card";
                  primary = "Jellyfin";
                  secondary = "Media Server";
                  icon = "mdi:play-box-multiple";
                  icon_color = "purple";
                  tap_action = { action = "url"; url_path = "http://10.100.0.100:8096"; };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Navidrome";
                  secondary = "Music";
                  icon = "mdi:music";
                  icon_color = "green";
                  tap_action = { action = "url"; url_path = "http://10.100.0.100:8105"; };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Immich";
                  secondary = "Photos";
                  icon = "mdi:image-multiple";
                  icon_color = "blue";
                  tap_action = { action = "url"; url_path = "http://10.100.0.100:2283"; };
                }
              ];
            }
            # Cloud Services Row
            {
              type = "horizontal-stack";
              cards = [
                {
                  type = "custom:mushroom-template-card";
                  primary = "Nextcloud";
                  secondary = "Files";
                  icon = "mdi:cloud";
                  icon_color = "blue";
                  tap_action = { action = "url"; url_path = "http://10.100.0.100:8081"; };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Syncthing";
                  secondary = "Sync";
                  icon = "mdi:sync";
                  icon_color = "cyan";
                  tap_action = { action = "url"; url_path = "http://10.100.0.100:8384"; };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "FileBrowser";
                  secondary = "Web Files";
                  icon = "mdi:folder";
                  icon_color = "orange";
                  tap_action = { action = "url"; url_path = "http://10.100.0.100:8107"; };
                }
              ];
            }
            # AI Services Row
            {
              type = "horizontal-stack";
              cards = [
                {
                  type = "custom:mushroom-template-card";
                  primary = "llama-swap";
                  secondary = "LLM API";
                  icon = "mdi:brain";
                  icon_color = "yellow";
                  tap_action = { action = "url"; url_path = "http://10.100.0.100:8080"; };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "ComfyUI";
                  secondary = "Image Gen";
                  icon = "mdi:image-auto-adjust";
                  icon_color = "pink";
                  tap_action = { action = "url"; url_path = "http://10.100.0.100:8188"; };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Homepage";
                  secondary = "Dashboard";
                  icon = "mdi:view-dashboard";
                  icon_color = "slate";
                  tap_action = { action = "url"; url_path = "http://10.100.0.100:8082"; };
                }
              ];
            }
            # Monitoring Row
            {
              type = "horizontal-stack";
              cards = [
                {
                  type = "custom:mushroom-template-card";
                  primary = "Grafana";
                  secondary = "Metrics";
                  icon = "mdi:chart-areaspline";
                  icon_color = "orange";
                  tap_action = { action = "url"; url_path = "http://10.100.0.100:3000"; };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Uptime Kuma";
                  secondary = "Status";
                  icon = "mdi:heart-pulse";
                  icon_color = "green";
                  tap_action = { action = "url"; url_path = "http://10.100.0.100:8109"; };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Ntfy";
                  secondary = "Notifications";
                  icon = "mdi:bell";
                  icon_color = "red";
                  tap_action = { action = "url"; url_path = "http://10.100.0.100:8106"; };
                }
              ];
            }
          ];
        }

        # ─────────────────────────────────────────────────────────────
        # MEDIA - Entertainment controls
        # ─────────────────────────────────────────────────────────────
        {
          title = "Media";
          icon = "mdi:play-circle";
          path = "media";
          cards = [
            {
              type = "custom:mushroom-title-card";
              title = "Media & Entertainment";
              subtitle = "TV, Music, and Streaming";
            }
            # LG WebOS TV (main entertainment device)
            {
              type = "custom:mushroom-title-card";
              title = "Living Room TV";
            }
            {
              type = "custom:mushroom-media-player-card";
              entity = "media_player.lg_webos_tv";
              name = "LG TV";
              icon = "mdi:television";
              use_media_info = true;
              show_volume_level = true;
              media_controls = [ "on_off" "play_pause_stop" ];
              volume_controls = [ "volume_buttons" "volume_mute" ];
            }
            # LG WebOS Remote Control
            {
              type = "custom:lg-webos-remote-control";
              entity = "media_player.lg_webos_tv";
            }
            # Spotify
            {
              type = "custom:mushroom-title-card";
              title = "Music";
            }
            {
              type = "custom:mushroom-media-player-card";
              entity = "media_player.spotify";
              name = "Spotify";
              icon = "mdi:spotify";
              use_media_info = true;
              show_volume_level = true;
              media_controls = [ "play_pause_stop" "previous" "next" "shuffle" "repeat" ];
              volume_controls = [ "volume_slider" ];
            }
            # Jellyfin Media Server
            {
              type = "custom:mushroom-title-card";
              title = "Jellyfin";
            }
            {
              type = "custom:mushroom-media-player-card";
              entity = "media_player.jellyfin";
              name = "Jellyfin";
              icon = "mdi:play-box-multiple";
              use_media_info = true;
              show_volume_level = true;
              media_controls = [ "on_off" "play_pause_stop" "previous" "next" ];
              volume_controls = [ "volume_buttons" "volume_mute" ];
            }
            # Active Media Sessions (auto-discovers all playing media)
            {
              type = "custom:auto-entities";
              card = {
                type = "entities";
                title = "Now Playing";
              };
              filter = {
                include = [
                  { domain = "media_player"; state = "playing"; }
                  { domain = "media_player"; state = "paused"; }
                ];
              };
              sort = {
                method = "state";
              };
              show_empty = false;
            }
            # Jellyfin Library Stats
            {
              type = "horizontal-stack";
              cards = [
                {
                  type = "custom:mushroom-entity-card";
                  entity = "sensor.jellyfin_movies";
                  name = "Movies";
                  icon = "mdi:movie";
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "sensor.jellyfin_series";
                  name = "Series";
                  icon = "mdi:television-classic";
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "sensor.jellyfin_music";
                  name = "Albums";
                  icon = "mdi:music";
                }
              ];
            }
            # Service Quick Links
            {
              type = "horizontal-stack";
              cards = [
                {
                  type = "custom:mushroom-template-card";
                  primary = "Jellyfin";
                  secondary = "Media Server";
                  icon = "mdi:play-box-multiple";
                  icon_color = "purple";
                  tap_action = { action = "url"; url_path = "http://10.100.0.100:8096"; };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Navidrome";
                  secondary = "Music";
                  icon = "mdi:music";
                  icon_color = "green";
                  tap_action = { action = "url"; url_path = "http://10.100.0.100:8105"; };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Immich";
                  secondary = "Photos";
                  icon = "mdi:image-multiple";
                  icon_color = "blue";
                  tap_action = { action = "url"; url_path = "http://10.100.0.100:2283"; };
                }
              ];
            }
          ];
        }

        # ─────────────────────────────────────────────────────────────
        # ENERGY - Energy monitoring
        # ─────────────────────────────────────────────────────────────
        {
          title = "Energy";
          icon = "mdi:lightning-bolt";
          path = "energy";
          cards = [
            {
              type = "custom:mushroom-title-card";
              title = "Energy Dashboard";
              subtitle = "Configure energy sensors via Settings > Dashboards > Energy";
            }
            {
              type = "markdown";
              content = ''
                ## Setup Required

                To use the Energy dashboard:
                1. Go to **Settings → Dashboards → Energy**
                2. Add your electricity grid consumption sensor
                3. Optionally add solar production, battery, and gas sensors

                Once configured, the energy cards will display your usage data.
              '';
            }
          ];
        }

        # ─────────────────────────────────────────────────────────────
        # SYSTEM - Monitoring & Status
        # ─────────────────────────────────────────────────────────────
        {
          title = "System";
          icon = "mdi:server";
          path = "system";
          cards = [
            # Title
            {
              type = "custom:mushroom-title-card";
              title = "System Status";
              subtitle = "Ninho server monitoring";
            }
            # Uptime chip
            {
              type = "custom:mushroom-chips-card";
              alignment = "center";
              chips = [
                {
                  type = "entity";
                  entity = "sensor.uptime";
                  icon = "mdi:clock-check";
                }
              ];
            }
            # System Resources (from System Monitor integration)
            {
              type = "custom:mushroom-title-card";
              title = "System Resources";
            }
            {
              type = "horizontal-stack";
              cards = [
                {
                  type = "gauge";
                  entity = "sensor.processor_use";
                  name = "CPU";
                  min = 0;
                  max = 100;
                  severity = { green = 0; yellow = 70; red = 90; };
                }
                {
                  type = "gauge";
                  entity = "sensor.memory_use_percent";
                  name = "Memory";
                  min = 0;
                  max = 100;
                  severity = { green = 0; yellow = 70; red = 90; };
                }
              ];
            }
            {
              type = "horizontal-stack";
              cards = [
                {
                  type = "gauge";
                  entity = "sensor.disk_use_percent";
                  name = "Root Disk";
                  min = 0;
                  max = 100;
                  severity = { green = 0; yellow = 70; red = 90; };
                }
                {
                  type = "gauge";
                  entity = "sensor.disk_use_percent_storage";
                  name = "Storage";
                  min = 0;
                  max = 100;
                  severity = { green = 0; yellow = 70; red = 90; };
                }
              ];
            }
            # System Load History
            {
              type = "custom:mini-graph-card";
              name = "System Load (24h)";
              icon = "mdi:speedometer";
              hours_to_show = 24;
              points_per_hour = 4;
              line_width = 2;
              entities = [
                { entity = "sensor.load_1m"; name = "1 min"; color = "#4CAF50"; }
                { entity = "sensor.load_5m"; name = "5 min"; color = "#FF9800"; }
                { entity = "sensor.load_15m"; name = "15 min"; color = "#F44336"; }
              ];
            }
            # CPU History
            {
              type = "custom:mini-graph-card";
              name = "CPU Usage (24h)";
              icon = "mdi:cpu-64-bit";
              hours_to_show = 24;
              points_per_hour = 4;
              line_width = 2;
              entities = [
                { entity = "sensor.processor_use"; name = "CPU"; color = "#2196F3"; }
              ];
            }
            # Automations Status
            {
              type = "custom:mushroom-title-card";
              title = "Climate Automations";
            }
            {
              type = "grid";
              columns = 2;
              square = false;
              cards = [
                {
                  type = "custom:mushroom-entity-card";
                  entity = "automation.office_preheat_morning";
                  name = "Morning Pre-Heat";
                  icon = "mdi:weather-sunset-up";
                  tap_action = { action = "toggle"; };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "automation.evening_transition_office_to_sala";
                  name = "Evening Transition";
                  icon = "mdi:weather-sunset-down";
                  tap_action = { action = "toggle"; };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "automation.night_shutdown_all_ac";
                  name = "Night Shutdown";
                  icon = "mdi:weather-night";
                  tap_action = { action = "toggle"; };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "automation.away_mode_ac_off";
                  name = "Away Mode";
                  icon = "mdi:home-export-outline";
                  tap_action = { action = "toggle"; };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "automation.return_home_smart_preheat";
                  name = "Return Home";
                  icon = "mdi:home-import-outline";
                  tap_action = { action = "toggle"; };
                }
              ];
            }
          ];
        }

        # ─────────────────────────────────────────────────────────────
        # CALENDAR - Schedule & Lists
        # ─────────────────────────────────────────────────────────────
        {
          title = "Calendar";
          icon = "mdi:calendar";
          path = "calendar";
          cards = [
            {
              type = "custom:mushroom-title-card";
              title = "Schedule & Lists";
              subtitle = "Your calendars and shopping list";
            }
            # Google Calendar - shows all Google calendars
            {
              type = "custom:auto-entities";
              card = {
                type = "calendar";
                title = "Google Calendar";
              };
              filter = {
                include = [
                  { entity_id = "calendar.*"; }
                ];
              };
            }
            # Upcoming Events (next 7 days)
            {
              type = "custom:auto-entities";
              card = {
                type = "entities";
                title = "Upcoming Events";
              };
              filter = {
                include = [
                  { entity_id = "calendar.*"; options = { secondary_info = "last-changed"; }; }
                ];
              };
            }
            # Shopping list
            {
              type = "shopping-list";
            }
          ];
        }

        # ─────────────────────────────────────────────────────────────
        # SETTINGS - Configuration
        # ─────────────────────────────────────────────────────────────
        {
          title = "Settings";
          icon = "mdi:cog";
          path = "settings";
          cards = [
            {
              type = "custom:mushroom-title-card";
              title = "Dashboard Settings";
            }
            {
              type = "custom:button-card";
              name = "Reload Dashboard";
              icon = "mdi:refresh";
              tap_action = {
                action = "call-service";
                service = "homeassistant.reload_core_config";
              };
            }
            {
              type = "custom:button-card";
              name = "Restart Home Assistant";
              icon = "mdi:restart";
              tap_action = {
                action = "call-service";
                service = "homeassistant.restart";
                confirmation = {
                  text = "Are you sure you want to restart Home Assistant?";
                };
              };
            }
          ];
        }
      ];
    };
  };

  # Create config directory with proper structure
  # Note: automations and scripts are now managed declaratively in Nix
  # Only scenes.yaml is needed for UI-managed scenes
  systemd.tmpfiles.rules = [
    "d ${hassHome} 0750 hass hass - -"
    "f ${hassHome}/scenes.yaml 0640 hass hass - -"
  ];
}
