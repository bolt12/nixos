# Home Assistant — history_stats and other declarative sensor entries.
# Module-merged into services.home-assistant.config by ./default.nix.
{ ... }:
{
  services.home-assistant.config = {
    sensor = [
      {
        platform = "history_stats";
        name = "AC Sala Runtime Today";
        entity_id = "climate.ac_sala";
        state = [
          "heat"
          "cool"
          "fan_only"
          "auto"
        ];
        type = "time";
        start = "{{ today_at('00:00') }}";
        end = "{{ now() }}";
      }
      {
        platform = "history_stats";
        name = "AC Escritorio Runtime Today";
        entity_id = "climate.ac_escritorio";
        state = [
          "heat"
          "cool"
          "fan_only"
          "auto"
        ];
        type = "time";
        start = "{{ today_at('00:00') }}";
        end = "{{ now() }}";
      }
      {
        platform = "history_stats";
        name = "AC Quarto Runtime Today";
        entity_id = "climate.ac_quarto";
        state = [
          "heat"
          "cool"
          "fan_only"
          "auto"
        ];
        type = "time";
        start = "{{ today_at('00:00') }}";
        end = "{{ now() }}";
      }
      {
        platform = "history_stats";
        name = "AC Quarto Hospedes Runtime Today";
        entity_id = "climate.ac_quarto_hospedes";
        state = [
          "heat"
          "cool"
          "fan_only"
          "auto"
        ];
        type = "time";
        start = "{{ today_at('00:00') }}";
        end = "{{ now() }}";
      }
    ];
  };
}
