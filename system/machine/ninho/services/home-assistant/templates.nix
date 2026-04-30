# Home Assistant — template sensors (computed entities derived from other sensors).
# Module-merged into services.home-assistant.config by ./default.nix.
{ ... }:
{
  services.home-assistant.config = {
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
  };
}
