# Home Assistant automations.
#
# Zone-mode AC abstraction:
#   policy automation  ──set──▶  input_select.zone_<slug>_mode
#                                          │
#                                          ▼
#                                   applier automation  ──▶  climate.<entity>
#
# Appliers are the sole writers to climate.*. Setpoints live in templates.nix
# as sensor.zone_<slug>_target_temp. input_boolean.ac_automations_enabled is a
# kill-switch: when off, appliers refuse to actuate but policy automations
# still update the input_select so you can see what *would* have happened.
_:
let
  zones = import ./zones.nix;

  mkApplier =
    z:
    let
      climate = "climate.ac_${z.slug}";
      modeSelect = "input_select.zone_${z.slug}_mode";
      target = "sensor.zone_${z.slug}_target_temp";
    in
    {
      id = "zone_${z.slug}_applier";
      alias = "Zone ${z.friendly} - Applier";
      description = "React to ${modeSelect} changes and push the resolved hvac_mode + temperature to the Gree unit. Sole writer to ${climate}.";
      mode = "single";
      trigger = [
        {
          platform = "state";
          entity_id = modeSelect;
        }
      ];
      condition = [
        {
          condition = "state";
          entity_id = "input_boolean.ac_automations_enabled";
          state = "on";
        }
        {
          condition = "template";
          value_template = "{{ states('${climate}') not in ['unavailable', 'unknown'] }}";
        }
      ];
      action = [
        {
          choose = [
            {
              conditions = [
                {
                  condition = "state";
                  entity_id = modeSelect;
                  state = "off";
                }
              ];
              sequence = [
                {
                  action = "climate.turn_off";
                  target.entity_id = climate;
                }
              ];
            }
          ];
          # Idempotency: skip the Gree round-trip if the unit is already in the
          # desired mode / at the desired setpoint. Each Gree call sends a UDP
          # command; avoiding no-op writes preserves the integration's quota.
          default = [
            {
              choose = [
                {
                  conditions = [
                    {
                      condition = "template";
                      value_template = "{{ states('${climate}') != states('sensor.smart_hvac_mode') }}";
                    }
                  ];
                  sequence = [
                    {
                      action = "climate.set_hvac_mode";
                      target.entity_id = climate;
                      data.hvac_mode = "{{ states('sensor.smart_hvac_mode') }}";
                    }
                    { delay.seconds = 2; }
                  ];
                }
              ];
            }
            {
              choose = [
                {
                  conditions = [
                    {
                      condition = "template";
                      value_template = "{{ (state_attr('${climate}', 'temperature') | float(0)) != (states('${target}') | float(0)) }}";
                    }
                  ];
                  sequence = [
                    {
                      action = "climate.set_temperature";
                      target.entity_id = climate;
                      # 20 °C is a safe room-temperature fallback if the target template renders non-numeric.
                      data.temperature = "{{ states('${target}') | float(20) }}";
                    }
                  ];
                }
              ];
            }
          ];
        }
      ];
    };
in
{
  services.home-assistant.config = {
    automation =
      # ─────────────────────────────────────────────────────────────
      # Zone appliers - sole writers to climate.* entities
      # ─────────────────────────────────────────────────────────────
      (map mkApplier zones) ++ [
        # ─────────────────────────────────────────────────────────────
        # Climate policy - schedule
        # ─────────────────────────────────────────────────────────────

        # Night shutdown: all zones off at 23:30.
        {
          id = "night_shutdown_all_ac";
          alias = "Night Shutdown - All Zones Off";
          description = "Set every zone mode to off at 23:30.";
          trigger = [
            {
              platform = "time";
              at = "23:30:00";
            }
          ];
          action = [
            {
              action = "input_select.select_option";
              target.entity_id = map (z: "input_select.zone_${z.slug}_mode") zones;
              data.option = "off";
            }
            {
              action = "input_text.set_value";
              target.entity_id = map (z: "input_text.ac_${z.slug}_last_intent") zones;
              data.value = "{{ now().strftime('%H:%M') }} schedule:night_shutdown → off";
            }
            {
              action = "rest_command.ntfy_notify";
              data = {
                title = "Night Shutdown";
                message = "Bedtime - all zones set to off";
              };
            }
          ];
        }

        # Workday morning: pre-heat office at 08:45 if home and outdoor cold.
        {
          id = "workday_start_escritorio";
          alias = "Workday Start - Escritorio Comfort";
          description = "Set escritorio to comfort at 08:45 weekdays if anyone is home and outdoor conditions warrant it.";
          trigger = [
            {
              platform = "time";
              at = "08:45:00";
            }
          ];
          condition = [
            {
              condition = "state";
              entity_id = "binary_sensor.anyone_home";
              state = "on";
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
              condition = "state";
              entity_id = "binary_sensor.outdoor_needs_conditioning";
              state = "on";
            }
          ];
          action = [
            {
              action = "input_text.set_value";
              target.entity_id = "input_text.ac_escritorio_last_intent";
              data.value = "{{ now().strftime('%H:%M') }} schedule:workday_start → comfort (out={{ state_attr('weather.forecast_home','temperature') }}°C)";
            }
            {
              action = "input_select.select_option";
              target.entity_id = "input_select.zone_escritorio_mode";
              data.option = "comfort";
            }
          ];
        }

        # Weekend morning: condition the living room from 10:00.
        {
          id = "weekend_morning_sala";
          alias = "Weekend Morning - Sala Comfort";
          description = "Set sala to comfort at 10:00 on weekends if anyone is home and outdoor conditions warrant it.";
          trigger = [
            {
              platform = "time";
              at = "10:00:00";
            }
          ];
          condition = [
            {
              condition = "state";
              entity_id = "binary_sensor.anyone_home";
              state = "on";
            }
            {
              condition = "time";
              weekday = [
                "sat"
                "sun"
              ];
            }
            {
              condition = "state";
              entity_id = "binary_sensor.outdoor_needs_conditioning";
              state = "on";
            }
          ];
          action = [
            {
              action = "input_text.set_value";
              target.entity_id = "input_text.ac_sala_last_intent";
              data.value = "{{ now().strftime('%H:%M') }} schedule:weekend_morning → comfort (out={{ state_attr('weather.forecast_home','temperature') }}°C)";
            }
            {
              action = "input_select.select_option";
              target.entity_id = "input_select.zone_sala_mode";
              data.option = "comfort";
            }
          ];
        }

        # ─────────────────────────────────────────────────────────────
        # Climate policy - occupancy
        # ─────────────────────────────────────────────────────────────

        # Away mode: when nobody has been home for 15 minutes, set every zone off.
        # Uses binary_sensor.anyone_home so a single person leaving doesn't shut
        # down the AC for everyone else.
        {
          id = "away_mode_all_zones_off";
          alias = "Away Mode - All Zones Off";
          description = "All zones off when binary_sensor.anyone_home is off for 15 minutes.";
          trigger = [
            {
              platform = "state";
              entity_id = "binary_sensor.anyone_home";
              from = "on";
              to = "off";
              "for".minutes = 15;
            }
          ];
          action = [
            {
              action = "input_select.select_option";
              target.entity_id = map (z: "input_select.zone_${z.slug}_mode") zones;
              data.option = "off";
            }
            {
              action = "input_text.set_value";
              target.entity_id = map (z: "input_text.ac_${z.slug}_last_intent") zones;
              data.value = "{{ now().strftime('%H:%M') }} occupancy:away_mode → off";
            }
            {
              action = "rest_command.ntfy_notify";
              data = {
                message = "Nobody home for 15 min - all zones set to off";
                title = "Away Mode Activated";
              };
            }
          ];
        }

        # Return - afternoon office reheat after lunch/gym.
        {
          id = "return_lunch_escritorio";
          alias = "Return Home - Escritorio Comfort (afternoon)";
          description = "Set escritorio to comfort when person returns 12:00–16:00 weekday.";
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
              condition = "state";
              entity_id = "binary_sensor.outdoor_needs_conditioning";
              state = "on";
            }
          ];
          action = [
            {
              action = "input_text.set_value";
              target.entity_id = "input_text.ac_escritorio_last_intent";
              data.value = "{{ now().strftime('%H:%M') }} occupancy:return_lunch → comfort";
            }
            {
              action = "input_select.select_option";
              target.entity_id = "input_select.zone_escritorio_mode";
              data.option = "comfort";
            }
          ];
        }

        # Return - evening sala comfort.
        {
          id = "return_evening_sala";
          alias = "Return Home - Sala Comfort (evening)";
          description = "Set sala to comfort when person returns 18:00–23:00.";
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
              condition = "state";
              entity_id = "binary_sensor.outdoor_needs_conditioning";
              state = "on";
            }
          ];
          action = [
            {
              action = "input_text.set_value";
              target.entity_id = "input_text.ac_sala_last_intent";
              data.value = "{{ now().strftime('%H:%M') }} occupancy:return_evening → comfort";
            }
            {
              action = "input_select.select_option";
              target.entity_id = "input_select.zone_sala_mode";
              data.option = "comfort";
            }
          ];
        }

        # ─────────────────────────────────────────────────────────────
        # Climate policy - TV / calendar triggered
        # ─────────────────────────────────────────────────────────────

        # TV on, evening, sala currently off, weather warrants it.
        {
          id = "tv_on_sala_comfort";
          alias = "TV On - Sala Comfort";
          description = "Bring sala to comfort when LG TV turns on in the evening.";
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
              entity_id = "input_select.zone_sala_mode";
              state = "off";
            }
            {
              condition = "state";
              entity_id = "binary_sensor.outdoor_needs_conditioning";
              state = "on";
            }
          ];
          action = [
            {
              action = "input_text.set_value";
              target.entity_id = "input_text.ac_sala_last_intent";
              data.value = "{{ now().strftime('%H:%M') }} trigger:tv_on → comfort";
            }
            {
              action = "input_select.select_option";
              target.entity_id = "input_select.zone_sala_mode";
              data.option = "comfort";
            }
          ];
        }

        # TV off late: sala off (let bedroom remain whatever it is - bedroom prep
        # is no longer a separate automation; configure manually if you want it).
        {
          id = "tv_off_late_sala_off";
          alias = "TV Off Late - Sala Off";
          description = "Sala off when TV turns off after 23:00.";
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
              action = "input_text.set_value";
              target.entity_id = "input_text.ac_sala_last_intent";
              data.value = "{{ now().strftime('%H:%M') }} trigger:tv_off_late → off";
            }
            {
              action = "input_select.select_option";
              target.entity_id = "input_select.zone_sala_mode";
              data.option = "off";
            }
          ];
        }

        # Calendar - pre-heat office 15 min before scheduled meeting.
        {
          id = "calendar_meeting_escritorio";
          alias = "Calendar Meeting - Escritorio Comfort";
          description = "Pre-condition escritorio 15 min before a calendar event 07:00–10:00 weekday.";
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
              entity_id = "binary_sensor.anyone_home";
              state = "on";
            }
            {
              condition = "state";
              entity_id = "input_select.zone_escritorio_mode";
              state = "off";
            }
            {
              condition = "state";
              entity_id = "binary_sensor.outdoor_needs_conditioning";
              state = "on";
            }
          ];
          action = [
            {
              action = "input_text.set_value";
              target.entity_id = "input_text.ac_escritorio_last_intent";
              data.value = "{{ now().strftime('%H:%M') }} trigger:calendar_meeting → comfort";
            }
            {
              action = "input_select.select_option";
              target.entity_id = "input_select.zone_escritorio_mode";
              data.option = "comfort";
            }
          ];
        }

        # ─────────────────────────────────────────────────────────────
        # Garmin Health & Training
        # ─────────────────────────────────────────────────────────────

        {
          id = "post_workout_notification";
          alias = "Post-Workout Summary";
          description = "Notify when Garmin detects a completed workout.";
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

        # Fires when *known* body battery or sleep score is below threshold.
        # The template guard ensures unknown/unavailable states don't trip the
        # alert (a bare numeric_state would coerce them and fire spuriously).
        {
          id = "low_recovery_alert";
          alias = "Low Recovery Alert";
          description = "Morning alert when body battery or sleep score is critically low.";
          trigger = [
            {
              platform = "time";
              at = "08:30:00";
            }
          ];
          condition = [
            {
              condition = "template";
              value_template = ''
                {%- set bb = states('sensor.garmin_connect_body_battery_most_recent') -%}
                {%- set ss = states('sensor.garmin_connect_sleep_score') -%}
                {{ (has_value('sensor.garmin_connect_body_battery_most_recent') and bb | int(100) < 30)
                   or (has_value('sensor.garmin_connect_sleep_score') and ss | int(100) < 50) }}
              '';
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

        {
          id = "resting_hr_elevation_alert";
          alias = "Resting HR Elevation Alert";
          description = "Warn when resting HR is elevated above baseline - early overtraining sign.";
          trigger = [
            {
              platform = "numeric_state";
              entity_id = "sensor.garmin_connect_resting_heart_rate";
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
        # Google Sheets logging (Sheets OAuth must be completed via UI)
        # ─────────────────────────────────────────────────────────────

        {
          id = "sheets_hourly_temperature_log";
          alias = "Sheets - Hourly Temperature Log";
          description = "Log temperatures from all rooms and outdoor to Google Sheets every hour.";
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
                  Zone_Sala_Intent = "{{ states('input_select.zone_sala_mode') }}";
                  Zone_Escritorio_Intent = "{{ states('input_select.zone_escritorio_mode') }}";
                  Zone_Quarto_Intent = "{{ states('input_select.zone_quarto_mode') }}";
                  Zone_Hospedes_Intent = "{{ states('input_select.zone_quarto_hospedes_mode') }}";
                };
              };
            }
          ];
        }

        # Daily AC runtime - uses *_runtime_yesterday so the log records the day
        # that just ended, not today's accumulation-since-midnight.
        {
          id = "sheets_daily_ac_runtime";
          alias = "Sheets - Daily AC Runtime";
          description = "Log yesterday's AC runtime hours to Google Sheets at 00:05.";
          trigger = [
            {
              platform = "time";
              at = "00:05:00";
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
                  Sala_Hours = "{{ states('sensor.ac_sala_runtime_yesterday') }}";
                  Escritorio_Hours = "{{ states('sensor.ac_escritorio_runtime_yesterday') }}";
                  Quarto_Hours = "{{ states('sensor.ac_quarto_runtime_yesterday') }}";
                  Hospedes_Hours = "{{ states('sensor.ac_quarto_hospedes_runtime_yesterday') }}";
                  Total_Hours = "{{ (
                  (states('sensor.ac_sala_runtime_yesterday') | float(0)) +
                  (states('sensor.ac_escritorio_runtime_yesterday') | float(0)) +
                  (states('sensor.ac_quarto_runtime_yesterday') | float(0)) +
                  (states('sensor.ac_quarto_hospedes_runtime_yesterday') | float(0))
                ) | round(2) }}";
                };
              };
            }
          ];
        }

        {
          id = "sheets_daily_garmin_log";
          alias = "Sheets - Daily Garmin Log";
          description = "Log daily Garmin health, sleep, and training metrics to Google Sheets at 23:00.";
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
