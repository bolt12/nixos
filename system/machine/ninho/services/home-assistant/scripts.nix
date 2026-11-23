# Home Assistant, reusable script definitions invoked by automations and the UI.
# Scripts go through input_select.zone_*_mode so the applier remains the sole
# writer to climate.* entities.
_:
let
  zones = import ./zones.nix;
  allZoneModes = map (z: "input_select.zone_${z.slug}_mode") zones;

  mkAllZonesScript =
    {
      alias,
      description,
      option,
    }:
    {
      inherit alias description;
      sequence = [
        {
          action = "input_select.select_option";
          target.entity_id = allZoneModes;
          data = {
            inherit option;
          };
        }
      ];
    };
in
{
  services.home-assistant.config = {
    script = {
      all_ac_off = mkAllZonesScript {
        alias = "All AC Off";
        description = "Set every zone to off.";
        option = "off";
      };

      all_comfort = mkAllZonesScript {
        alias = "All Comfort";
        description = "Set every zone to comfort mode.";
        option = "comfort";
      };

      all_boost = mkAllZonesScript {
        alias = "All Boost";
        description = "Set every zone to boost mode.";
        option = "boost";
      };

      guest_room_on = {
        alias = "Guest Room Heat";
        description = "Set the guest room to comfort.";
        sequence = [
          {
            action = "input_select.select_option";
            target.entity_id = "input_select.zone_quarto_hospedes_mode";
            data.option = "comfort";
          }
        ];
      };

      bedroom_quick_heat = {
        alias = "Bedroom Quick Heat";
        description = "Boost the bedroom for 30 minutes then turn it off.";
        sequence = [
          {
            action = "input_select.select_option";
            target.entity_id = "input_select.zone_quarto_mode";
            data.option = "boost";
          }
          { delay.minutes = 30; }
          {
            action = "input_select.select_option";
            target.entity_id = "input_select.zone_quarto_mode";
            data.option = "off";
          }
        ];
      };
    };
  };
}
