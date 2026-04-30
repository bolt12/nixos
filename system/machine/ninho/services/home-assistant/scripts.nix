# Home Assistant — reusable script definitions invoked by automations and the UI.
# Module-merged into services.home-assistant.config by ./default.nix.
{ ... }:
{
  services.home-assistant.config = {
    script = {
      all_ac_off = {
        alias = "All AC Off";
        description = "Turn off all AC units";
        sequence = [
          {
            action = "climate.turn_off";
            target.entity_id = [
              "climate.ac_sala"
              "climate.ac_escritorio"
              "climate.ac_quarto"
              "climate.ac_quarto_hospedes"
            ];
          }
        ];
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
}
