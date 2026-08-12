# Home Assistant, template sensors. Module-merged into
# services.home-assistant.config by ./default.nix.
_:
let
  zones = import ./zones.nix;

  mkZoneTarget = z: {
    name = "Zone ${z.friendly} Target Temp";
    unique_id = "zone_${z.slug}_target_temp";
    state = ''
      {% set m = states('input_select.zone_${z.slug}_mode') %}
      {% if m == 'eco' %}${toString z.eco}
      {% elif m == 'comfort' %}${toString z.comfort}
      {% elif m == 'boost' %}${toString z.boost}
      {% else %}0{% endif %}
    '';
    unit_of_measurement = "°C";
  };
in
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
            name = "AC Total Runtime";
            unique_id = "ac_total_runtime";
            state = ''
              {% set vals = [
                states('sensor.ac_sala_runtime_total') | float(0),
                states('sensor.ac_escritorio_runtime_total') | float(0),
                states('sensor.ac_quarto_runtime_total') | float(0),
                states('sensor.ac_quarto_hospedes_runtime_total') | float(0),
              ] %}
              {{ vals | sum | round(2) }}
            '';
            unit_of_measurement = "h";
            state_class = "total_increasing";
            icon = "mdi:timer-outline";
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
        ]
        ++ (map mkZoneTarget zones);
      }
      {
        binary_sensor = [
          # <12°C heating gate: Lisbon sits below 15°C most of Nov–Mar, so the
          # old <15 gate filtered nothing. <12 aligns with when a heat pump
          # actually starts to matter for comfort.
          {
            name = "Outdoor Requires Heating";
            unique_id = "outdoor_requires_heating";
            state = "{{ state_attr('weather.forecast_home', 'temperature') | float(15) < 12 }}";
            icon = "mdi:thermometer-low";
          }
          {
            name = "Outdoor Requires Cooling";
            unique_id = "outdoor_requires_cooling";
            state = "{{ state_attr('weather.forecast_home', 'temperature') | float(15) > 25 }}";
            icon = "mdi:thermometer-high";
          }
          {
            name = "Outdoor Needs Conditioning";
            unique_id = "outdoor_needs_conditioning";
            state = "{{ is_state('binary_sensor.outdoor_requires_heating', 'on') or is_state('binary_sensor.outdoor_requires_cooling', 'on') }}";
            icon = "mdi:thermometer-alert";
          }
          # True iff at least one tracked person is at home. Used by away_mode
          # so the AC isn't shut off when only one inhabitant leaves.
          {
            name = "Anyone Home";
            unique_id = "anyone_home";
            state = ''
              {{ expand(states.person)
                 | selectattr('state', 'eq', 'home')
                 | list | count > 0 }}
            '';
            icon = "mdi:home-account";
          }
        ];
      }
    ];
  };
}
