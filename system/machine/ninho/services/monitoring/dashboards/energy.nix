# Energy & Cost: what the CPU and GPU draw and what that costs.
#
# Only those two are measured. Drives, board, memory, fans and PSU losses are
# not, so every figure here is a floor for the real consumption at the wall.
{ d, ... }:
let
  inherit (d)
    promql
    q
    row
    stat
    timeseries
    ;

  tile =
    args:
    stat (
      {
        w = 4;
        h = 4;
      }
      // args
    );

  # Energy over a window, in kWh. The CPU has a joule counter; the GPU only
  # reports instantaneous watts, so its energy is average power times time.
  cpuKwh = window: "sum(increase(node_rapl_package_joules_total[${window}])) / 3.6e6";
  gpuKwh =
    window: seconds: "sum(avg_over_time(nvidia_smi_power_draw_watts[${window}])) * ${seconds} / 3.6e6";
  kwh = window: seconds: "(${cpuKwh window} + ${gpuKwh window seconds})";

  rangeKwh = kwh "$__range" "$__range_s";
  # Scaled from the visible range to a longer period.
  projected = hours: "${rangeKwh} / $__range_s * 3600 * ${toString hours} * $price";

  euros = {
    unit = "currencyEUR";
    decimals = 2;
  };
in
d.dashboard {
  uid = "energy";
  title = "Energy & Cost";
  description = "CPU and GPU power, energy and cost. A floor for the box as a whole: nothing else in it is metered.";
  from = "now-7d";
  variables = [
    (d.textVar {
      name = "price";
      label = "Price, EUR per kWh";
      default = "0.15";
    })
  ];
  rows = [
    (row null [
      (tile {
        title = "CPU";
        expr = promql.cpuWatts;
        unit = "watt";
        decimals = 0;
        spark = true;
      })
      (tile {
        title = "GPU";
        expr = promql.gpuWatts;
        unit = "watt";
        decimals = 0;
        spark = true;
      })
      (tile {
        title = "CPU + GPU";
        expr = promql.watts;
        unit = "watt";
        decimals = 0;
        spark = true;
      })
      (tile {
        title = "Energy in the visible range";
        expr = rangeKwh;
        unit = "kwatth";
        decimals = 2;
      })
      (tile (
        {
          title = "Cost of the visible range";
          expr = "${rangeKwh} * $price";
        }
        // euros
      ))
      (tile (
        {
          title = "At this rate, per day";
          expr = "(${promql.watts}) / 1000 * 24 * $price";
          desc = "The current draw held for 24 hours.";
        }
        // euros
      ))
      (tile (
        {
          title = "At the range's average, per month";
          expr = projected 730;
          w = 6;
          desc = "The average draw over the visible range, held for a month. Widen the range for a steadier figure.";
        }
        // euros
      ))
      (tile (
        {
          title = "At the range's average, per year";
          expr = projected 8760;
          w = 6;
        }
        // euros
      ))
      (d.note {
        w = 12;
        h = 4;
        content = ''
          **What is and is not measured.** The CPU figure is the package energy counter (RAPL) and the GPU figure is what the card reports. The three hard drives, the motherboard, 128 GB of memory, the fans and the power supply's own losses are not measured anywhere, so the real draw at the wall is higher than anything on this page. A metering smart plug read through Home Assistant would close the gap.
        '';
      })
    ])

    (row "Power" [
      (timeseries {
        title = "Draw";
        targets = [
          (q promql.cpuWatts "CPU")
          (q promql.gpuWatts "GPU")
        ];
        unit = "watt";
        stack = true;
        min = 0;
      })
      (timeseries {
        title = "CPU package against its cores";
        targets = [
          (q promql.cpuWatts "package")
          (q "sum(rate(node_rapl_core_joules_total[$__rate_interval]))" "cores")
        ];
        unit = "watt";
        min = 0;
        desc = "The gap between the two is the rest of the package: cache, memory controller, integrated graphics.";
      })
    ])

    (row "Energy and cost" [
      (timeseries {
        title = "Energy per day";
        targets = [
          (q (cpuKwh "1d") "CPU")
          (q (gpuKwh "1d" "86400") "GPU")
        ];
        unit = "kwatth";
        stack = true;
        bucketed = true;
        interval = "1d";
        min = 0;
        desc = "Each bar is the 24 hours ending at that point.";
      })
      (timeseries {
        title = "Cost per day";
        targets = [ (q "${kwh "1d" "86400"} * $price" "") ];
        unit = "currencyEUR";
        bucketed = true;
        interval = "1d";
        min = 0;
      })
    ])

    (row "Who is using it" [
      (timeseries {
        title = "Estimated CPU power by service";
        targets = [
          (q (d.topOver 8 "service"
            "${promql.serviceCpu "$__rate_interval"} / scalar(sum(rate(node_cpu_seconds_total{mode!=\"idle\"}[$__rate_interval]))) * scalar(${promql.cpuWatts})"
            (promql.serviceCpuAt "$__range" " @ end()")
          ) "{{service}}")
        ];
        unit = "watt";
        many = true;
        stack = true;
        min = 0;
        desc = "An estimate: each service's share of busy CPU time, applied to the package power. It ignores that some instructions cost more than others.";
      })
      (timeseries {
        title = "GPU power against its limit";
        targets = [
          (q "nvidia_smi_power_draw_watts" "draw")
          (q "nvidia_smi_enforced_power_limit_watts" "limit")
        ];
        unit = "watt";
        min = 0;
        interval = "15s";
      })
    ])
  ];
}
