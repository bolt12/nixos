# Home Assistant Lovelace dashboard (declarative YAML mode).
# Single huge attrset; kept whole so the dashboard JSON renders as one unit.
{ constants, ... }:
let
  inherit (constants) ports network;
in
{
  services.home-assistant = {
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
                  layout_options = {
                    grid_columns = 4;
                    grid_rows = 1;
                  };
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
                  layout_options = {
                    grid_columns = 4;
                    grid_rows = 1;
                  };
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
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 2;
                  };
                }
                {
                  type = "custom:button-card";
                  entity = "sensor.time_of_day";
                  name = "[[[ const h = new Date().getHours(); const d = new Date().getDay(); if (h >= 8 && h < 18 && d >= 1 && d <= 5) return 'Office'; if (h >= 23 || h < 8) return 'Bedroom'; return 'Living Room'; ]]]";
                  label = "[[[ const h = new Date().getHours(); const d = new Date().getDay(); if (h >= 8 && h < 18 && d >= 1 && d <= 5) return states['climate.ac_escritorio'].attributes.current_temperature + '°C'; if (h >= 23 || h < 8) return states['climate.ac_quarto'].attributes.current_temperature + '°C'; return states['climate.ac_sala'].attributes.current_temperature + '°C'; ]]]";
                  show_label = true;
                  icon = "[[[ const h = new Date().getHours(); const d = new Date().getDay(); if (h >= 8 && h < 18 && d >= 1 && d <= 5) return 'mdi:desk'; if (h >= 23 || h < 8) return 'mdi:bed'; return 'mdi:sofa'; ]]]";
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 2;
                  };
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
                  layout_options = {
                    grid_columns = 4;
                    grid_rows = 1;
                  };
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
                        service_data = {
                          entity_id = "automation.away_mode_all_ac_off";
                        };
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
                  layout_options = {
                    grid_columns = 4;
                    grid_rows = 3;
                  };
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
                      {
                        domain = "media_player";
                        state = "playing";
                      }
                      {
                        domain = "media_player";
                        state = "paused";
                      }
                    ];
                  };
                  sort.method = "state";
                  show_empty = false;
                  layout_options = {
                    grid_columns = 4;
                    grid_rows = 2;
                  };
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
                  severity = {
                    green = 70;
                    yellow = 50;
                    red = 0;
                  };
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 2;
                  };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "sensor.training_readiness";
                  name = "Training";
                  icon = "mdi:dumbbell";
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 1;
                  };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "sensor.garmin_connect_body_battery_most_recent";
                  name = "Body Battery";
                  icon = "mdi:battery-heart-variant";
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 1;
                  };
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
                  layout_options = {
                    grid_columns = 4;
                    grid_rows = 1;
                  };
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
                  layout_options = {
                    grid_columns = 4;
                    grid_rows = 1;
                  };
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
                  layout_options = {
                    grid_columns = 4;
                    grid_rows = 1;
                  };
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
                          entity_id = [
                            "climate.ac_sala"
                            "climate.ac_escritorio"
                            "climate.ac_quarto"
                            "climate.ac_quarto_hospedes"
                          ];
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
                          entity_id = [
                            "climate.ac_sala"
                            "climate.ac_escritorio"
                            "climate.ac_quarto"
                            "climate.ac_quarto_hospedes"
                          ];
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
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 3;
                  };
                  features = [
                    {
                      type = "climate-hvac-modes";
                      hvac_modes = [
                        "off"
                        "cool"
                        "heat"
                        "fan_only"
                        "auto"
                      ];
                    }
                    { type = "climate-fan-modes"; }
                  ];
                }
                {
                  type = "thermostat";
                  entity = "climate.ac_escritorio";
                  name = "Escritório (Office)";
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 3;
                  };
                  features = [
                    {
                      type = "climate-hvac-modes";
                      hvac_modes = [
                        "off"
                        "cool"
                        "heat"
                        "fan_only"
                        "auto"
                      ];
                    }
                    { type = "climate-fan-modes"; }
                  ];
                }
                {
                  type = "vertical-stack";
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 3;
                  };
                  cards = [
                    {
                      type = "thermostat";
                      entity = "climate.ac_quarto";
                      name = "Quarto (Bedroom)";
                      features = [
                        {
                          type = "climate-hvac-modes";
                          hvac_modes = [
                            "off"
                            "cool"
                            "heat"
                            "fan_only"
                            "auto"
                          ];
                        }
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
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 3;
                  };
                  cards = [
                    {
                      type = "thermostat";
                      entity = "climate.ac_quarto_hospedes";
                      name = "Quarto de Hóspedes (Guest)";
                      features = [
                        {
                          type = "climate-hvac-modes";
                          hvac_modes = [
                            "off"
                            "cool"
                            "heat"
                            "fan_only"
                            "auto"
                          ];
                        }
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
                  conditions = [
                    {
                      condition = "numeric_state";
                      entity = "sensor.active_ac_units";
                      above = 0;
                    }
                  ];
                  card = {
                    type = "glance";
                    title = "Room Humidity";
                    entities = [
                      {
                        entity = "sensor.ac_sala_room_humidity";
                        name = "Sala";
                      }
                      {
                        entity = "sensor.ac_escritorio_room_humidity";
                        name = "Escritório";
                      }
                      {
                        entity = "sensor.ac_quarto_room_humidity";
                        name = "Quarto";
                      }
                      {
                        entity = "sensor.ac_quarto_hospedes_room_humidity";
                        name = "Hóspedes";
                      }
                    ];
                  };
                }
                {
                  type = "glance";
                  title = "Current AC Modes";
                  layout_options = {
                    grid_columns = 4;
                    grid_rows = 1;
                  };
                  entities = [
                    {
                      entity = "climate.ac_sala";
                      name = "Sala";
                    }
                    {
                      entity = "climate.ac_escritorio";
                      name = "Escritório";
                    }
                    {
                      entity = "climate.ac_quarto";
                      name = "Quarto";
                    }
                    {
                      entity = "climate.ac_quarto_hospedes";
                      name = "Hóspedes";
                    }
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
                  header = {
                    title = "Temperature History (24h)";
                    show = true;
                  };
                  graph_span = "24h";
                  span.end = "now";
                  layout_options = {
                    grid_columns = 4;
                    grid_rows = 3;
                  };
                  yaxis = [
                    {
                      min = 14;
                      max = 32;
                    }
                  ];
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
                  header = {
                    title = "Temperature Comparison (48h)";
                    show = true;
                  };
                  graph_span = "48h";
                  span.end = "now";
                  layout_options = {
                    grid_columns = 4;
                    grid_rows = 3;
                  };
                  yaxis = [
                    {
                      min = 14;
                      max = 32;
                    }
                  ];
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
                  header = {
                    title = "AC Runtime Today";
                    show = true;
                  };
                  chart_type = "bar";
                  layout = "horizontal";
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 2;
                  };
                  series = [
                    {
                      entity = "sensor.ac_sala_runtime_today";
                      name = "Sala";
                      color = "#FF9800";
                    }
                    {
                      entity = "sensor.ac_escritorio_runtime_today";
                      name = "Escritório";
                      color = "#2196F3";
                    }
                    {
                      entity = "sensor.ac_quarto_runtime_today";
                      name = "Quarto";
                      color = "#9C27B0";
                    }
                    {
                      entity = "sensor.ac_quarto_hospedes_runtime_today";
                      name = "Hóspedes";
                      color = "#4CAF50";
                    }
                  ];
                }
                {
                  type = "custom:apexcharts-card";
                  header = {
                    title = "AC Runtime (7 days)";
                    show = true;
                  };
                  graph_span = "7d";
                  span.end = "now";
                  chart_type = "area";
                  stacked = true;
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 2;
                  };
                  series = [
                    {
                      entity = "sensor.ac_sala_runtime_today";
                      name = "Sala";
                      color = "#FF9800";
                      stroke_width = 1;
                      curve = "smooth";
                      opacity = 0.5;
                      group_by = {
                        func = "max";
                        duration = "1d";
                      };
                    }
                    {
                      entity = "sensor.ac_escritorio_runtime_today";
                      name = "Escritório";
                      color = "#2196F3";
                      stroke_width = 1;
                      curve = "smooth";
                      opacity = 0.5;
                      group_by = {
                        func = "max";
                        duration = "1d";
                      };
                    }
                    {
                      entity = "sensor.ac_quarto_runtime_today";
                      name = "Quarto";
                      color = "#9C27B0";
                      stroke_width = 1;
                      curve = "smooth";
                      opacity = 0.5;
                      group_by = {
                        func = "max";
                        duration = "1d";
                      };
                    }
                    {
                      entity = "sensor.ac_quarto_hospedes_runtime_today";
                      name = "Hóspedes";
                      color = "#4CAF50";
                      stroke_width = 1;
                      curve = "smooth";
                      opacity = 0.5;
                      group_by = {
                        func = "max";
                        duration = "1d";
                      };
                    }
                  ];
                }
                {
                  type = "conditional";
                  conditions = [
                    {
                      condition = "numeric_state";
                      entity = "sensor.active_ac_units";
                      above = 0;
                    }
                  ];
                  card = {
                    type = "custom:apexcharts-card";
                    header = {
                      title = "Humidity Comparison (24h)";
                      show = true;
                    };
                    graph_span = "24h";
                    span.end = "now";
                    series = [
                      {
                        entity = "sensor.ac_sala_room_humidity";
                        name = "Sala";
                        color = "#FF9800";
                        stroke_width = 2;
                        curve = "smooth";
                      }
                      {
                        entity = "sensor.ac_escritorio_room_humidity";
                        name = "Escritório";
                        color = "#2196F3";
                        stroke_width = 2;
                        curve = "smooth";
                      }
                      {
                        entity = "sensor.ac_quarto_room_humidity";
                        name = "Quarto";
                        color = "#9C27B0";
                        stroke_width = 2;
                        curve = "smooth";
                      }
                      {
                        entity = "sensor.ac_quarto_hospedes_room_humidity";
                        name = "Hóspedes";
                        color = "#4CAF50";
                        stroke_width = 2;
                        curve = "smooth";
                      }
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
                  layout_options = {
                    grid_columns = 4;
                    grid_rows = 1;
                  };
                  chips = [
                    {
                      type = "entity";
                      entity = "automation.workday_start_comfort";
                      icon = "mdi:weather-sunset-up";
                      name = "Workday";
                      tap_action = {
                        action = "toggle";
                      };
                    }
                    {
                      type = "entity";
                      entity = "automation.night_shutdown_all_ac";
                      icon = "mdi:weather-night";
                      name = "Night Off";
                      tap_action = {
                        action = "toggle";
                      };
                    }
                    {
                      type = "entity";
                      entity = "automation.away_mode_all_ac_off";
                      icon = "mdi:home-export-outline";
                      name = "Away";
                      tap_action = {
                        action = "toggle";
                      };
                    }
                    {
                      type = "entity";
                      entity = "automation.seasonal_mode_heat_cool_auto_switch";
                      icon = "mdi:sun-snowflake-variant";
                      name = "Seasonal";
                      tap_action = {
                        action = "toggle";
                      };
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
                  layout_options = {
                    grid_columns = 4;
                    grid_rows = 1;
                  };
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
                  severity = {
                    green = 70;
                    yellow = 50;
                    red = 0;
                  };
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 2;
                  };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "sensor.garmin_connect_last_activity";
                  name = "Last Activity";
                  icon = "mdi:run";
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 2;
                  };
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
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 1;
                  };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "sensor.garmin_connect_resting_heart_rate";
                  name = "Resting HR";
                  icon = "mdi:heart-pulse";
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 1;
                  };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "sensor.garmin_connect_sleep_score";
                  name = "Sleep Score";
                  icon = "mdi:sleep";
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 1;
                  };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "sensor.garmin_connect_avg_stress_level";
                  name = "Avg Stress";
                  icon = "mdi:head-snowflake";
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 1;
                  };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "sensor.garmin_connect_total_steps";
                  name = "Steps";
                  icon = "mdi:shoe-print";
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 1;
                  };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "sensor.garmin_connect_active_kilocalories";
                  name = "Active Cal";
                  icon = "mdi:fire";
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 1;
                  };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "sensor.garmin_connect_total_distance_mtr";
                  name = "Distance";
                  icon = "mdi:map-marker-distance";
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 1;
                  };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "sensor.garmin_connect_floors_ascended";
                  name = "Floors";
                  icon = "mdi:stairs-up";
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 1;
                  };
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
                  header = {
                    title = "Body Battery (24h)";
                    show = true;
                  };
                  graph_span = "24h";
                  span.end = "now";
                  layout_options = {
                    grid_columns = 4;
                    grid_rows = 3;
                  };
                  series = [
                    {
                      entity = "sensor.garmin_connect_body_battery_most_recent";
                      name = "Body Battery";
                      color = "#4CAF50";
                      stroke_width = 2;
                      curve = "smooth";
                      type = "area";
                      opacity = 0.2;
                    }
                  ];
                  yaxis = [
                    {
                      min = 0;
                      max = 100;
                    }
                  ];
                }
                {
                  type = "custom:apexcharts-card";
                  header = {
                    title = "Resting Heart Rate (7 days)";
                    show = true;
                  };
                  graph_span = "7d";
                  span.end = "now";
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 3;
                  };
                  series = [
                    {
                      entity = "sensor.garmin_connect_resting_heart_rate";
                      name = "Resting HR";
                      color = "#E53935";
                      stroke_width = 2;
                      curve = "smooth";
                    }
                  ];
                }
                {
                  type = "custom:apexcharts-card";
                  header = {
                    title = "Sleep Score (7 days)";
                    show = true;
                  };
                  graph_span = "7d";
                  span.end = "now";
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 3;
                  };
                  series = [
                    {
                      entity = "sensor.garmin_connect_sleep_score";
                      name = "Sleep Score";
                      color = "#7E57C2";
                      stroke_width = 2;
                      curve = "smooth";
                      type = "area";
                      opacity = 0.15;
                    }
                  ];
                  yaxis = [
                    {
                      min = 0;
                      max = 100;
                    }
                  ];
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
                  layout_options = {
                    grid_columns = 4;
                    grid_rows = 1;
                  };
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
                  media_controls = [
                    "on_off"
                    "play_pause_stop"
                  ];
                  volume_controls = [
                    "volume_buttons"
                    "volume_mute"
                  ];
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 2;
                  };
                }
                {
                  type = "custom:lg-webos-remote-control";
                  entity = "media_player.lg_webos_tv_75nano826qb";
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 4;
                  };
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
                      {
                        domain = "media_player";
                        integration = "jellyfin";
                      }
                    ];
                    exclude = [
                      { state = "unavailable"; }
                    ];
                  };
                  sort.method = "state";
                  show_empty = false;
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 2;
                  };
                }
                {
                  type = "custom:auto-entities";
                  card = {
                    type = "entities";
                    title = "Now Playing";
                  };
                  filter = {
                    include = [
                      {
                        domain = "media_player";
                        state = "playing";
                      }
                      {
                        domain = "media_player";
                        state = "paused";
                      }
                    ];
                  };
                  sort.method = "state";
                  show_empty = false;
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 2;
                  };
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
                  layout_options = {
                    grid_columns = 1;
                    grid_rows = 1;
                  };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "sensor.sonarr_shows";
                  name = "Shows";
                  icon = "mdi:television-classic";
                  layout_options = {
                    grid_columns = 1;
                    grid_rows = 1;
                  };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "sensor.nixos_ninho_active_clients";
                  name = "Active";
                  icon = "mdi:account-group";
                  layout_options = {
                    grid_columns = 1;
                    grid_rows = 1;
                  };
                }
                {
                  type = "custom:mushroom-chips-card";
                  alignment = "center";
                  layout_options = {
                    grid_columns = 1;
                    grid_rows = 1;
                  };
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
                      {
                        entity = "sensor.meater_probe_3415f6c7_internal_temperature";
                        name = "Internal";
                      }
                      {
                        entity = "sensor.meater_probe_3415f6c7_target_temperature";
                        name = "Target";
                      }
                      {
                        entity = "sensor.meater_probe_3415f6c7_ambient_temperature";
                        name = "Ambient";
                      }
                      {
                        entity = "sensor.meater_probe_3415f6c7_time_remaining";
                        name = "Time Left";
                      }
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
                  layout_options = {
                    grid_columns = 1;
                    grid_rows = 1;
                  };
                  tap_action = {
                    action = "url";
                    url_path = "http://${network.ninho.vpnIp}:${toString ports.jellyfin}";
                  };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Navidrome";
                  secondary = "Music";
                  icon = "mdi:music";
                  icon_color = "green";
                  layout_options = {
                    grid_columns = 1;
                    grid_rows = 1;
                  };
                  tap_action = {
                    action = "url";
                    url_path = "http://${network.ninho.vpnIp}:${toString ports.navidrome}";
                  };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Jellyseerr";
                  secondary = "Requests";
                  icon = "mdi:movie-search";
                  icon_color = "amber";
                  layout_options = {
                    grid_columns = 1;
                    grid_rows = 1;
                  };
                  tap_action = {
                    action = "url";
                    url_path = "http://${network.ninho.vpnIp}:${toString ports.jellyseerr}";
                  };
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
                  layout_options = {
                    grid_columns = 1;
                    grid_rows = 1;
                  };
                  tap_action = {
                    action = "url";
                    url_path = "http://${network.ninho.vpnIp}:${toString ports.jellyfin}";
                  };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Navidrome";
                  secondary = "Music";
                  icon = "mdi:music";
                  icon_color = "green";
                  layout_options = {
                    grid_columns = 1;
                    grid_rows = 1;
                  };
                  tap_action = {
                    action = "url";
                    url_path = "http://${network.ninho.vpnIp}:${toString ports.navidrome}";
                  };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Jellyseerr";
                  secondary = "Requests";
                  icon = "mdi:movie-search";
                  icon_color = "amber";
                  layout_options = {
                    grid_columns = 1;
                    grid_rows = 1;
                  };
                  tap_action = {
                    action = "url";
                    url_path = "http://${network.ninho.vpnIp}:${toString ports.jellyseerr}";
                  };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Kavita";
                  secondary = "Books";
                  icon = "mdi:book-open-page-variant";
                  icon_color = "teal";
                  layout_options = {
                    grid_columns = 1;
                    grid_rows = 1;
                  };
                  tap_action = {
                    action = "url";
                    url_path = "http://${network.ninho.vpnIp}:${toString ports.kavita}";
                  };
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
                  layout_options = {
                    grid_columns = 1;
                    grid_rows = 1;
                  };
                  tap_action = {
                    action = "url";
                    url_path = "http://${network.ninho.vpnIp}:8099";
                  };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Radarr";
                  secondary = "Movies";
                  icon = "mdi:movie";
                  icon_color = "amber";
                  layout_options = {
                    grid_columns = 1;
                    grid_rows = 1;
                  };
                  tap_action = {
                    action = "url";
                    url_path = "http://${network.ninho.vpnIp}:8098";
                  };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Lidarr";
                  secondary = "Music";
                  icon = "mdi:music-note";
                  icon_color = "green";
                  layout_options = {
                    grid_columns = 1;
                    grid_rows = 1;
                  };
                  tap_action = {
                    action = "url";
                    url_path = "http://${network.ninho.vpnIp}:8100";
                  };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Readarr";
                  secondary = "Books";
                  icon = "mdi:book";
                  icon_color = "brown";
                  layout_options = {
                    grid_columns = 1;
                    grid_rows = 1;
                  };
                  tap_action = {
                    action = "url";
                    url_path = "http://${network.ninho.vpnIp}:8101";
                  };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Prowlarr";
                  secondary = "Indexers";
                  icon = "mdi:magnify";
                  icon_color = "orange";
                  layout_options = {
                    grid_columns = 1;
                    grid_rows = 1;
                  };
                  tap_action = {
                    action = "url";
                    url_path = "http://${network.ninho.vpnIp}:8097";
                  };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Bazarr";
                  secondary = "Subtitles";
                  icon = "mdi:subtitles";
                  icon_color = "grey";
                  layout_options = {
                    grid_columns = 1;
                    grid_rows = 1;
                  };
                  tap_action = {
                    action = "url";
                    url_path = "http://${network.ninho.vpnIp}:8112";
                  };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Deluge";
                  secondary = "Torrents";
                  icon = "mdi:download";
                  icon_color = "blue";
                  layout_options = {
                    grid_columns = 1;
                    grid_rows = 1;
                  };
                  tap_action = {
                    action = "url";
                    url_path = "http://${network.ninho.vpnIp}:8103";
                  };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Bitmagnet";
                  secondary = "DHT Indexer";
                  icon = "mdi:magnet";
                  icon_color = "red";
                  layout_options = {
                    grid_columns = 1;
                    grid_rows = 1;
                  };
                  tap_action = {
                    action = "url";
                    url_path = "http://${network.ninho.vpnIp}:3333";
                  };
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
                  layout_options = {
                    grid_columns = 1;
                    grid_rows = 1;
                  };
                  tap_action = {
                    action = "url";
                    url_path = "http://${network.ninho.vpnIp}:${toString ports.nextcloud}";
                  };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Syncthing";
                  secondary = "Sync";
                  icon = "mdi:sync";
                  icon_color = "cyan";
                  layout_options = {
                    grid_columns = 1;
                    grid_rows = 1;
                  };
                  tap_action = {
                    action = "url";
                    url_path = "http://${network.ninho.vpnIp}:8384";
                  };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "FileBrowser";
                  secondary = "Web Files";
                  icon = "mdi:folder";
                  icon_color = "orange";
                  layout_options = {
                    grid_columns = 1;
                    grid_rows = 1;
                  };
                  tap_action = {
                    action = "url";
                    url_path = "http://${network.ninho.vpnIp}:${toString ports.filebrowser}";
                  };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Immich";
                  secondary = "Photos";
                  icon = "mdi:image-multiple";
                  icon_color = "indigo";
                  layout_options = {
                    grid_columns = 1;
                    grid_rows = 1;
                  };
                  tap_action = {
                    action = "url";
                    url_path = "http://${network.ninho.vpnIp}:${toString ports.immich}";
                  };
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
                  layout_options = {
                    grid_columns = 1;
                    grid_rows = 1;
                  };
                  tap_action = {
                    action = "url";
                    url_path = "http://${network.ninho.vpnIp}:${toString ports.llamaswap}";
                  };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "ComfyUI";
                  secondary = "Image Gen";
                  icon = "mdi:image-auto-adjust";
                  icon_color = "pink";
                  layout_options = {
                    grid_columns = 1;
                    grid_rows = 1;
                  };
                  tap_action = {
                    action = "url";
                    url_path = "http://${network.ninho.vpnIp}:${toString ports.comfy-ui}";
                  };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Memos";
                  secondary = "Notes";
                  icon = "mdi:note-text";
                  icon_color = "teal";
                  layout_options = {
                    grid_columns = 1;
                    grid_rows = 1;
                  };
                  tap_action = {
                    action = "url";
                    url_path = "http://${network.ninho.vpnIp}:8111";
                  };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Miniflux";
                  secondary = "RSS Reader";
                  icon = "mdi:rss";
                  icon_color = "orange";
                  layout_options = {
                    grid_columns = 1;
                    grid_rows = 1;
                  };
                  tap_action = {
                    action = "url";
                    url_path = "http://${network.ninho.vpnIp}:8104";
                  };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Emanote";
                  secondary = "Zettelkasten";
                  icon = "mdi:notebook";
                  icon_color = "green";
                  layout_options = {
                    grid_columns = 1;
                    grid_rows = 1;
                  };
                  tap_action = {
                    action = "url";
                    url_path = "http://${network.ninho.vpnIp}:7000";
                  };
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
                  layout_options = {
                    grid_columns = 1;
                    grid_rows = 1;
                  };
                  tap_action = {
                    action = "url";
                    url_path = "http://${network.ninho.vpnIp}:${toString ports.grafana}";
                  };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Gatus";
                  secondary = "Status";
                  icon = "mdi:heart-pulse";
                  icon_color = "green";
                  layout_options = {
                    grid_columns = 1;
                    grid_rows = 1;
                  };
                  tap_action = {
                    action = "url";
                    url_path = "http://${network.ninho.vpnIp}:${toString ports.gatus}";
                  };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Ntfy";
                  secondary = "Notifications";
                  icon = "mdi:bell";
                  icon_color = "red";
                  layout_options = {
                    grid_columns = 1;
                    grid_rows = 1;
                  };
                  tap_action = {
                    action = "url";
                    url_path = "http://${network.ninho.vpnIp}:${toString ports.ntfy}";
                  };
                }
                {
                  type = "custom:mushroom-template-card";
                  primary = "Homepage";
                  secondary = "Dashboard";
                  icon = "mdi:view-dashboard";
                  icon_color = "grey";
                  layout_options = {
                    grid_columns = 1;
                    grid_rows = 1;
                  };
                  tap_action = {
                    action = "url";
                    url_path = "http://${network.ninho.vpnIp}:${toString ports.homepage}";
                  };
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
                  layout_options = {
                    grid_columns = 4;
                    grid_rows = 1;
                  };
                  chips = [
                    {
                      type = "entity";
                      entity = "sensor.uptime";
                      icon = "mdi:clock-check";
                    }
                  ];
                }
                {
                  type = "gauge";
                  entity = "sensor.cpu_usage";
                  name = "CPU";
                  min = 0;
                  max = 100;
                  severity = {
                    green = 0;
                    yellow = 70;
                    red = 90;
                  };
                  layout_options = {
                    grid_columns = 1;
                    grid_rows = 2;
                  };
                }
                {
                  type = "gauge";
                  entity = "sensor.memory_usage";
                  name = "Memory";
                  min = 0;
                  max = 100;
                  severity = {
                    green = 0;
                    yellow = 70;
                    red = 90;
                  };
                  layout_options = {
                    grid_columns = 1;
                    grid_rows = 2;
                  };
                }
                {
                  type = "gauge";
                  entity = "sensor.system_monitor_processor_temperature";
                  name = "CPU Temp";
                  min = 20;
                  max = 100;
                  severity = {
                    green = 20;
                    yellow = 70;
                    red = 85;
                  };
                  layout_options = {
                    grid_columns = 1;
                    grid_rows = 2;
                  };
                }
                {
                  type = "gauge";
                  entity = "sensor.disk_usage";
                  name = "Root Disk";
                  min = 0;
                  max = 100;
                  severity = {
                    green = 0;
                    yellow = 70;
                    red = 90;
                  };
                  layout_options = {
                    grid_columns = 1;
                    grid_rows = 2;
                  };
                }
                {
                  type = "gauge";
                  entity = "sensor.storage_usage";
                  name = "Storage";
                  min = 0;
                  max = 100;
                  severity = {
                    green = 0;
                    yellow = 70;
                    red = 90;
                  };
                  layout_options = {
                    grid_columns = 4;
                    grid_rows = 2;
                  };
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
                  header = {
                    title = "System Load (24h)";
                    show = true;
                  };
                  graph_span = "24h";
                  span.end = "now";
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 3;
                  };
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
                  header = {
                    title = "CPU Usage (24h)";
                    show = true;
                  };
                  graph_span = "24h";
                  span.end = "now";
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 3;
                  };
                  series = [
                    {
                      entity = "sensor.system_monitor_processor_use";
                      name = "CPU";
                      color = "#2196F3";
                      stroke_width = 2;
                      curve = "smooth";
                      type = "area";
                      opacity = 0.2;
                    }
                  ];
                  yaxis = [
                    {
                      min = 0;
                      max = 100;
                    }
                  ];
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
                  layout_options = {
                    grid_columns = 4;
                    grid_rows = 1;
                  };
                  entities = [
                    {
                      entity = "sensor.speedtest_download";
                      name = "Download";
                      icon = "mdi:download";
                    }
                    {
                      entity = "sensor.speedtest_upload";
                      name = "Upload";
                      icon = "mdi:upload";
                    }
                    {
                      entity = "sensor.speedtest_ping";
                      name = "Ping";
                      icon = "mdi:timer-outline";
                    }
                  ];
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "sensor.system_monitor_network_throughput_in_enp11s0";
                  name = "enp11s0 In";
                  icon = "mdi:arrow-down";
                  layout_options = {
                    grid_columns = 1;
                    grid_rows = 1;
                  };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "sensor.system_monitor_network_throughput_out_enp11s0";
                  name = "enp11s0 Out";
                  icon = "mdi:arrow-up";
                  layout_options = {
                    grid_columns = 1;
                    grid_rows = 1;
                  };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "sensor.system_monitor_network_throughput_in_wg0";
                  name = "WG In";
                  icon = "mdi:arrow-down";
                  layout_options = {
                    grid_columns = 1;
                    grid_rows = 1;
                  };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "sensor.system_monitor_network_throughput_out_wg0";
                  name = "WG Out";
                  icon = "mdi:arrow-up";
                  layout_options = {
                    grid_columns = 1;
                    grid_rows = 1;
                  };
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
                  tap_action = {
                    action = "more-info";
                  };
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 1;
                  };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "light.yeelink_de_77086772_color1_s_2_light";
                  name = "Smart Light";
                  icon = "mdi:lightbulb";
                  tap_action = {
                    action = "toggle";
                  };
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 1;
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
                  type = "custom:mushroom-entity-card";
                  entity = "automation.workday_start_comfort";
                  name = "Workday Start";
                  icon = "mdi:weather-sunset-up";
                  tap_action = {
                    action = "toggle";
                  };
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 1;
                  };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "automation.night_shutdown_all_ac";
                  name = "Night Shutdown";
                  icon = "mdi:weather-night";
                  tap_action = {
                    action = "toggle";
                  };
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 1;
                  };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "automation.away_mode_all_ac_off";
                  name = "Away Mode";
                  icon = "mdi:home-export-outline";
                  tap_action = {
                    action = "toggle";
                  };
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 1;
                  };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "automation.return_home_smart_pre_heat";
                  name = "Return Home";
                  icon = "mdi:home-import-outline";
                  tap_action = {
                    action = "toggle";
                  };
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 1;
                  };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "automation.seasonal_mode_heat_cool_auto_switch";
                  name = "Seasonal Mode";
                  icon = "mdi:sun-snowflake-variant";
                  tap_action = {
                    action = "toggle";
                  };
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 1;
                  };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "automation.tv_on_heat_living_room";
                  name = "TV On Heat";
                  icon = "mdi:television";
                  tap_action = {
                    action = "toggle";
                  };
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 1;
                  };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "automation.cooking_done_notification";
                  name = "Cooking Alert";
                  icon = "mdi:grill";
                  tap_action = {
                    action = "toggle";
                  };
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 1;
                  };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "automation.garmin_daily_summary";
                  name = "Daily Health";
                  icon = "mdi:heart-pulse";
                  tap_action = {
                    action = "toggle";
                  };
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 1;
                  };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "automation.weekly_summary";
                  name = "Weekly Summary";
                  icon = "mdi:calendar-week";
                  tap_action = {
                    action = "toggle";
                  };
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 1;
                  };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "automation.night_bedroom_prep";
                  name = "Bedroom Prep";
                  icon = "mdi:bed-clock";
                  tap_action = {
                    action = "toggle";
                  };
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 1;
                  };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "automation.tv_off_late_night_shutdown";
                  name = "TV Off Late";
                  icon = "mdi:television-off";
                  tap_action = {
                    action = "toggle";
                  };
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 1;
                  };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "automation.calendar_meeting_pre_heat";
                  name = "Meeting Pre-Heat";
                  icon = "mdi:calendar-clock";
                  tap_action = {
                    action = "toggle";
                  };
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 1;
                  };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "automation.cold_weather_boost";
                  name = "Cold Boost";
                  icon = "mdi:snowflake-alert";
                  tap_action = {
                    action = "toggle";
                  };
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 1;
                  };
                }
                {
                  type = "custom:mushroom-entity-card";
                  entity = "automation.weekend_morning_comfort";
                  name = "Weekend Morning";
                  icon = "mdi:coffee";
                  tap_action = {
                    action = "toggle";
                  };
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 1;
                  };
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
                  layout_options = {
                    grid_columns = 4;
                    grid_rows = 1;
                  };
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
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 1;
                  };
                  tap_action = {
                    action = "call-service";
                    service = "homeassistant.reload_core_config";
                  };
                }
                {
                  type = "custom:button-card";
                  name = "Restart Home Assistant";
                  icon = "mdi:restart";
                  layout_options = {
                    grid_columns = 2;
                    grid_rows = 1;
                  };
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
                  layout_options = {
                    grid_columns = 4;
                    grid_rows = 3;
                  };
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
                  layout_options = {
                    grid_columns = 4;
                    grid_rows = 4;
                  };
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
                  layout_options = {
                    grid_columns = 4;
                    grid_rows = 2;
                  };
                }
              ];
            }
          ];
        }
      ];
    };
  };
}
