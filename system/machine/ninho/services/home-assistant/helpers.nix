# Home Assistant — input helpers backing the zone-mode AC abstraction and the
# audit trail. Module-merged into services.home-assistant.config.
#
# Each AC zone has:
#   input_select.zone_<slug>_mode    — off | eco | comfort | boost
#   input_text.ac_<slug>_last_intent — most recent *policy* decision (which
#                                      automation set the mode and why).
#                                      UI-driven changes go to HA's logbook,
#                                      not this audit text.
#
# input_boolean.ac_automations_enabled is the kill-switch for all appliers.
{ ... }:
let
  zones = import ./zones.nix;
  modes = [
    "off"
    "eco"
    "comfort"
    "boost"
  ];

  byKey =
    mkKey: mkValue:
    builtins.listToAttrs (
      map (z: {
        name = mkKey z;
        value = mkValue z;
      }) zones
    );

  modeSelects = byKey (z: "zone_${z.slug}_mode") (z: {
    name = "Zone ${z.friendly} Mode";
    options = modes;
    initial = "off";
    icon = "mdi:thermostat";
  });

  intentTexts = byKey (z: "ac_${z.slug}_last_intent") (z: {
    name = "AC ${z.friendly} — Last Intent";
    max = 255;
    icon = "mdi:history";
  });
in
{
  services.home-assistant.config = {
    input_select = modeSelects;
    input_text = intentTexts;
    input_boolean = {
      ac_automations_enabled = {
        name = "AC Automations Enabled";
        icon = "mdi:robot";
        initial = true;
      };
    };
  };
}
