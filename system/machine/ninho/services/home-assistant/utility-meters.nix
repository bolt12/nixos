# Home Assistant — utility_meter rollups for AC runtime hours, aligned to the
# Iberdrola 25th-to-25th billing cycle. Module-merged into HA config.
#
# Cron is computed as day = 1 + offset.days, so 24 → resets on the 25th.
{ ... }:
let
  zones = import ./zones.nix;
  billingOffsetDays = 24;

  mkMeter =
    { source, name }:
    {
      inherit source name;
      cycle = "monthly";
      offset.days = billingOffsetDays;
    };

  zoneMeter = z: {
    name = "ac_${z.slug}_runtime_billing";
    value = mkMeter {
      source = "sensor.ac_${z.slug}_runtime_total";
      name = "AC ${z.friendly} Runtime — Billing Cycle";
    };
  };
in
{
  services.home-assistant.config = {
    utility_meter = builtins.listToAttrs (map zoneMeter zones) // {
      ac_total_runtime_billing = mkMeter {
        source = "sensor.ac_total_runtime";
        name = "AC Total Runtime — Billing Cycle";
      };
    };
  };
}
