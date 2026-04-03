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
            # ── Garmin Recovery & Training Sensors ──
            {
              name = "Recovery Score";
              unique_id = "recovery_score";
              availability = "{{ states('sensor.garmin_connect_body_battery_most_recent') not in ['unknown', 'unavailable'] or states('sensor.garmin_connect_sleep_score') not in ['unknown', 'unavailable'] or states('sensor.garmin_connect_avg_stress_level') not in ['unknown', 'unavailable'] }}";
              state = ''
                {% set bb = states('sensor.garmin_connect_body_battery_most_recent') | float(-1) %}
                {% set ss = states('sensor.garmin_connect_sleep_score') | float(-1) %}
                {% set st = states('sensor.garmin_connect_avg_stress_level') | float(-1) %}
                {% set ns = namespace(weight=0, score=0) %}
                {% if bb >= 0 %}{% set ns.weight = ns.weight + 0.4 %}{% set ns.score = ns.score + (bb * 0.4) %}{% endif %}
                {% if ss >= 0 %}{% set ns.weight = ns.weight + 0.3 %}{% set ns.score = ns.score + (ss * 0.3) %}{% endif %}
                {% if st >= 0 %}{% set ns.weight = ns.weight + 0.3 %}{% set ns.score = ns.score + ((100 - st) * 0.3) %}{% endif %}
                {% if ns.weight > 0 %}{{ (ns.score / ns.weight) | round(0) }}{% else %}unavailable{% endif %}
              '';
              state_class = "measurement";
              unit_of_measurement = "%";
              icon = "mdi:heart-pulse";
            }
            {
              name = "Training Readiness";
              unique_id = "training_readiness";
              availability = "{{ states('sensor.recovery_score') not in ['unknown', 'unavailable'] }}";
              state = "{% set score = states('sensor.recovery_score') | float(-1) %}{% if score < 0 %}unavailable{% elif score >= 70 %}Ready{% elif score >= 50 %}Moderate{% else %}Rest{% endif %}";
              icon = "mdi:dumbbell";
            }
            {
              name = "Smart HVAC Mode";
              unique_id = "smart_hvac_mode";
              state = "{% set outdoor = state_attr('weather.forecast_home', 'temperature') | float(15) %}{% if outdoor > 25 %}cool{% else %}heat{% endif %}";
              icon = "mdi:thermostat-auto";
            }
          ];
        }
        {
          binary_sensor = [
            {
              name = "Outdoor Requires Heating";
              unique_id = "outdoor_requires_heating";
              state = "{{ state_attr('weather.forecast_home', 'temperature') | float(15) < 15 }}";
              icon = "mdi:thermometer-low";
            }
            {
              name = "Outdoor Requires Cooling";
              unique_id = "outdoor_requires_cooling";
              state = "{{ state_attr('weather.forecast_home', 'temperature') | float(15) > 25 }}";
              icon = "mdi:thermometer-high";
            }
          ];
        }
      ];

      # ─────────────────────────────────────────────────────────────────
      # History Stats Sensors - AC Runtime Tracking
      # ─────────────────────────────────────────────────────────────────
      sensor = [
        {
          platform = "history_stats";
          name = "AC Sala Runtime Today";
          entity_id = "climate.ac_sala";
          state = ["heat" "cool" "fan_only" "auto"];
          type = "time";
          start = "{{ today_at('00:00') }}";
          end = "{{ now() }}";
        }
        {
          platform = "history_stats";
          name = "AC Escritorio Runtime Today";
          entity_id = "climate.ac_escritorio";
          state = ["heat" "cool" "fan_only" "auto"];
          type = "time";
          start = "{{ today_at('00:00') }}";
          end = "{{ now() }}";
        }
        {
          platform = "history_stats";
          name = "AC Quarto Runtime Today";
          entity_id = "climate.ac_quarto";
          state = ["heat" "cool" "fan_only" "auto"];
          type = "time";
          start = "{{ today_at('00:00') }}";
          end = "{{ now() }}";
        }
        {
          platform = "history_stats";
          name = "AC Quarto Hospedes Runtime Today";
          entity_id = "climate.ac_quarto_hospedes";
          state = ["heat" "cool" "fan_only" "auto"];
          type = "time";
          start = "{{ today_at('00:00') }}";
          end = "{{ now() }}";
        }
      ];

      # Energy monitoring dashboard
      energy = {};

      # Scenes (managed via UI)
      scene = "!include scenes.yaml";

      # ─────────────────────────────────────────────────────────────────
      # Ntfy Notification (REST command to local ntfy server)
      # ─────────────────────────────────────────────────────────────────
      rest_command = {
        ntfy_notify = {
          url = "http://127.0.0.1:${toString ports.ntfy}/home-assistant";
          method = "POST";
          headers = {
            Title = "{{ title }}";
            Priority = "{{ priority | default('default') }}";
            Tags = "{{ tags | default('house') }}";
          };
          content_type = "text/plain";
          payload = "{{ message }}";
        };
      };

      # ─────────────────────────────────────────────────────────────────
      # Climate Automations
      # ─────────────────────────────────────────────────────────────────
      automation = [
        # 3. Night Shutdown - All AC Off
        {
          id = "night_shutdown_all_ac";
          alias = "Night Shutdown All AC";
          description = "Turn off all AC at 11:30 PM (bedtime)";
          trigger = [{
            platform = "time";
            at = "23:30:00";
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
              action = "rest_command.ntfy_notify";
              data = {
                title = "Night Shutdown";
                message = "Bedtime - all AC units turned off";
              };
            }
          ];
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
              action = "rest_command.ntfy_notify";
              data = {
                message = "You left home - all AC units turned off";
                title = "Away Mode Activated";
              };
            }
          ];
        }

        # 5a. Return from Lunch Gym - Office Reheat
        {
          id = "return_lunch_gym_office_reheat";
          alias = "Return Home - Smart Pre-Heat";
          description = "Reheat office after lunch gym if temperature dropped";
          trigger = [{
            platform = "state";
            entity_id = "person.armando";
            from = "not_home";
            to = "home";
          }];
          condition = [
            {
              condition = "time";
              after = "12:00:00";
              before = "16:00:00";
              weekday = ["mon" "tue" "wed" "thu" "fri"];
            }
            {
              condition = "or";
              conditions = [
                {
                  condition = "state";
                  entity_id = "binary_sensor.outdoor_requires_heating";
                  state = "on";
                }
                {
                  condition = "state";
                  entity_id = "binary_sensor.outdoor_requires_cooling";
                  state = "on";
                }
              ];
            }
            {
              condition = "template";
              value_template = ''
                {% set outdoor = state_attr('weather.forecast_home', 'temperature') | float(15) %}
                {% set indoor = state_attr('climate.ac_escritorio', 'current_temperature') | float(20) %}
                {{ (outdoor < 15 and indoor < 20) or (outdoor > 25 and indoor > 23) }}
              '';
            }
          ];
          action = [
            {
              action = "climate.set_hvac_mode";
              target.entity_id = "climate.ac_escritorio";
              data.hvac_mode = "{{ states('sensor.smart_hvac_mode') }}";
            }
            { delay.seconds = 2; }
            {
              action = "climate.set_temperature";
              target.entity_id = "climate.ac_escritorio";
              data.temperature = 22;
            }
            {
              action = "rest_command.ntfy_notify";
              data = {
                title = "Welcome Back";
                message = "Back from gym - office AC on to 22°C (was {{ state_attr('climate.ac_escritorio', 'current_temperature') }}°C)";
              };
            }
          ];
        }

        # 5b. Return from Evening - Sala Comfort
        {
          id = "return_evening_sala_comfort";
          alias = "Return Home - Smart Pre-Heat";
          description = "Condition living room after evening return (track & field)";
          trigger = [{
            platform = "state";
            entity_id = "person.armando";
            from = "not_home";
            to = "home";
          }];
          condition = [
            {
              condition = "time";
              after = "18:00:00";
              before = "23:00:00";
            }
            {
              condition = "or";
              conditions = [
                {
                  condition = "state";
                  entity_id = "binary_sensor.outdoor_requires_heating";
                  state = "on";
                }
                {
                  condition = "state";
                  entity_id = "binary_sensor.outdoor_requires_cooling";
                  state = "on";
                }
              ];
            }
            {
              condition = "template";
              value_template = ''
                {% set outdoor = state_attr('weather.forecast_home', 'temperature') | float(15) %}
                {% set indoor = state_attr('climate.ac_sala', 'current_temperature') | float(20) %}
                {{ (outdoor < 15 and indoor < 20) or (outdoor > 25 and indoor > 23) }}
              '';
            }
          ];
          action = [
            {
              action = "climate.set_hvac_mode";
              target.entity_id = "climate.ac_sala";
              data.hvac_mode = "{{ states('sensor.smart_hvac_mode') }}";
            }
            { delay.seconds = 2; }
            {
              action = "climate.set_temperature";
              target.entity_id = "climate.ac_sala";
              data.temperature = 22;
            }
            {
              action = "rest_command.ntfy_notify";
              data = {
                title = "Welcome Home";
                message = "Evening return - sala AC on to 22°C (was {{ state_attr('climate.ac_sala', 'current_temperature') }}°C)";
              };
            }
          ];
        }

        # 7. Seasonal Mode - Heat/Cool Auto Switch
        {
          id = "seasonal_mode_switch";
          alias = "Seasonal Mode - Heat/Cool Auto Switch";
          description = "Use cooling when outside is warm, heating when cold";
          mode = "single";
          trigger = [{
            platform = "state";
            entity_id = [
              "climate.ac_escritorio"
              "climate.ac_sala"
              "climate.ac_quarto"
              "climate.ac_quarto_hospedes"
            ];
          }];
          condition = [{
            condition = "template";
            value_template = "{{ trigger.to_state.state not in ['off', 'unavailable', 'unknown'] }}";
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
                    value_template = "{{ trigger.to_state.state == 'heat' }}";
                  }
                ];
                sequence = [
                  {
                    action = "climate.set_hvac_mode";
                    target.entity_id = "{{ trigger.entity_id }}";
                    data.hvac_mode = "cool";
                  }
                  {
                    action = "rest_command.ntfy_notify";
                    data = {
                      title = "Seasonal Mode Switch";
                      message = "{{ trigger.to_state.attributes.friendly_name }} switched from heat to cool (outdoor >22°C)";
                    };
                  }
                ];
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
                    value_template = "{{ trigger.to_state.state == 'cool' }}";
                  }
                ];
                sequence = [
                  {
                    action = "climate.set_hvac_mode";
                    target.entity_id = "{{ trigger.entity_id }}";
                    data.hvac_mode = "heat";
                  }
                  {
                    action = "rest_command.ntfy_notify";
                    data = {
                      title = "Seasonal Mode Switch";
                      message = "{{ trigger.to_state.attributes.friendly_name }} switched from cool to heat (outdoor <18°C)";
                    };
                  }
                ];
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
            action = "rest_command.ntfy_notify";
            data = {
              title = "Low Temperature Alert";
              message = "{{ trigger.to_state.attributes.friendly_name }} is at {{ trigger.to_state.attributes.current_temperature }}°C";
            };
          }];
        }

        # 9. Weekly Summary (Sunday 9 AM) - Enhanced
        {
          id = "weekly_summary";
          alias = "Weekly Summary";
          description = "Send comprehensive weekly summary every Sunday at 9 AM";
          trigger = [{ platform = "time"; at = "09:00:00"; }];
          condition = [{ condition = "time"; weekday = ["sun"]; }];
          action = [{
            action = "rest_command.ntfy_notify";
            data = {
              title = "Weekly Summary";
              message = ''
                Active AC: {{ states('sensor.active_ac_units') }}
                Weather: {{ state_attr('weather.forecast_home', 'temperature') }}°C, {{ states('weather.forecast_home') }}
                Recovery: {{ states('sensor.recovery_score') if has_value('sensor.recovery_score') else 'N/A' }}% ({{ states('sensor.training_readiness') if has_value('sensor.training_readiness') else 'N/A' }})
                Resting HR: {{ states('sensor.garmin_connect_resting_heart_rate') if has_value('sensor.garmin_connect_resting_heart_rate') else 'N/A' }} bpm
                Sleep Score: {{ states('sensor.garmin_connect_sleep_score') if has_value('sensor.garmin_connect_sleep_score') else 'N/A' }}
                Body Battery: {{ states('sensor.garmin_connect_body_battery_most_recent') if has_value('sensor.garmin_connect_body_battery_most_recent') else 'N/A' }}
                Steps: {{ states('sensor.garmin_connect_total_steps') if has_value('sensor.garmin_connect_total_steps') else 'N/A' }}
                CPU: {{ states('sensor.system_monitor_processor_use') if has_value('sensor.system_monitor_processor_use') else 'N/A' }}%
                Memory: {{ states('sensor.system_monitor_memory_usage') if has_value('sensor.system_monitor_memory_usage') else 'N/A' }}%
                Disk: {{ states('sensor.system_monitor_disk_usage') if has_value('sensor.system_monitor_disk_usage') else 'N/A' }}%
                Speedtest DL: {{ states('sensor.speedtest_download') if has_value('sensor.speedtest_download') else 'N/A' }} Mbps
              '';
            };
          }];
        }

        # 10. Workday Start Comfort - Pre-heat office before work
        {
          id = "workday_start_comfort";
          alias = "Workday Start Comfort";
          description = "Turn on office AC at 8:45 on weekdays if room needs conditioning and weather warrants it";
          trigger = [{
            platform = "time";
            at = "08:45:00";
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
            {
              condition = "or";
              conditions = [
                {
                  condition = "state";
                  entity_id = "binary_sensor.outdoor_requires_heating";
                  state = "on";
                }
                {
                  condition = "state";
                  entity_id = "binary_sensor.outdoor_requires_cooling";
                  state = "on";
                }
              ];
            }
            {
              condition = "template";
              value_template = ''
                {% set outdoor = state_attr('weather.forecast_home', 'temperature') | float(15) %}
                {% set indoor = state_attr('climate.ac_escritorio', 'current_temperature') | float(20) %}
                {{ (outdoor < 15 and indoor < 20) or (outdoor > 25 and indoor > 23) }}
              '';
            }
          ];
          action = [
            {
              action = "climate.set_hvac_mode";
              target.entity_id = "climate.ac_escritorio";
              data.hvac_mode = "{{ states('sensor.smart_hvac_mode') }}";
            }
            { delay.seconds = 2; }
            {
              action = "climate.set_temperature";
              target.entity_id = "climate.ac_escritorio";
              data.temperature = 22;
            }
            {
              action = "rest_command.ntfy_notify";
              data = {
                title = "Workday Start";
                message = "Office AC on to 22°C (indoor {{ state_attr('climate.ac_escritorio', 'current_temperature') }}°C, outdoor {{ state_attr('weather.forecast_home', 'temperature') }}°C)";
              };
            }
          ];
        }

        # 11. Weekend Morning Comfort - Later start on weekends
        {
          id = "weekend_morning_comfort";
          alias = "Weekend Morning Comfort";
          description = "Turn on living room AC at 10:00 on weekends if weather warrants it";
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
              condition = "or";
              conditions = [
                {
                  condition = "state";
                  entity_id = "binary_sensor.outdoor_requires_heating";
                  state = "on";
                }
                {
                  condition = "state";
                  entity_id = "binary_sensor.outdoor_requires_cooling";
                  state = "on";
                }
              ];
            }
            {
              condition = "template";
              value_template = ''
                {% set outdoor = state_attr('weather.forecast_home', 'temperature') | float(15) %}
                {% set indoor = state_attr('climate.ac_sala', 'current_temperature') | float(20) %}
                {{ (outdoor < 15 and indoor < 20) or (outdoor > 25 and indoor > 23) }}
              '';
            }
          ];
          action = [
            {
              action = "climate.set_hvac_mode";
              target.entity_id = "climate.ac_sala";
              data.hvac_mode = "{{ states('sensor.smart_hvac_mode') }}";
            }
            { delay.seconds = 2; }
            {
              action = "climate.set_temperature";
              target.entity_id = "climate.ac_sala";
              data.temperature = 22;
            }
            {
              action = "rest_command.ntfy_notify";
              data = {
                title = "Weekend Morning";
                message = "Weekend - sala AC on to 22°C (indoor {{ state_attr('climate.ac_sala', 'current_temperature') }}°C, outdoor {{ state_attr('weather.forecast_home', 'temperature') }}°C)";
              };
            }
          ];
        }

        # 14. Night Bedroom Prep - Pre-heat bedroom before bedtime
        {
          id = "night_bedroom_prep";
          alias = "Night Bedroom Prep";
          description = "Pre-heat bedroom 30 minutes before bedtime if cold outside and room is chilly";
          trigger = [{
            platform = "time";
            at = "23:00:00";
          }];
          condition = [
            {
              condition = "state";
              entity_id = "person.armando";
              state = "home";
            }
            {
              condition = "state";
              entity_id = "binary_sensor.outdoor_requires_heating";
              state = "on";
            }
            {
              condition = "numeric_state";
              entity_id = "climate.ac_quarto";
              attribute = "current_temperature";
              below = 19;
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
              data.temperature = 20;
            }
            {
              action = "rest_command.ntfy_notify";
              data = {
                title = "Bedroom Prep";
                message = "Pre-heating bedroom to 20°C for 30 minutes (was {{ state_attr('climate.ac_quarto', 'current_temperature') }}°C)";
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
              action = "rest_command.ntfy_notify";
              data = {
                title = "Cold Weather Alert";
                message = "Outside temp dropped below 10°C - consider using multiple AC units";
              };
            }
          ];
        }

        # ─────────────────────────────────────────────────────────────
        # Climate-Aware Automations
        # ─────────────────────────────────────────────────────────────

        # 16. TV On - Condition Living Room
        {
          id = "tv_on_heat_sala";
          alias = "TV On - Heat Living Room";
          description = "Condition living room when LG TV turns on if weather warrants it";
          trigger = [{
            platform = "state";
            entity_id = "media_player.lg_webos_tv_75nano826qb";
            to = "on";
          }];
          condition = [
            {
              condition = "time";
              after = "18:00:00";
              before = "23:30:00";
            }
            {
              condition = "state";
              entity_id = "climate.ac_sala";
              state = "off";
            }
            {
              condition = "or";
              conditions = [
                {
                  condition = "state";
                  entity_id = "binary_sensor.outdoor_requires_heating";
                  state = "on";
                }
                {
                  condition = "state";
                  entity_id = "binary_sensor.outdoor_requires_cooling";
                  state = "on";
                }
              ];
            }
            {
              condition = "template";
              value_template = ''
                {% set outdoor = state_attr('weather.forecast_home', 'temperature') | float(15) %}
                {% set indoor = state_attr('climate.ac_sala', 'current_temperature') | float(20) %}
                {{ (outdoor < 15 and indoor < 20) or (outdoor > 25 and indoor > 23) }}
              '';
            }
          ];
          action = [
            {
              action = "climate.set_hvac_mode";
              target.entity_id = "climate.ac_sala";
              data.hvac_mode = "{{ states('sensor.smart_hvac_mode') }}";
            }
            { delay.seconds = 2; }
            {
              action = "climate.set_temperature";
              target.entity_id = "climate.ac_sala";
              data.temperature = 22;
            }
            {
              action = "rest_command.ntfy_notify";
              data = {
                title = "TV On - Climate";
                message = "TV on - sala AC on to 22°C (indoor {{ state_attr('climate.ac_sala', 'current_temperature') }}°C, outdoor {{ state_attr('weather.forecast_home', 'temperature') }}°C)";
              };
            }
          ];
        }

        # 17. TV Off Late Night - Shutdown & Bedroom Prep
        {
          id = "tv_off_late_night_shutdown";
          alias = "TV Off Late Night Shutdown";
          description = "Turn off sala AC and pre-heat bedroom when TV turns off late";
          trigger = [{
            platform = "state";
            entity_id = "media_player.lg_webos_tv_75nano826qb";
            from = "on";
            to = "off";
          }];
          condition = [{
            condition = "time";
            after = "23:00:00";
            before = "02:00:00";
          }];
          action = [
            {
              action = "climate.turn_off";
              target.entity_id = "climate.ac_sala";
            }
            {
              choose = [{
                conditions = [
                  {
                    condition = "state";
                    entity_id = "binary_sensor.outdoor_requires_heating";
                    state = "on";
                  }
                  {
                    condition = "numeric_state";
                    entity_id = "climate.ac_quarto";
                    attribute = "current_temperature";
                    below = 19;
                  }
                ];
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
                    data.temperature = 20;
                  }
                  {
                    action = "rest_command.ntfy_notify";
                    data = {
                      title = "TV Off - Bedtime";
                      message = "TV off - sala AC off, pre-heating bedroom to 20°C for 25 min";
                    };
                  }
                  { delay.minutes = 25; }
                  {
                    action = "climate.turn_off";
                    target.entity_id = "climate.ac_quarto";
                  }
                ];
              }];
              default = [{
                action = "rest_command.ntfy_notify";
                data = {
                  title = "TV Off - Bedtime";
                  message = "TV off - sala AC off, bedroom warm enough ({{ state_attr('climate.ac_quarto', 'current_temperature') }}°C)";
                };
              }];
            }
          ];
        }

        # ─────────────────────────────────────────────────────────────
        # Notification Automations
        # ─────────────────────────────────────────────────────────────

        # 18. Cooking Done Notification
        {
          id = "cooking_done_notification";
          alias = "Cooking Done Notification";
          description = "Notify when Meater probe reaches done status";
          trigger = [{
            platform = "state";
            entity_id = "sensor.meater_probe_3415f6c7_cook_state";
            to = "done";
          }];
          action = [
            {
              action = "rest_command.ntfy_notify";
              data = {
                title = "Cooking Done";
                message = "Your meat is ready! Meater probe has reached target temperature.";
              };
            }
            {
              action = "webostv.command";
              target.entity_id = "media_player.lg_webos_tv_75nano826qb";
              data.command = "system.notifications/createToast";
              data.payload.message = "Cooking done! Meat is ready.";
            }
          ];
        }

        # 19. Slow Network Alert
        {
          id = "slow_network_alert";
          alias = "Slow Network Alert";
          description = "Alert when speedtest download drops below 50 Mbps";
          trigger = [{
            platform = "numeric_state";
            entity_id = "sensor.speedtest_download";
            below = 50;
          }];
          mode = "single";
          action = [
            {
              action = "rest_command.ntfy_notify";
              data = {
                title = "Slow Network Alert";
                message = "Download speed: {{ states('sensor.speedtest_download') }} Mbps (below 50 Mbps threshold)";
              };
            }
            { delay.hours = 1; }
          ];
        }

        # 20. New Media Downloaded
        {
          id = "new_media_downloaded";
          alias = "New Media Downloaded";
          description = "Notify when Sonarr or Radarr finishes downloading";
          trigger = [
            {
              platform = "state";
              entity_id = "sensor.sonarr_queue";
            }
            {
              platform = "state";
              entity_id = "sensor.radarr_queue";
            }
          ];
          condition = [{
            condition = "template";
            value_template = "{{ trigger.from_state.state | int(0) > trigger.to_state.state | int(0) }}";
          }];
          action = [{
            action = "rest_command.ntfy_notify";
            data = {
              title = "New Media Ready";
              message = "New content downloaded and ready to watch on Jellyfin!";
            };
          }];
        }

        # ─────────────────────────────────────────────────────────────
        # Calendar-Driven Automations
        # ─────────────────────────────────────────────────────────────

        # 22. Calendar Meeting Pre-Heat
        {
          id = "calendar_meeting_preheat";
          alias = "Calendar Meeting Pre-Heat";
          description = "Pre-heat office 15 minutes before calendar events if weather warrants it";
          trigger = [{
            platform = "calendar";
            event = "start";
            entity_id = "calendar.armando_well_typed_com";
            offset = "-00:15:00";
          }];
          condition = [
            {
              condition = "time";
              after = "07:00:00";
              before = "10:00:00";
              weekday = ["mon" "tue" "wed" "thu" "fri"];
            }
            {
              condition = "state";
              entity_id = "person.armando";
              state = "home";
            }
            {
              condition = "state";
              entity_id = "climate.ac_escritorio";
              state = "off";
            }
            {
              condition = "or";
              conditions = [
                {
                  condition = "state";
                  entity_id = "binary_sensor.outdoor_requires_heating";
                  state = "on";
                }
                {
                  condition = "state";
                  entity_id = "binary_sensor.outdoor_requires_cooling";
                  state = "on";
                }
              ];
            }
            {
              condition = "template";
              value_template = ''
                {% set outdoor = state_attr('weather.forecast_home', 'temperature') | float(15) %}
                {% set indoor = state_attr('climate.ac_escritorio', 'current_temperature') | float(20) %}
                {{ (outdoor < 15 and indoor < 20) or (outdoor > 25 and indoor > 23) }}
              '';
            }
          ];
          action = [
            {
              action = "climate.set_hvac_mode";
              target.entity_id = "climate.ac_escritorio";
              data.hvac_mode = "{{ states('sensor.smart_hvac_mode') }}";
            }
            { delay.seconds = 2; }
            {
              action = "climate.set_temperature";
              target.entity_id = "climate.ac_escritorio";
              data.temperature = 22;
            }
            {
              action = "rest_command.ntfy_notify";
              data = {
                title = "Meeting Prep";
                message = "Meeting in 15 min - office AC on to 22°C (was {{ state_attr('climate.ac_escritorio', 'current_temperature') }}°C)";
              };
            }
          ];
        }

        # ─────────────────────────────────────────────────────────────
        # Garmin Health & Training Automations
        # Entity names: garmin_connect_* prefix
        # ─────────────────────────────────────────────────────────────

        # 24. Garmin Daily Health Briefing
        {
          id = "garmin_daily_summary";
          alias = "Garmin Daily Summary";
          description = "Morning health and recovery briefing with training readiness";
          trigger = [{ platform = "time"; at = "08:00:00"; }];
          action = [{
            action = "rest_command.ntfy_notify";
            data = {
              title = "Daily Health Briefing";
              message = ''
                Recovery: {{ states('sensor.recovery_score') if has_value('sensor.recovery_score') else 'N/A' }}% ({{ states('sensor.training_readiness') if has_value('sensor.training_readiness') else 'N/A' }})
                Body Battery: {{ states('sensor.garmin_connect_body_battery_most_recent') if has_value('sensor.garmin_connect_body_battery_most_recent') else 'N/A' }}
                Sleep Score: {{ states('sensor.garmin_connect_sleep_score') if has_value('sensor.garmin_connect_sleep_score') else 'N/A' }}
                Resting HR: {{ states('sensor.garmin_connect_resting_heart_rate') if has_value('sensor.garmin_connect_resting_heart_rate') else 'N/A' }} bpm
                Stress: {{ states('sensor.garmin_connect_avg_stress_level') if has_value('sensor.garmin_connect_avg_stress_level') else 'N/A' }}
                Steps (yesterday): {{ states('sensor.garmin_connect_total_steps') if has_value('sensor.garmin_connect_total_steps') else 'N/A' }}
              '';
            };
          }];
        }

        # 25. Post-Workout Summary
        {
          id = "post_workout_notification";
          alias = "Post-Workout Summary";
          description = "Notify when Garmin detects a completed workout (e.g. Strength)";
          trigger = [{
            platform = "state";
            entity_id = "sensor.garmin_connect_last_activity";
          }];
          condition = [{
            condition = "template";
            value_template = "{{ trigger.from_state.state != trigger.to_state.state and trigger.to_state.state not in ['unknown', 'unavailable', ''] }}";
          }];
          action = [{
            action = "rest_command.ntfy_notify";
            data = {
              title = "Workout Complete";
              message = ''
                Activity: {{ states('sensor.garmin_connect_last_activity') }}
                Body Battery: {{ states('sensor.garmin_connect_body_battery_most_recent') if has_value('sensor.garmin_connect_body_battery_most_recent') else 'N/A' }}
                Recovery: {{ states('sensor.recovery_score') if has_value('sensor.recovery_score') else 'N/A' }}%
              '';
            };
          }];
        }

        # 26. Low Recovery Alert
        {
          id = "low_recovery_alert";
          alias = "Low Recovery Alert";
          description = "Morning alert when body battery or sleep score is critically low";
          trigger = [{ platform = "time"; at = "07:00:00"; }];
          condition = [{
            condition = "or";
            conditions = [
              {
                condition = "numeric_state";
                entity_id = "sensor.garmin_connect_body_battery_most_recent";
                below = 30;
              }
              {
                condition = "numeric_state";
                entity_id = "sensor.garmin_connect_sleep_score";
                below = 50;
              }
            ];
          }];
          action = [{
            action = "rest_command.ntfy_notify";
            data = {
              title = "Low Recovery - Consider Rest Day";
              message = ''
                Body Battery: {{ states('sensor.garmin_connect_body_battery_most_recent') if has_value('sensor.garmin_connect_body_battery_most_recent') else 'N/A' }}
                Sleep Score: {{ states('sensor.garmin_connect_sleep_score') if has_value('sensor.garmin_connect_sleep_score') else 'N/A' }}
                Recovery Score: {{ states('sensor.recovery_score') if has_value('sensor.recovery_score') else 'N/A' }}%
                Consider a rest day or light session only.
              '';
            };
          }];
        }

        # 27. Resting HR Elevation Alert (overtraining indicator)
        {
          id = "resting_hr_elevation_alert";
          alias = "Resting HR Elevation Alert";
          description = "Warn when resting HR is elevated above baseline - early overtraining sign";
          trigger = [{
            platform = "numeric_state";
            entity_id = "sensor.garmin_connect_resting_heart_rate";
            # Adjust this threshold to ~10% above your normal resting HR
            above = 65;
          }];
          condition = [{
            condition = "time";
            after = "06:00:00";
            before = "10:00:00";
          }];
          action = [{
            action = "rest_command.ntfy_notify";
            data = {
              title = "Elevated Resting HR";
              message = "Resting HR: {{ states('sensor.garmin_connect_resting_heart_rate') }} bpm (above baseline). Possible sign of under-recovery. Consider lighter training today.";
            };
          }];
        }

        # ─────────────────────────────────────────────────────────────
        # System Monitoring
        # ─────────────────────────────────────────────────────────────

        # 32. High CPU/Memory Alert
        {
          id = "high_cpu_memory_alert";
          alias = "High CPU/Memory Usage Alert";
          description = "Alert when CPU or memory usage exceeds 90% for 10 minutes";
          trigger = [
            {
              platform = "numeric_state";
              entity_id = "sensor.system_monitor_processor_use";
              above = 90;
              "for".minutes = 10;
            }
            {
              platform = "numeric_state";
              entity_id = "sensor.system_monitor_memory_usage";
              above = 90;
              "for".minutes = 10;
            }
          ];
          mode = "single";
          action = [
            {
              action = "rest_command.ntfy_notify";
              data = {
                title = "System Resource Alert";
                message = "{{ trigger.to_state.attributes.friendly_name }}: {{ trigger.to_state.state }}% (above 90% for 10+ min)";
              };
            }
            { delay.hours = 1; }
          ];
        }

        # ─────────────────────────────────────────────────────────────
        # Google Sheets Logging Automations
        # Note: Requires Google Sheets OAuth setup. Fill in config_entry
        # ID after completing the integration setup via HA UI.
        # The google_sheets.append_sheet service only becomes available
        # AFTER you complete: Settings > Integrations > Google Sheets.
        # ─────────────────────────────────────────────────────────────

        # 29. Hourly Temperature Log
        {
          id = "sheets_hourly_temperature_log";
          alias = "Sheets - Hourly Temperature Log";
          description = "Log temperatures from all rooms and outdoor to Google Sheets every hour";
          trigger = [{ platform = "time_pattern"; hours = "/1"; }];
          action = [{
            action = "google_sheets.append_sheet";
            data = {
              config_entry = "01KGDDV8MK8T4HRXT4GCGNBE6Z";
              data = {
                Timestamp = "{{ now().isoformat() }}";
                Outdoor = "{{ state_attr('weather.forecast_home', 'temperature') }}";
                Sala = "{{ state_attr('climate.ac_sala', 'current_temperature') }}";
                Escritorio = "{{ state_attr('climate.ac_escritorio', 'current_temperature') }}";
                Quarto = "{{ state_attr('climate.ac_quarto', 'current_temperature') }}";
                Hospedes = "{{ state_attr('climate.ac_quarto_hospedes', 'current_temperature') }}";
                AC_Sala_Mode = "{{ states('climate.ac_sala') }}";
                AC_Escritorio_Mode = "{{ states('climate.ac_escritorio') }}";
                AC_Quarto_Mode = "{{ states('climate.ac_quarto') }}";
                AC_Hospedes_Mode = "{{ states('climate.ac_quarto_hospedes') }}";
              };
            };
          }];
        }

        # 30. Daily AC Runtime Log
        {
          id = "sheets_daily_ac_runtime";
          alias = "Sheets - Daily AC Runtime";
          description = "Log daily AC runtime hours to Google Sheets at midnight";
          trigger = [{ platform = "time"; at = "00:00:01"; }];
          action = [{
            action = "google_sheets.append_sheet";
            data = {
              config_entry = "01KGDDV8MK8T4HRXT4GCGNBE6Z";
              data = {
                Date = "{{ (now() - timedelta(days=1)).strftime('%Y-%m-%d') }}";
                Outdoor_Temp = "{{ state_attr('weather.forecast_home', 'temperature') }}";
                Sala_Hours = "{{ states('sensor.ac_sala_runtime_today') }}";
                Escritorio_Hours = "{{ states('sensor.ac_escritorio_runtime_today') }}";
                Quarto_Hours = "{{ states('sensor.ac_quarto_runtime_today') }}";
                Hospedes_Hours = "{{ states('sensor.ac_quarto_hospedes_runtime_today') }}";
              };
            };
          }];
        }

        # 31. Daily Garmin Health & Training Log
        {
          id = "sheets_daily_garmin_log";
          alias = "Sheets - Daily Garmin Log";
          description = "Log daily Garmin health, sleep, and training metrics to Google Sheets at 11 PM";
          trigger = [{ platform = "time"; at = "23:00:00"; }];
          action = [{
            action = "google_sheets.append_sheet";
            data = {
              config_entry = "01KGDDV8MK8T4HRXT4GCGNBE6Z";
              data = {
                Date = "{{ now().strftime('%Y-%m-%d') }}";
                Recovery_Score = "{{ states('sensor.recovery_score') if has_value('sensor.recovery_score') else '' }}";
                Training_Readiness = "{{ states('sensor.training_readiness') if has_value('sensor.training_readiness') else '' }}";
                Body_Battery = "{{ states('sensor.garmin_connect_body_battery_most_recent') if has_value('sensor.garmin_connect_body_battery_most_recent') else '' }}";
                Resting_HR = "{{ states('sensor.garmin_connect_resting_heart_rate') if has_value('sensor.garmin_connect_resting_heart_rate') else '' }}";
                Sleep_Score = "{{ states('sensor.garmin_connect_sleep_score') if has_value('sensor.garmin_connect_sleep_score') else '' }}";
                Stress = "{{ states('sensor.garmin_connect_avg_stress_level') if has_value('sensor.garmin_connect_avg_stress_level') else '' }}";
                Steps = "{{ states('sensor.garmin_connect_total_steps') if has_value('sensor.garmin_connect_total_steps') else '' }}";
                Calories = "{{ states('sensor.garmin_connect_total_kilocalories') if has_value('sensor.garmin_connect_total_kilocalories') else '' }}";
                Active_Calories = "{{ states('sensor.garmin_connect_active_kilocalories') if has_value('sensor.garmin_connect_active_kilocalories') else '' }}";
                Intensity_Minutes = "{{ states('sensor.garmin_connect_active_time') if has_value('sensor.garmin_connect_active_time') else '' }}";
                Last_Activity = "{{ states('sensor.garmin_connect_last_activity') if has_value('sensor.garmin_connect_last_activity') else '' }}";
              };
            };
          }];
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
      # Data & Logging
      # ─────────────────────────────────────────────────────────────
      "google_sheets"          # Google Sheets (OAuth setup required post-deploy)
      "history_stats"          # History-based statistics sensors

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
    ] ++ (with pkgs.unstable.home-assistant-custom-components; [
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
        # ═══════════════════════════════════════════════════════════════
        # VIEW 1: HOME
        # ═══════════════════════════════════════════════════════════════
        {
          type = "sections";
          title = "Home";
          icon = "mdi:home";
          path = "home";
          max_columns = 4;
          badges = [
            { entity = "person.armando"; }
            { entity = "sun.sun"; }
          ];
          sections = [
            # ── Navigation Overlay (position: fixed) ──
            {
              type = "grid";
              cards = [
                {
                  type = "custom:bubble-card";
                  card_type = "horizontal-buttons-stack";
                  auto_order = false;
                  "1_link" = "/lovelace/home";
                  "1_icon" = "mdi:home";
                  "1_name" = "Home";
                  "2_link" = "/lovelace/climate";
                  "2_icon" = "mdi:thermostat";
                  "2_name" = "Climate";
                  "3_link" = "/lovelace/health";
                  "3_icon" = "mdi:heart-pulse";
                  "3_name" = "Health";
                  "4_link" = "/lovelace/media";
                  "4_icon" = "mdi:play-circle";
                  "4_name" = "Media";
                  "5_link" = "/lovelace/services";
                  "5_icon" = "mdi:apps";
                  "5_name" = "Services";
                  "6_link" = "/lovelace/system";
                  "6_icon" = "mdi:server";
                  "6_name" = "System";
                  "7_link" = "/lovelace/settings";
                  "7_icon" = "mdi:cog";
                  "7_name" = "Settings";
                  styles = ''
                    .horizontal-buttons-stack-container {
                      background: rgba(var(--rgb-card-background-color), 0.9) !important;
                      backdrop-filter: blur(10px);
                      border-radius: 24px 24px 0 0;
                    }
                  '';
                }
              ];
            }
            # ── Welcome ──
            {
              type = "grid";
              title = "Welcome";
              cards = [
                {
                  type = "custom:button-card";
                  entity = "sensor.time_of_day";
                  name = "[[[ return 'Good ' + entity.state + ', Armando' ]]]";
                  layout_options = { grid_columns = 4; grid_rows = 1; };
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
                {
                  type = "custom:mushroom-chips-card";
                  alignment = "center";
                  layout_options = { grid_columns = 4; grid_rows = 1; };
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
                      type = "template";
                      icon = "mdi:thermostat-auto";
                      content = "{{ states('sensor.smart_hvac_mode') | title }}";
                      icon_color = "{% if states('sensor.smart_hvac_mode') == 'cool' %}blue{% else %}orange{% endif %}";
                    }
                    {
                      type = "weather";
                      entity = "weather.forecast_home";
                      show_conditions = true;
                      show_temperature = true;
                    }
                    {
                      type = "template";
                      icon = "mdi:heart-pulse";
                      content = "{{ states('sensor.recovery_score') }}%";
                      icon_color = "{% set s = states('sensor.recovery_score')|int(0) %}{% if s >= 70 %}green{% elif s >= 50 %}amber{% else %}red{% endif %}";
                    }
                    {
                      type = "entity";
                      entity = "sensor.prado_travel_distance_from_braga";
                      icon = "mdi:car";
                    }
                  ];
                }
              ];
            }
            # ── At a Glance ──
            {
              type = "grid";
              title = "At a Glance";
              cards = [
                {
                  type = "weather-forecast";
                  entity = "weather.forecast_home";
                  show_forecast = true;
                  forecast_type = "daily";
                  layout_options = { grid_columns = 2; grid_rows = 2; };
                }
                {
                  type = "custom:button-card";
                  entity = "sensor.time_of_day";
                  name = "[[[ const h = new Date().getHours(); const d = new Date().getDay(); if (h >= 8 && h < 18 && d >= 1 && d <= 5) return 'Office'; if (h >= 23 || h < 8) return 'Bedroom'; return 'Living Room'; ]]]";
                  label = "[[[ const h = new Date().getHours(); const d = new Date().getDay(); if (h >= 8 && h < 18 && d >= 1 && d <= 5) return states['climate.ac_escritorio'].attributes.current_temperature + '°C'; if (h >= 23 || h < 8) return states['climate.ac_quarto'].attributes.current_temperature + '°C'; return states['climate.ac_sala'].attributes.current_temperature + '°C'; ]]]";
                  show_label = true;
                  icon = "[[[ const h = new Date().getHours(); const d = new Date().getDay(); if (h >= 8 && h < 18 && d >= 1 && d <= 5) return 'mdi:desk'; if (h >= 23 || h < 8) return 'mdi:bed'; return 'mdi:sofa'; ]]]";
                  layout_options = { grid_columns = 2; grid_rows = 2; };
                  styles = {
                    card = [
                      { "background" = "rgba(var(--rgb-primary-color), 0.1)"; }
                      { "border-radius" = "12px"; }
                      { "padding" = "16px"; }
                    ];
                    label = [
                      { "font-size" = "28px"; }
                      { "font-weight" = "bold"; }
                    ];
                  };
                }
              ];
            }
            # ── Quick Actions ──
            {
              type = "grid";
              title = "Quick Actions";
              cards = [
                {
                  type = "custom:mushroom-chips-card";
                  alignment = "center";
                  layout_options = { grid_columns = 4; grid_rows = 1; };
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
                      icon = "mdi:home-export-outline";
                      icon_color = "green";
                      content = "Away Mode";
                      tap_action = {
                        action = "call-service";
                        service = "automation.trigger";
                        service_data = { entity_id = "automation.away_mode_all_ac_off"; };
                      };
                    }
                  ];
                }
              ];
            }
            # ── Schedule ──
            {
              type = "grid";
              title = "Schedule";
              cards = [
                {
                  type = "calendar";
                  entities = [
                    "calendar.armando_well_typed_com"
                    "calendar.armandoifsantos_gmail_com"
                    "calendar.birthdays"
                    "calendar.holidays_in_portugal"
                  ];
                  layout_options = { grid_columns = 4; grid_rows = 3; };
                }
              ];
            }
            # ── Now Playing ──
            {
              type = "grid";
              title = "Now Playing";
              cards = [
                {
                  type = "custom:auto-entities";
                  card = {
                    type = "entities";
                  };
                  filter = {
                    include = [
                      { domain = "media_player"; state = "playing"; }
                      { domain = "media_player"; state = "paused"; }
                    ];
                  };
                  sort.method = "state";
                  show_empty = false;
                  layout_options = { grid_columns = 4; grid_rows = 2; };
                }
              ];
            }
            # ── Health Summary ──
            {
              type = "grid";
              title = "Health Summary";
              cards = [
                {
                  type = "gauge";
                  entity = "sensor.recovery_score";
                  name = "Recovery";
                  min = 0;
                  max = 100;
                  severity = { green = 70; yellow = 50; red = 0; };
                  layout_options = { grid_columns = 2; grid_rows = 2; };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "sensor.training_readiness";
                  name = "Training";
                  icon = "mdi:dumbbell";
                  layout_options = { grid_columns = 2; grid_rows = 1; };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "sensor.garmin_connect_body_battery_most_recent";
                  name = "Body Battery";
                  icon = "mdi:battery-heart-variant";
                  layout_options = { grid_columns = 2; grid_rows = 1; };
                }
              ];
            }
          ];
        }

        # ═══════════════════════════════════════════════════════════════
        # VIEW 2: CLIMATE (includes merged Energy analytics)
        # ═══════════════════════════════════════════════════════════════
        {
          type = "sections";
          title = "Climate";
          icon = "mdi:thermostat";
          path = "climate";
          max_columns = 4;
          sections = [
            # ── Status ──
            {
              type = "grid";
              title = "Status";
              cards = [
                {
                  type = "custom:mushroom-chips-card";
                  alignment = "center";
                  layout_options = { grid_columns = 4; grid_rows = 1; };
                  chips = [
                    {
                      type = "template";
                      icon = "mdi:air-conditioner";
                      content = "{{ states('sensor.active_ac_units') }} Active";
                      icon_color = "{% if states('sensor.active_ac_units')|int > 0 %}blue{% else %}grey{% endif %}";
                    }
                    {
                      type = "template";
                      icon = "mdi:thermostat-auto";
                      content = "{{ states('sensor.smart_hvac_mode') | title }} Mode";
                      icon_color = "{% if states('sensor.smart_hvac_mode') == 'cool' %}blue{% else %}orange{% endif %}";
                    }
                    {
                      type = "weather";
                      entity = "weather.forecast_home";
                      show_conditions = true;
                      show_temperature = true;
                    }
                  ];
                }
                {
                  type = "custom:mushroom-chips-card";
                  alignment = "center";
                  layout_options = { grid_columns = 4; grid_rows = 1; };
                  chips = [
                    {
                      type = "entity";
                      entity = "sensor.ac_sala_outside_temperature";
                      icon = "mdi:thermometer";
                      name = "Sala Out";
                    }
                    {
                      type = "entity";
                      entity = "sensor.ac_escritorio_outside_temperature";
                      icon = "mdi:thermometer";
                      name = "Office Out";
                    }
                    {
                      type = "entity";
                      entity = "sensor.ac_quarto_outside_temperature";
                      icon = "mdi:thermometer";
                      name = "Bedroom Out";
                    }
                    {
                      type = "entity";
                      entity = "sensor.ac_quarto_hospedes_outside_temperature";
                      icon = "mdi:thermometer";
                      name = "Guest Out";
                    }
                  ];
                }
                {
                  type = "custom:mushroom-chips-card";
                  alignment = "center";
                  layout_options = { grid_columns = 4; grid_rows = 1; };
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
                      content = "Cool All 22°C";
                      icon_color = "blue";
                      tap_action = {
                        action = "call-service";
                        service = "climate.set_temperature";
                        service_data = {
                          entity_id = [ "climate.ac_sala" "climate.ac_escritorio" "climate.ac_quarto" "climate.ac_quarto_hospedes" ];
                          temperature = 22;
                          hvac_mode = "cool";
                        };
                      };
                    }
                    {
                      type = "template";
                      icon = "mdi:fire";
                      content = "Heat All 24°C";
                      icon_color = "orange";
                      tap_action = {
                        action = "call-service";
                        service = "climate.set_temperature";
                        service_data = {
                          entity_id = [ "climate.ac_sala" "climate.ac_escritorio" "climate.ac_quarto" "climate.ac_quarto_hospedes" ];
                          temperature = 24;
                          hvac_mode = "heat";
                        };
                      };
                    }
                  ];
                }
              ];
            }
            # ── Thermostats ──
            {
              type = "grid";
              title = "Thermostats";
              cards = [
                {
                  type = "thermostat";
                  entity = "climate.ac_sala";
                  name = "Sala (Living Room)";
                  layout_options = { grid_columns = 2; grid_rows = 3; };
                  features = [
                    { type = "climate-hvac-modes"; hvac_modes = [ "off" "cool" "heat" "fan_only" "auto" ]; }
                    { type = "climate-fan-modes"; }
                  ];
                }
                {
                  type = "thermostat";
                  entity = "climate.ac_escritorio";
                  name = "Escritório (Office)";
                  layout_options = { grid_columns = 2; grid_rows = 3; };
                  features = [
                    { type = "climate-hvac-modes"; hvac_modes = [ "off" "cool" "heat" "fan_only" "auto" ]; }
                    { type = "climate-fan-modes"; }
                  ];
                }
                {
                  type = "vertical-stack";
                  layout_options = { grid_columns = 2; grid_rows = 3; };
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
                {
                  type = "vertical-stack";
                  layout_options = { grid_columns = 2; grid_rows = 3; };
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
              ];
            }
            # ── Room Conditions ──
            {
              type = "grid";
              title = "Room Conditions";
              cards = [
                {
                  type = "conditional";
                  conditions = [{
                    condition = "numeric_state";
                    entity = "sensor.active_ac_units";
                    above = 0;
                  }];
                  card = {
                    type = "glance";
                    title = "Room Humidity";
                    entities = [
                      { entity = "sensor.ac_sala_room_humidity"; name = "Sala"; }
                      { entity = "sensor.ac_escritorio_room_humidity"; name = "Escritório"; }
                      { entity = "sensor.ac_quarto_room_humidity"; name = "Quarto"; }
                      { entity = "sensor.ac_quarto_hospedes_room_humidity"; name = "Hóspedes"; }
                    ];
                  };
                }
                {
                  type = "glance";
                  title = "Current AC Modes";
                  layout_options = { grid_columns = 4; grid_rows = 1; };
                  entities = [
                    { entity = "climate.ac_sala"; name = "Sala"; }
                    { entity = "climate.ac_escritorio"; name = "Escritório"; }
                    { entity = "climate.ac_quarto"; name = "Quarto"; }
                    { entity = "climate.ac_quarto_hospedes"; name = "Hóspedes"; }
                  ];
                }
              ];
            }
            # ── Temperature History ──
            {
              type = "grid";
              title = "Temperature History";
              cards = [
                {
                  type = "custom:apexcharts-card";
                  header = { title = "Temperature History (24h)"; show = true; };
                  graph_span = "24h";
                  span.end = "now";
                  layout_options = { grid_columns = 4; grid_rows = 3; };
                  yaxis = [{ min = 14; max = 32; }];
                  series = [
                    {
                      entity = "climate.ac_sala";
                      attribute = "current_temperature";
                      name = "Sala";
                      color = "#FF9800";
                      stroke_width = 2;
                      curve = "smooth";
                    }
                    {
                      entity = "climate.ac_escritorio";
                      attribute = "current_temperature";
                      name = "Escritório";
                      color = "#2196F3";
                      stroke_width = 2;
                      curve = "smooth";
                    }
                    {
                      entity = "climate.ac_quarto";
                      attribute = "current_temperature";
                      name = "Quarto";
                      color = "#9C27B0";
                      stroke_width = 2;
                      curve = "smooth";
                    }
                    {
                      entity = "climate.ac_quarto_hospedes";
                      attribute = "current_temperature";
                      name = "Hóspedes";
                      color = "#4CAF50";
                      stroke_width = 2;
                      curve = "smooth";
                    }
                    {
                      entity = "weather.forecast_home";
                      attribute = "temperature";
                      name = "Outdoor";
                      color = "#78909C";
                      stroke_width = 1;
                      curve = "smooth";
                      opacity = 0.5;
                    }
                  ];
                }
                {
                  type = "custom:apexcharts-card";
                  header = { title = "Temperature Comparison (48h)"; show = true; };
                  graph_span = "48h";
                  span.end = "now";
                  layout_options = { grid_columns = 4; grid_rows = 3; };
                  yaxis = [{ min = 14; max = 32; }];
                  series = [
                    {
                      entity = "climate.ac_sala";
                      attribute = "current_temperature";
                      name = "Sala";
                      color = "#FF9800";
                      stroke_width = 2;
                      curve = "smooth";
                    }
                    {
                      entity = "climate.ac_escritorio";
                      attribute = "current_temperature";
                      name = "Escritório";
                      color = "#2196F3";
                      stroke_width = 2;
                      curve = "smooth";
                    }
                    {
                      entity = "climate.ac_quarto";
                      attribute = "current_temperature";
                      name = "Quarto";
                      color = "#9C27B0";
                      stroke_width = 2;
                      curve = "smooth";
                    }
                    {
                      entity = "climate.ac_quarto_hospedes";
                      attribute = "current_temperature";
                      name = "Hóspedes";
                      color = "#4CAF50";
                      stroke_width = 2;
                      curve = "smooth";
                    }
                    {
                      entity = "weather.forecast_home";
                      attribute = "temperature";
                      name = "Outdoor";
                      color = "#78909C";
                      stroke_width = 1;
                      curve = "smooth";
                      opacity = 0.5;
                    }
                  ];
                }
              ];
            }
            # ── AC Runtime & Efficiency ──
            {
              type = "grid";
              title = "AC Runtime & Efficiency";
              cards = [
                {
                  type = "custom:apexcharts-card";
                  header = { title = "AC Runtime Today"; show = true; };
                  chart_type = "bar";
                  layout = "horizontal";
                  layout_options = { grid_columns = 2; grid_rows = 2; };
                  series = [
                    { entity = "sensor.ac_sala_runtime_today"; name = "Sala"; color = "#FF9800"; }
                    { entity = "sensor.ac_escritorio_runtime_today"; name = "Escritório"; color = "#2196F3"; }
                    { entity = "sensor.ac_quarto_runtime_today"; name = "Quarto"; color = "#9C27B0"; }
                    { entity = "sensor.ac_quarto_hospedes_runtime_today"; name = "Hóspedes"; color = "#4CAF50"; }
                  ];
                }
                {
                  type = "custom:apexcharts-card";
                  header = { title = "AC Runtime (7 days)"; show = true; };
                  graph_span = "7d";
                  span.end = "now";
                  chart_type = "area";
                  stacked = true;
                  layout_options = { grid_columns = 2; grid_rows = 2; };
                  series = [
                    {
                      entity = "sensor.ac_sala_runtime_today";
                      name = "Sala";
                      color = "#FF9800";
                      stroke_width = 1;
                      curve = "smooth";
                      opacity = 0.5;
                      group_by = { func = "max"; duration = "1d"; };
                    }
                    {
                      entity = "sensor.ac_escritorio_runtime_today";
                      name = "Escritório";
                      color = "#2196F3";
                      stroke_width = 1;
                      curve = "smooth";
                      opacity = 0.5;
                      group_by = { func = "max"; duration = "1d"; };
                    }
                    {
                      entity = "sensor.ac_quarto_runtime_today";
                      name = "Quarto";
                      color = "#9C27B0";
                      stroke_width = 1;
                      curve = "smooth";
                      opacity = 0.5;
                      group_by = { func = "max"; duration = "1d"; };
                    }
                    {
                      entity = "sensor.ac_quarto_hospedes_runtime_today";
                      name = "Hóspedes";
                      color = "#4CAF50";
                      stroke_width = 1;
                      curve = "smooth";
                      opacity = 0.5;
                      group_by = { func = "max"; duration = "1d"; };
                    }
                  ];
                }
                {
                  type = "conditional";
                  conditions = [{
                    condition = "numeric_state";
                    entity = "sensor.active_ac_units";
                    above = 0;
                  }];
                  card = {
                    type = "custom:apexcharts-card";
                    header = { title = "Humidity Comparison (24h)"; show = true; };
                    graph_span = "24h";
                    span.end = "now";
                    series = [
                      { entity = "sensor.ac_sala_room_humidity"; name = "Sala"; color = "#FF9800"; stroke_width = 2; curve = "smooth"; }
                      { entity = "sensor.ac_escritorio_room_humidity"; name = "Escritório"; color = "#2196F3"; stroke_width = 2; curve = "smooth"; }
                      { entity = "sensor.ac_quarto_room_humidity"; name = "Quarto"; color = "#9C27B0"; stroke_width = 2; curve = "smooth"; }
                      { entity = "sensor.ac_quarto_hospedes_room_humidity"; name = "Hóspedes"; color = "#4CAF50"; stroke_width = 2; curve = "smooth"; }
                    ];
                  };
                }
              ];
            }
            # ── Automations ──
            {
              type = "grid";
              title = "Automations";
              cards = [
                {
                  type = "custom:mushroom-chips-card";
                  alignment = "center";
                  layout_options = { grid_columns = 4; grid_rows = 1; };
                  chips = [
                    {
                      type = "entity";
                      entity = "automation.workday_start_comfort";
                      icon = "mdi:weather-sunset-up";
                      name = "Workday";
                      tap_action = { action = "toggle"; };
                    }
                    {
                      type = "entity";
                      entity = "automation.night_shutdown_all_ac";
                      icon = "mdi:weather-night";
                      name = "Night Off";
                      tap_action = { action = "toggle"; };
                    }
                    {
                      type = "entity";
                      entity = "automation.away_mode_all_ac_off";
                      icon = "mdi:home-export-outline";
                      name = "Away";
                      tap_action = { action = "toggle"; };
                    }
                    {
                      type = "entity";
                      entity = "automation.seasonal_mode_heat_cool_auto_switch";
                      icon = "mdi:sun-snowflake-variant";
                      name = "Seasonal";
                      tap_action = { action = "toggle"; };
                    }
                  ];
                }
              ];
            }
          ];
        }

        # ═══════════════════════════════════════════════════════════════
        # VIEW 3: HEALTH & TRAINING
        # ═══════════════════════════════════════════════════════════════
        {
          type = "sections";
          title = "Health";
          icon = "mdi:heart-pulse";
          path = "health";
          max_columns = 4;
          sections = [
            # ── Overview ──
            {
              type = "grid";
              title = "Overview";
              cards = [
                {
                  type = "custom:mushroom-chips-card";
                  alignment = "center";
                  layout_options = { grid_columns = 4; grid_rows = 1; };
                  chips = [
                    {
                      type = "template";
                      icon = "mdi:dumbbell";
                      content = "{{ states('sensor.training_readiness') }}";
                      icon_color = "{% set s = states('sensor.training_readiness') %}{% if s == 'Ready' %}green{% elif s == 'Moderate' %}amber{% else %}red{% endif %}";
                    }
                    {
                      type = "entity";
                      entity = "sensor.garmin_connect_hrv_status";
                      icon = "mdi:heart-flash";
                    }
                    {
                      type = "entity";
                      entity = "sensor.garmin_connect_fitness_age";
                      icon = "mdi:human";
                    }
                  ];
                }
                {
                  type = "gauge";
                  entity = "sensor.recovery_score";
                  name = "Recovery Score";
                  min = 0;
                  max = 100;
                  severity = { green = 70; yellow = 50; red = 0; };
                  layout_options = { grid_columns = 2; grid_rows = 2; };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "sensor.garmin_connect_last_activity";
                  name = "Last Activity";
                  icon = "mdi:run";
                  layout_options = { grid_columns = 2; grid_rows = 2; };
                }
              ];
            }
            # ── Today's Metrics ──
            {
              type = "grid";
              title = "Today's Metrics";
              cards = [
                {
                  type = "custom:mushroom-entity-card";
                  entity = "sensor.garmin_connect_body_battery_most_recent";
                  name = "Body Battery";
                  icon = "mdi:battery-heart-variant";
                  layout_options = { grid_columns = 2; grid_rows = 1; };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "sensor.garmin_connect_resting_heart_rate";
                  name = "Resting HR";
                  icon = "mdi:heart-pulse";
                  layout_options = { grid_columns = 2; grid_rows = 1; };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "sensor.garmin_connect_sleep_score";
                  name = "Sleep Score";
                  icon = "mdi:sleep";
                  layout_options = { grid_columns = 2; grid_rows = 1; };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "sensor.garmin_connect_avg_stress_level";
                  name = "Avg Stress";
                  icon = "mdi:head-snowflake";
                  layout_options = { grid_columns = 2; grid_rows = 1; };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "sensor.garmin_connect_total_steps";
                  name = "Steps";
                  icon = "mdi:shoe-print";
                  layout_options = { grid_columns = 2; grid_rows = 1; };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "sensor.garmin_connect_active_kilocalories";
                  name = "Active Cal";
                  icon = "mdi:fire";
                  layout_options = { grid_columns = 2; grid_rows = 1; };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "sensor.garmin_connect_total_distance_mtr";
                  name = "Distance";
                  icon = "mdi:map-marker-distance";
                  layout_options = { grid_columns = 2; grid_rows = 1; };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "sensor.garmin_connect_floors_ascended";
                  name = "Floors";
                  icon = "mdi:stairs-up";
                  layout_options = { grid_columns = 2; grid_rows = 1; };
                }
              ];
            }
            # ── Trends ──
            {
              type = "grid";
              title = "Trends";
              cards = [
                {
                  type = "custom:apexcharts-card";
                  header = { title = "Body Battery (24h)"; show = true; };
                  graph_span = "24h";
                  span.end = "now";
                  layout_options = { grid_columns = 4; grid_rows = 3; };
                  series = [{
                    entity = "sensor.garmin_connect_body_battery_most_recent";
                    name = "Body Battery";
                    color = "#4CAF50";
                    stroke_width = 2;
                    curve = "smooth";
                    type = "area";
                    opacity = 0.2;
                  }];
                  yaxis = [{ min = 0; max = 100; }];
                }
                {
                  type = "custom:apexcharts-card";
                  header = { title = "Resting Heart Rate (7 days)"; show = true; };
                  graph_span = "7d";
                  span.end = "now";
                  layout_options = { grid_columns = 2; grid_rows = 3; };
                  series = [{
                    entity = "sensor.garmin_connect_resting_heart_rate";
                    name = "Resting HR";
                    color = "#E53935";
                    stroke_width = 2;
                    curve = "smooth";
                  }];
                }
                {
                  type = "custom:apexcharts-card";
                  header = { title = "Sleep Score (7 days)"; show = true; };
                  graph_span = "7d";
                  span.end = "now";
                  layout_options = { grid_columns = 2; grid_rows = 3; };
                  series = [{
                    entity = "sensor.garmin_connect_sleep_score";
                    name = "Sleep Score";
                    color = "#7E57C2";
                    stroke_width = 2;
                    curve = "smooth";
                    type = "area";
                    opacity = 0.15;
                  }];
                  yaxis = [{ min = 0; max = 100; }];
                }
              ];
            }
            # ── Stress ──
            {
              type = "grid";
              title = "Stress";
              cards = [
                {
                  type = "custom:mushroom-chips-card";
                  alignment = "center";
                  layout_options = { grid_columns = 4; grid_rows = 1; };
                  chips = [
                    {
                      type = "entity";
                      entity = "sensor.garmin_connect_high_stress_duration";
                      icon = "mdi:alert-circle";
                    }
                    {
                      type = "entity";
                      entity = "sensor.garmin_connect_medium_stress_duration";
                      icon = "mdi:alert";
                    }
                    {
                      type = "entity";
                      entity = "sensor.garmin_connect_low_stress_duration";
                      icon = "mdi:check-circle";
                    }
                    {
                      type = "entity";
                      entity = "sensor.garmin_connect_rest_stress_duration";
                      icon = "mdi:sleep";
                    }
                  ];
                }
              ];
            }
          ];
        }

        # ═══════════════════════════════════════════════════════════════
        # VIEW 4: MEDIA
        # ═══════════════════════════════════════════════════════════════
        {
          type = "sections";
          title = "Media";
          icon = "mdi:play-circle";
          path = "media";
          max_columns = 4;
          sections = [
            # ── Living Room TV ──
            {
              type = "grid";
              title = "Living Room TV";
              cards = [
                {
                  type = "custom:mushroom-media-player-card";
                  entity = "media_player.lg_webos_tv_75nano826qb";
                  name = "LG TV";
                  icon = "mdi:television";
                  use_media_info = true;
                  show_volume_level = true;
                  media_controls = [ "on_off" "play_pause_stop" ];
                  volume_controls = [ "volume_buttons" "volume_mute" ];
                  layout_options = { grid_columns = 2; grid_rows = 2; };
                }
                {
                  type = "custom:lg-webos-remote-control";
                  entity = "media_player.lg_webos_tv_75nano826qb";
                  layout_options = { grid_columns = 2; grid_rows = 4; };
                }
              ];
            }
            # ── Now Playing ──
            {
              type = "grid";
              title = "Now Playing";
              cards = [
                {
                  type = "custom:auto-entities";
                  card = {
                    type = "entities";
                    title = "Jellyfin Sessions";
                  };
                  filter = {
                    include = [
                      { domain = "media_player"; integration = "jellyfin"; }
                    ];
                    exclude = [
                      { state = "unavailable"; }
                    ];
                  };
                  sort.method = "state";
                  show_empty = false;
                  layout_options = { grid_columns = 2; grid_rows = 2; };
                }
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
                  sort.method = "state";
                  show_empty = false;
                  layout_options = { grid_columns = 2; grid_rows = 2; };
                }
              ];
            }
            # ── Library ──
            {
              type = "grid";
              title = "Library";
              cards = [
                {
                  type = "custom:mushroom-entity-card";
                  entity = "sensor.radarr_films";
                  name = "Films";
                  icon = "mdi:movie";
                  layout_options = { grid_columns = 1; grid_rows = 1; };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "sensor.sonarr_shows";
                  name = "Shows";
                  icon = "mdi:television-classic";
                  layout_options = { grid_columns = 1; grid_rows = 1; };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "sensor.nixos_ninho_active_clients";
                  name = "Active";
                  icon = "mdi:account-group";
                  layout_options = { grid_columns = 1; grid_rows = 1; };
                }
                {
                  type = "custom:mushroom-chips-card";
                  alignment = "center";
                  layout_options = { grid_columns = 1; grid_rows = 1; };
                  chips = [
                    {
                      type = "entity";
                      entity = "sensor.sonarr_queue";
                      icon = "mdi:television-classic";
                    }
                    {
                      type = "entity";
                      entity = "sensor.radarr_queue";
                      icon = "mdi:movie";
                    }
                  ];
                }
              ];
            }
            # ── Cooking ──
            {
              type = "grid";
              title = "Cooking";
              cards = [
                {
                  type = "conditional";
                  conditions = [
                    {
                      condition = "state";
                      entity = "sensor.meater_probe_3415f6c7_cook_state";
                      state_not = "idle";
                    }
                    {
                      condition = "state";
                      entity = "sensor.meater_probe_3415f6c7_cook_state";
                      state_not = "unavailable";
                    }
                  ];
                  card = {
                    type = "glance";
                    title = "Meater Probe";
                    entities = [
                      { entity = "sensor.meater_probe_3415f6c7_internal_temperature"; name = "Internal"; }
                      { entity = "sensor.meater_probe_3415f6c7_target_temperature"; name = "Target"; }
                      { entity = "sensor.meater_probe_3415f6c7_ambient_temperature"; name = "Ambient"; }
                      { entity = "sensor.meater_probe_3415f6c7_time_remaining"; name = "Time Left"; }
                    ];
                    card_mod.style = "ha-card { border: 2px solid #FF5722; }";
                  };
                }
              ];
            }
            # ── Quick Links ──
            {
              type = "grid";
              title = "Quick Links";
              cards = [
                {
                  type = "custom:mushroom-template-card";
                  primary = "Jellyfin";
                  secondary = "Media Server";
                  icon = "mdi:play-box-multiple";
                  icon_color = "purple";
                  layout_options = { grid_columns = 1; grid_rows = 1; };
                  tap_action = { action = "url"; url_path = "http://10.100.0.100:8096"; };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Navidrome";
                  secondary = "Music";
                  icon = "mdi:music";
                  icon_color = "green";
                  layout_options = { grid_columns = 1; grid_rows = 1; };
                  tap_action = { action = "url"; url_path = "http://10.100.0.100:8105"; };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Jellyseerr";
                  secondary = "Requests";
                  icon = "mdi:movie-search";
                  icon_color = "amber";
                  layout_options = { grid_columns = 1; grid_rows = 1; };
                  tap_action = { action = "url"; url_path = "http://10.100.0.100:8200"; };
                }
              ];
            }
          ];
        }

        # ═══════════════════════════════════════════════════════════════
        # VIEW 5: SERVICES
        # ═══════════════════════════════════════════════════════════════
        {
          type = "sections";
          title = "Services";
          icon = "mdi:apps";
          path = "services";
          max_columns = 4;
          sections = [
            # ── Media ──
            {
              type = "grid";
              title = "Media";
              cards = [
                {
                  type = "custom:mushroom-template-card";
                  primary = "Jellyfin";
                  secondary = "Media Server";
                  icon = "mdi:play-box-multiple";
                  icon_color = "purple";
                  layout_options = { grid_columns = 1; grid_rows = 1; };
                  tap_action = { action = "url"; url_path = "http://10.100.0.100:8096"; };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Navidrome";
                  secondary = "Music";
                  icon = "mdi:music";
                  icon_color = "green";
                  layout_options = { grid_columns = 1; grid_rows = 1; };
                  tap_action = { action = "url"; url_path = "http://10.100.0.100:8105"; };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Jellyseerr";
                  secondary = "Requests";
                  icon = "mdi:movie-search";
                  icon_color = "amber";
                  layout_options = { grid_columns = 1; grid_rows = 1; };
                  tap_action = { action = "url"; url_path = "http://10.100.0.100:8200"; };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Kavita";
                  secondary = "Books";
                  icon = "mdi:book-open-page-variant";
                  icon_color = "teal";
                  layout_options = { grid_columns = 1; grid_rows = 1; };
                  tap_action = { action = "url"; url_path = "http://10.100.0.100:8110"; };
                }
              ];
            }
            # ── Downloads ──
            {
              type = "grid";
              title = "Downloads";
              cards = [
                {
                  type = "custom:mushroom-template-card";
                  primary = "Sonarr";
                  secondary = "TV Shows";
                  icon = "mdi:television-classic";
                  icon_color = "blue";
                  layout_options = { grid_columns = 1; grid_rows = 1; };
                  tap_action = { action = "url"; url_path = "http://10.100.0.100:8099"; };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Radarr";
                  secondary = "Movies";
                  icon = "mdi:movie";
                  icon_color = "amber";
                  layout_options = { grid_columns = 1; grid_rows = 1; };
                  tap_action = { action = "url"; url_path = "http://10.100.0.100:8098"; };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Lidarr";
                  secondary = "Music";
                  icon = "mdi:music-note";
                  icon_color = "green";
                  layout_options = { grid_columns = 1; grid_rows = 1; };
                  tap_action = { action = "url"; url_path = "http://10.100.0.100:8100"; };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Readarr";
                  secondary = "Books";
                  icon = "mdi:book";
                  icon_color = "brown";
                  layout_options = { grid_columns = 1; grid_rows = 1; };
                  tap_action = { action = "url"; url_path = "http://10.100.0.100:8101"; };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Prowlarr";
                  secondary = "Indexers";
                  icon = "mdi:magnify";
                  icon_color = "orange";
                  layout_options = { grid_columns = 1; grid_rows = 1; };
                  tap_action = { action = "url"; url_path = "http://10.100.0.100:8097"; };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Bazarr";
                  secondary = "Subtitles";
                  icon = "mdi:subtitles";
                  icon_color = "grey";
                  layout_options = { grid_columns = 1; grid_rows = 1; };
                  tap_action = { action = "url"; url_path = "http://10.100.0.100:8112"; };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Deluge";
                  secondary = "Torrents";
                  icon = "mdi:download";
                  icon_color = "blue";
                  layout_options = { grid_columns = 1; grid_rows = 1; };
                  tap_action = { action = "url"; url_path = "http://10.100.0.100:8103"; };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Bitmagnet";
                  secondary = "DHT Indexer";
                  icon = "mdi:magnet";
                  icon_color = "red";
                  layout_options = { grid_columns = 1; grid_rows = 1; };
                  tap_action = { action = "url"; url_path = "http://10.100.0.100:3333"; };
                }
              ];
            }
            # ── Cloud & Files ──
            {
              type = "grid";
              title = "Cloud & Files";
              cards = [
                {
                  type = "custom:mushroom-template-card";
                  primary = "Nextcloud";
                  secondary = "Files";
                  icon = "mdi:cloud";
                  icon_color = "blue";
                  layout_options = { grid_columns = 1; grid_rows = 1; };
                  tap_action = { action = "url"; url_path = "http://10.100.0.100:8081"; };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Syncthing";
                  secondary = "Sync";
                  icon = "mdi:sync";
                  icon_color = "cyan";
                  layout_options = { grid_columns = 1; grid_rows = 1; };
                  tap_action = { action = "url"; url_path = "http://10.100.0.100:8384"; };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "FileBrowser";
                  secondary = "Web Files";
                  icon = "mdi:folder";
                  icon_color = "orange";
                  layout_options = { grid_columns = 1; grid_rows = 1; };
                  tap_action = { action = "url"; url_path = "http://10.100.0.100:8107"; };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Immich";
                  secondary = "Photos";
                  icon = "mdi:image-multiple";
                  icon_color = "indigo";
                  layout_options = { grid_columns = 1; grid_rows = 1; };
                  tap_action = { action = "url"; url_path = "http://10.100.0.100:2283"; };
                }
              ];
            }
            # ── AI & Tools ──
            {
              type = "grid";
              title = "AI & Tools";
              cards = [
                {
                  type = "custom:mushroom-template-card";
                  primary = "llama-swap";
                  secondary = "LLM API";
                  icon = "mdi:brain";
                  icon_color = "yellow";
                  layout_options = { grid_columns = 1; grid_rows = 1; };
                  tap_action = { action = "url"; url_path = "http://10.100.0.100:8080"; };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "ComfyUI";
                  secondary = "Image Gen";
                  icon = "mdi:image-auto-adjust";
                  icon_color = "pink";
                  layout_options = { grid_columns = 1; grid_rows = 1; };
                  tap_action = { action = "url"; url_path = "http://10.100.0.100:8188"; };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Memos";
                  secondary = "Notes";
                  icon = "mdi:note-text";
                  icon_color = "teal";
                  layout_options = { grid_columns = 1; grid_rows = 1; };
                  tap_action = { action = "url"; url_path = "http://10.100.0.100:8111"; };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Miniflux";
                  secondary = "RSS Reader";
                  icon = "mdi:rss";
                  icon_color = "orange";
                  layout_options = { grid_columns = 1; grid_rows = 1; };
                  tap_action = { action = "url"; url_path = "http://10.100.0.100:8104"; };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Emanote";
                  secondary = "Zettelkasten";
                  icon = "mdi:notebook";
                  icon_color = "green";
                  layout_options = { grid_columns = 1; grid_rows = 1; };
                  tap_action = { action = "url"; url_path = "http://10.100.0.100:7000"; };
                }
              ];
            }
            # ── Monitoring ──
            {
              type = "grid";
              title = "Monitoring";
              cards = [
                {
                  type = "custom:mushroom-template-card";
                  primary = "Grafana";
                  secondary = "Metrics";
                  icon = "mdi:chart-areaspline";
                  icon_color = "orange";
                  layout_options = { grid_columns = 1; grid_rows = 1; };
                  tap_action = { action = "url"; url_path = "http://10.100.0.100:3000"; };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Uptime Kuma";
                  secondary = "Status";
                  icon = "mdi:heart-pulse";
                  icon_color = "green";
                  layout_options = { grid_columns = 1; grid_rows = 1; };
                  tap_action = { action = "url"; url_path = "http://10.100.0.100:8109"; };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Ntfy";
                  secondary = "Notifications";
                  icon = "mdi:bell";
                  icon_color = "red";
                  layout_options = { grid_columns = 1; grid_rows = 1; };
                  tap_action = { action = "url"; url_path = "http://10.100.0.100:8106"; };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Homepage";
                  secondary = "Dashboard";
                  icon = "mdi:view-dashboard";
                  icon_color = "grey";
                  layout_options = { grid_columns = 1; grid_rows = 1; };
                  tap_action = { action = "url"; url_path = "http://10.100.0.100:8082"; };
                }
              ];
            }
          ];
        }

        # ═══════════════════════════════════════════════════════════════
        # VIEW 6: SYSTEM
        # ═══════════════════════════════════════════════════════════════
        {
          type = "sections";
          title = "System";
          icon = "mdi:server";
          path = "system";
          max_columns = 4;
          sections = [
            # ── Server Status ──
            {
              type = "grid";
              title = "Server Status";
              cards = [
                {
                  type = "custom:mushroom-chips-card";
                  alignment = "center";
                  layout_options = { grid_columns = 4; grid_rows = 1; };
                  chips = [{
                    type = "entity";
                    entity = "sensor.uptime";
                    icon = "mdi:clock-check";
                  }];
                }
                {
                  type = "gauge";
                  entity = "sensor.cpu_usage";
                  name = "CPU";
                  min = 0;
                  max = 100;
                  severity = { green = 0; yellow = 70; red = 90; };
                  layout_options = { grid_columns = 1; grid_rows = 2; };
                }
                {
                  type = "gauge";
                  entity = "sensor.memory_usage";
                  name = "Memory";
                  min = 0;
                  max = 100;
                  severity = { green = 0; yellow = 70; red = 90; };
                  layout_options = { grid_columns = 1; grid_rows = 2; };
                }
                {
                  type = "gauge";
                  entity = "sensor.system_monitor_processor_temperature";
                  name = "CPU Temp";
                  min = 20;
                  max = 100;
                  severity = { green = 20; yellow = 70; red = 85; };
                  layout_options = { grid_columns = 1; grid_rows = 2; };
                }
                {
                  type = "gauge";
                  entity = "sensor.disk_usage";
                  name = "Root Disk";
                  min = 0;
                  max = 100;
                  severity = { green = 0; yellow = 70; red = 90; };
                  layout_options = { grid_columns = 1; grid_rows = 2; };
                }
                {
                  type = "gauge";
                  entity = "sensor.storage_usage";
                  name = "Storage";
                  min = 0;
                  max = 100;
                  severity = { green = 0; yellow = 70; red = 90; };
                  layout_options = { grid_columns = 4; grid_rows = 2; };
                }
              ];
            }
            # ── Performance ──
            {
              type = "grid";
              title = "Performance";
              cards = [
                {
                  type = "custom:apexcharts-card";
                  header = { title = "System Load (24h)"; show = true; };
                  graph_span = "24h";
                  span.end = "now";
                  layout_options = { grid_columns = 2; grid_rows = 3; };
                  series = [
                    {
                      entity = "sensor.system_monitor_load_1_min";
                      name = "1 min";
                      color = "#4CAF50";
                      stroke_width = 2;
                      curve = "smooth";
                    }
                    {
                      entity = "sensor.system_monitor_load_5_min";
                      name = "5 min";
                      color = "#FF9800";
                      stroke_width = 2;
                      curve = "smooth";
                    }
                    {
                      entity = "sensor.system_monitor_load_15_min";
                      name = "15 min";
                      color = "#F44336";
                      stroke_width = 2;
                      curve = "smooth";
                    }
                  ];
                }
                {
                  type = "custom:apexcharts-card";
                  header = { title = "CPU Usage (24h)"; show = true; };
                  graph_span = "24h";
                  span.end = "now";
                  layout_options = { grid_columns = 2; grid_rows = 3; };
                  series = [{
                    entity = "sensor.system_monitor_processor_use";
                    name = "CPU";
                    color = "#2196F3";
                    stroke_width = 2;
                    curve = "smooth";
                    type = "area";
                    opacity = 0.2;
                  }];
                  yaxis = [{ min = 0; max = 100; }];
                }
              ];
            }
            # ── Network ──
            {
              type = "grid";
              title = "Network";
              cards = [
                {
                  type = "glance";
                  title = "Network Speed";
                  layout_options = { grid_columns = 4; grid_rows = 1; };
                  entities = [
                    { entity = "sensor.speedtest_download"; name = "Download"; icon = "mdi:download"; }
                    { entity = "sensor.speedtest_upload"; name = "Upload"; icon = "mdi:upload"; }
                    { entity = "sensor.speedtest_ping"; name = "Ping"; icon = "mdi:timer-outline"; }
                  ];
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "sensor.system_monitor_network_throughput_in_enp11s0";
                  name = "enp11s0 In";
                  icon = "mdi:arrow-down";
                  layout_options = { grid_columns = 1; grid_rows = 1; };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "sensor.system_monitor_network_throughput_out_enp11s0";
                  name = "enp11s0 Out";
                  icon = "mdi:arrow-up";
                  layout_options = { grid_columns = 1; grid_rows = 1; };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "sensor.system_monitor_network_throughput_in_wg0";
                  name = "WG In";
                  icon = "mdi:arrow-down";
                  layout_options = { grid_columns = 1; grid_rows = 1; };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "sensor.system_monitor_network_throughput_out_wg0";
                  name = "WG Out";
                  icon = "mdi:arrow-up";
                  layout_options = { grid_columns = 1; grid_rows = 1; };
                }
              ];
            }
            # ── Devices ──
            {
              type = "grid";
              title = "Devices";
              cards = [
                {
                  type = "custom:mushroom-entity-card";
                  entity = "vacuum.dreame_de_521213416_p2028";
                  name = "Robot Vacuum";
                  icon = "mdi:robot-vacuum";
                  tap_action = { action = "more-info"; };
                  layout_options = { grid_columns = 2; grid_rows = 1; };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "light.yeelink_de_77086772_color1_s_2_light";
                  name = "Smart Light";
                  icon = "mdi:lightbulb";
                  tap_action = { action = "toggle"; };
                  layout_options = { grid_columns = 2; grid_rows = 1; };
                }
              ];
            }
            # ── Automations ──
            {
              type = "grid";
              title = "Automations";
              cards = [
                {
                  type = "custom:mushroom-entity-card";
                  entity = "automation.workday_start_comfort";
                  name = "Workday Start";
                  icon = "mdi:weather-sunset-up";
                  tap_action = { action = "toggle"; };
                  layout_options = { grid_columns = 2; grid_rows = 1; };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "automation.night_shutdown_all_ac";
                  name = "Night Shutdown";
                  icon = "mdi:weather-night";
                  tap_action = { action = "toggle"; };
                  layout_options = { grid_columns = 2; grid_rows = 1; };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "automation.away_mode_all_ac_off";
                  name = "Away Mode";
                  icon = "mdi:home-export-outline";
                  tap_action = { action = "toggle"; };
                  layout_options = { grid_columns = 2; grid_rows = 1; };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "automation.return_home_smart_pre_heat";
                  name = "Return Home";
                  icon = "mdi:home-import-outline";
                  tap_action = { action = "toggle"; };
                  layout_options = { grid_columns = 2; grid_rows = 1; };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "automation.seasonal_mode_heat_cool_auto_switch";
                  name = "Seasonal Mode";
                  icon = "mdi:sun-snowflake-variant";
                  tap_action = { action = "toggle"; };
                  layout_options = { grid_columns = 2; grid_rows = 1; };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "automation.tv_on_heat_living_room";
                  name = "TV On Heat";
                  icon = "mdi:television";
                  tap_action = { action = "toggle"; };
                  layout_options = { grid_columns = 2; grid_rows = 1; };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "automation.cooking_done_notification";
                  name = "Cooking Alert";
                  icon = "mdi:grill";
                  tap_action = { action = "toggle"; };
                  layout_options = { grid_columns = 2; grid_rows = 1; };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "automation.garmin_daily_summary";
                  name = "Daily Health";
                  icon = "mdi:heart-pulse";
                  tap_action = { action = "toggle"; };
                  layout_options = { grid_columns = 2; grid_rows = 1; };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "automation.weekly_summary";
                  name = "Weekly Summary";
                  icon = "mdi:calendar-week";
                  tap_action = { action = "toggle"; };
                  layout_options = { grid_columns = 2; grid_rows = 1; };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "automation.night_bedroom_prep";
                  name = "Bedroom Prep";
                  icon = "mdi:bed-clock";
                  tap_action = { action = "toggle"; };
                  layout_options = { grid_columns = 2; grid_rows = 1; };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "automation.tv_off_late_night_shutdown";
                  name = "TV Off Late";
                  icon = "mdi:television-off";
                  tap_action = { action = "toggle"; };
                  layout_options = { grid_columns = 2; grid_rows = 1; };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "automation.calendar_meeting_pre_heat";
                  name = "Meeting Pre-Heat";
                  icon = "mdi:calendar-clock";
                  tap_action = { action = "toggle"; };
                  layout_options = { grid_columns = 2; grid_rows = 1; };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "automation.cold_weather_boost";
                  name = "Cold Boost";
                  icon = "mdi:snowflake-alert";
                  tap_action = { action = "toggle"; };
                  layout_options = { grid_columns = 2; grid_rows = 1; };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "automation.weekend_morning_comfort";
                  name = "Weekend Morning";
                  icon = "mdi:coffee";
                  tap_action = { action = "toggle"; };
                  layout_options = { grid_columns = 2; grid_rows = 1; };
                }
              ];
            }
            # ── GitHub ──
            {
              type = "grid";
              title = "GitHub";
              cards = [
                {
                  type = "custom:mushroom-chips-card";
                  alignment = "center";
                  layout_options = { grid_columns = 4; grid_rows = 1; };
                  chips = [
                    {
                      type = "entity";
                      entity = "sensor.bolt12_nixos_stars";
                      icon = "mdi:github";
                    }
                    {
                      type = "entity";
                      entity = "sensor.bolt12_nixos_issues";
                      icon = "mdi:alert-circle-outline";
                    }
                    {
                      type = "entity";
                      entity = "sensor.well_typed_hs_bindgen_stars";
                      icon = "mdi:github";
                    }
                    {
                      type = "entity";
                      entity = "sensor.well_typed_hs_bindgen_issues";
                      icon = "mdi:alert-circle-outline";
                    }
                  ];
                }
              ];
            }
          ];
        }

        # ═══════════════════════════════════════════════════════════════
        # VIEW 7: SETTINGS
        # ═══════════════════════════════════════════════════════════════
        {
          type = "sections";
          title = "Settings";
          icon = "mdi:cog";
          path = "settings";
          max_columns = 4;
          sections = [
            # ── Controls ──
            {
              type = "grid";
              title = "Controls";
              cards = [
                {
                  type = "custom:button-card";
                  name = "Reload Dashboard";
                  icon = "mdi:refresh";
                  layout_options = { grid_columns = 2; grid_rows = 1; };
                  tap_action = {
                    action = "call-service";
                    service = "homeassistant.reload_core_config";
                  };
                }
                {
                  type = "custom:button-card";
                  name = "Restart Home Assistant";
                  icon = "mdi:restart";
                  layout_options = { grid_columns = 2; grid_rows = 1; };
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
            # ── Shopping List ──
            {
              type = "grid";
              title = "Shopping List";
              cards = [
                {
                  type = "shopping-list";
                  layout_options = { grid_columns = 4; grid_rows = 3; };
                }
              ];
            }
            # ── Automation Management ──
            {
              type = "grid";
              title = "Automation Management";
              cards = [
                {
                  type = "custom:auto-entities";
                  card = {
                    type = "entities";
                    title = "All Automations";
                  };
                  filter = {
                    include = [
                      { domain = "automation"; }
                    ];
                  };
                  sort = {
                    method = "friendly_name";
                  };
                  layout_options = { grid_columns = 4; grid_rows = 4; };
                }
              ];
            }
            # ── Updates ──
            {
              type = "grid";
              title = "Updates";
              cards = [
                {
                  type = "custom:auto-entities";
                  card = {
                    type = "entities";
                    title = "Available Updates";
                  };
                  filter = {
                    include = [
                      { domain = "update"; }
                    ];
                  };
                  show_empty = false;
                  layout_options = { grid_columns = 4; grid_rows = 2; };
                }
              ];
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
