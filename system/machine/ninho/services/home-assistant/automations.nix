# Home Assistant automations: triggers, conditions, actions.
# Module-merged into services.home-assistant.config by ./default.nix.
{ ... }:
{
  services.home-assistant.config = {
    automation = [
      # 3. Night Shutdown - All AC Off
      {
        id = "night_shutdown_all_ac";
        alias = "Night Shutdown All AC";
        description = "Turn off all AC at 11:30 PM (bedtime)";
        trigger = [
          {
            platform = "time";
            at = "23:30:00";
          }
        ];
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
        trigger = [
          {
            platform = "state";
            entity_id = "person.armando";
            from = "home";
            to = "not_home";
            "for".minutes = 10;
          }
        ];
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
        trigger = [
          {
            platform = "state";
            entity_id = "person.armando";
            from = "not_home";
            to = "home";
          }
        ];
        condition = [
          {
            condition = "time";
            after = "12:00:00";
            before = "16:00:00";
            weekday = [
              "mon"
              "tue"
              "wed"
              "thu"
              "fri"
            ];
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
        trigger = [
          {
            platform = "state";
            entity_id = "person.armando";
            from = "not_home";
            to = "home";
          }
        ];
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
        trigger = [
          {
            platform = "state";
            entity_id = [
              "climate.ac_escritorio"
              "climate.ac_sala"
              "climate.ac_quarto"
              "climate.ac_quarto_hospedes"
            ];
          }
        ];
        condition = [
          {
            condition = "template";
            value_template = "{{ trigger.to_state.state not in ['off', 'unavailable', 'unknown'] }}";
          }
        ];
        action = [
          {
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
          }
        ];
      }

      # 8. Low Temperature Alert
      {
        id = "low_temperature_alert";
        alias = "Low Temperature Alert";
        description = "Alert when any room drops below 18°C";
        trigger = [
          {
            platform = "numeric_state";
            entity_id = [
              "climate.ac_sala"
              "climate.ac_escritorio"
              "climate.ac_quarto"
            ];
            attribute = "current_temperature";
            below = 18;
            "for".minutes = 10;
          }
        ];
        action = [
          {
            action = "rest_command.ntfy_notify";
            data = {
              title = "Low Temperature Alert";
              message = "{{ trigger.to_state.attributes.friendly_name }} is at {{ trigger.to_state.attributes.current_temperature }}°C";
            };
          }
        ];
      }

      # 9. Weekly Summary (Sunday 9 AM) - Enhanced
      {
        id = "weekly_summary";
        alias = "Weekly Summary";
        description = "Send comprehensive weekly summary every Sunday at 9 AM";
        trigger = [
          {
            platform = "time";
            at = "09:00:00";
          }
        ];
        condition = [
          {
            condition = "time";
            weekday = [ "sun" ];
          }
        ];
        action = [
          {
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
          }
        ];
      }

      # 10. Workday Start Comfort - Pre-heat office before work
      {
        id = "workday_start_comfort";
        alias = "Workday Start Comfort";
        description = "Turn on office AC at 8:45 on weekdays if room needs conditioning and weather warrants it";
        trigger = [
          {
            platform = "time";
            at = "08:45:00";
          }
        ];
        condition = [
          {
            condition = "state";
            entity_id = "person.armando";
            state = "home";
          }
          {
            condition = "time";
            weekday = [
              "mon"
              "tue"
              "wed"
              "thu"
              "fri"
            ];
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
        trigger = [
          {
            platform = "time";
            at = "10:00:00";
          }
        ];
        condition = [
          {
            condition = "state";
            entity_id = "person.armando";
            state = "home";
          }
          {
            condition = "time";
            weekday = [
              "sat"
              "sun"
            ];
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
        trigger = [
          {
            platform = "time";
            at = "23:00:00";
          }
        ];
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
        trigger = [
          {
            platform = "numeric_state";
            entity_id = "weather.forecast_home";
            attribute = "temperature";
            below = 10;
          }
        ];
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
        trigger = [
          {
            platform = "state";
            entity_id = "media_player.lg_webos_tv_75nano826qb";
            to = "on";
          }
        ];
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
        trigger = [
          {
            platform = "state";
            entity_id = "media_player.lg_webos_tv_75nano826qb";
            from = "on";
            to = "off";
          }
        ];
        condition = [
          {
            condition = "time";
            after = "23:00:00";
            before = "02:00:00";
          }
        ];
        action = [
          {
            action = "climate.turn_off";
            target.entity_id = "climate.ac_sala";
          }
          {
            choose = [
              {
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
              }
            ];
            default = [
              {
                action = "rest_command.ntfy_notify";
                data = {
                  title = "TV Off - Bedtime";
                  message = "TV off - sala AC off, bedroom warm enough ({{ state_attr('climate.ac_quarto', 'current_temperature') }}°C)";
                };
              }
            ];
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
        trigger = [
          {
            platform = "state";
            entity_id = "sensor.meater_probe_3415f6c7_cook_state";
            to = "done";
          }
        ];
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
        trigger = [
          {
            platform = "numeric_state";
            entity_id = "sensor.speedtest_download";
            below = 50;
          }
        ];
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
        condition = [
          {
            condition = "template";
            value_template = "{{ trigger.from_state.state | int(0) > trigger.to_state.state | int(0) }}";
          }
        ];
        action = [
          {
            action = "rest_command.ntfy_notify";
            data = {
              title = "New Media Ready";
              message = "New content downloaded and ready to watch on Jellyfin!";
            };
          }
        ];
      }

      # ─────────────────────────────────────────────────────────────
      # Calendar-Driven Automations
      # ─────────────────────────────────────────────────────────────

      # 22. Calendar Meeting Pre-Heat
      {
        id = "calendar_meeting_preheat";
        alias = "Calendar Meeting Pre-Heat";
        description = "Pre-heat office 15 minutes before calendar events if weather warrants it";
        trigger = [
          {
            platform = "calendar";
            event = "start";
            entity_id = "calendar.armando_well_typed_com";
            offset = "-00:15:00";
          }
        ];
        condition = [
          {
            condition = "time";
            after = "07:00:00";
            before = "10:00:00";
            weekday = [
              "mon"
              "tue"
              "wed"
              "thu"
              "fri"
            ];
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
        trigger = [
          {
            platform = "time";
            at = "08:00:00";
          }
        ];
        action = [
          {
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
          }
        ];
      }

      # 25. Post-Workout Summary
      {
        id = "post_workout_notification";
        alias = "Post-Workout Summary";
        description = "Notify when Garmin detects a completed workout (e.g. Strength)";
        trigger = [
          {
            platform = "state";
            entity_id = "sensor.garmin_connect_last_activity";
          }
        ];
        condition = [
          {
            condition = "template";
            value_template = "{{ trigger.from_state.state != trigger.to_state.state and trigger.to_state.state not in ['unknown', 'unavailable', ''] }}";
          }
        ];
        action = [
          {
            action = "rest_command.ntfy_notify";
            data = {
              title = "Workout Complete";
              message = ''
                Activity: {{ states('sensor.garmin_connect_last_activity') }}
                Body Battery: {{ states('sensor.garmin_connect_body_battery_most_recent') if has_value('sensor.garmin_connect_body_battery_most_recent') else 'N/A' }}
                Recovery: {{ states('sensor.recovery_score') if has_value('sensor.recovery_score') else 'N/A' }}%
              '';
            };
          }
        ];
      }

      # 26. Low Recovery Alert
      {
        id = "low_recovery_alert";
        alias = "Low Recovery Alert";
        description = "Morning alert when body battery or sleep score is critically low";
        trigger = [
          {
            platform = "time";
            at = "07:00:00";
          }
        ];
        condition = [
          {
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
          }
        ];
        action = [
          {
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
          }
        ];
      }

      # 27. Resting HR Elevation Alert (overtraining indicator)
      {
        id = "resting_hr_elevation_alert";
        alias = "Resting HR Elevation Alert";
        description = "Warn when resting HR is elevated above baseline - early overtraining sign";
        trigger = [
          {
            platform = "numeric_state";
            entity_id = "sensor.garmin_connect_resting_heart_rate";
            # Adjust this threshold to ~10% above your normal resting HR
            above = 65;
          }
        ];
        condition = [
          {
            condition = "time";
            after = "06:00:00";
            before = "10:00:00";
          }
        ];
        action = [
          {
            action = "rest_command.ntfy_notify";
            data = {
              title = "Elevated Resting HR";
              message = "Resting HR: {{ states('sensor.garmin_connect_resting_heart_rate') }} bpm (above baseline). Possible sign of under-recovery. Consider lighter training today.";
            };
          }
        ];
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
        trigger = [
          {
            platform = "time_pattern";
            hours = "/1";
          }
        ];
        action = [
          {
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
          }
        ];
      }

      # 30. Daily AC Runtime Log
      {
        id = "sheets_daily_ac_runtime";
        alias = "Sheets - Daily AC Runtime";
        description = "Log daily AC runtime hours to Google Sheets at midnight";
        trigger = [
          {
            platform = "time";
            at = "00:00:01";
          }
        ];
        action = [
          {
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
          }
        ];
      }

      # 31. Daily Garmin Health & Training Log
      {
        id = "sheets_daily_garmin_log";
        alias = "Sheets - Daily Garmin Log";
        description = "Log daily Garmin health, sleep, and training metrics to Google Sheets at 11 PM";
        trigger = [
          {
            platform = "time";
            at = "23:00:00";
          }
        ];
        action = [
          {
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
          }
        ];
      }
    ];
  };
}
