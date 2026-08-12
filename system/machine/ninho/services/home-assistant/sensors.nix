# Home Assistant, history_stats sensors. Module-merged into
# services.home-assistant.config by ./default.nix.
#
# For each AC zone we keep three rolling-window runtime sensors:
#   *_runtime_today     , accumulates from 00:00 today
#   *_runtime_yesterday , fixed yesterday window (used by daily summary)
#   *_runtime_total     , cumulative since 2026-01-01 (feeds utility_meter)
_:
let
  zones = import ./zones.nix;
  acStates = [
    "heat"
    "cool"
    "fan_only"
    "auto"
    "dry"
  ];

  mkSensor =
    {
      window,
      startExpr,
      endExpr,
    }:
    zone: {
      platform = "history_stats";
      name = "AC ${zone.friendly} Runtime ${window}";
      entity_id = "climate.ac_${zone.slug}";
      state = acStates;
      type = "time";
      start = startExpr;
      end = endExpr;
    };

  todaySensor = mkSensor {
    window = "Today";
    startExpr = "{{ today_at('00:00') }}";
    endExpr = "{{ now() }}";
  };
  yesterdaySensor = mkSensor {
    window = "Yesterday";
    startExpr = "{{ today_at('00:00') - timedelta(days=1) }}";
    endExpr = "{{ today_at('00:00') }}";
  };
  totalSensor = mkSensor {
    window = "Total";
    startExpr = "{{ '2026-01-01 00:00:00' | as_datetime | as_local }}";
    endExpr = "{{ now() }}";
  };
in
{
  services.home-assistant.config = {
    sensor = (map todaySensor zones) ++ (map yesterdaySensor zones) ++ (map totalSensor zones);
  };
}
