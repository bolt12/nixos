# GPU & AI: the RTX 5090, who holds its memory, and what the models are doing.
{ d, lib, ... }:
let
  inherit (d)
    q
    row
    stat
    status
    thresholds
    timeseries
    ;

  tile =
    args:
    stat (
      {
        w = 3;
        h = 4;
      }
      // args
    );

  # The GPU moves in seconds, so these panels ask for 15s steps.
  fast = args: timeseries ({ interval = "15s"; } // args);

  # llama-server metric names carry a colon.
  llama = name: "llamacpp:${name}";

  throttle = reason: "nvidia_smi_clocks_event_reasons_${reason}";

  # A lane that is drawn but says "nothing happening".
  idle = "#3d3f47";
in
d.dashboard {
  uid = "gpu";
  title = "GPU & AI";
  description = "GPU load, memory by tenant, thermals and throttling, and llama-server throughput per model.";
  rows = [
    (row null [
      (tile {
        title = "Utilisation";
        expr = "nvidia_smi_utilization_gpu_ratio * 100";
        unit = "percent";
        decimals = 0;
        spark = true;
      })
      (tile {
        title = "VRAM in use";
        expr = "nvidia_smi_memory_used_bytes";
        unit = "bytes";
        decimals = 1;
        spark = true;
      })
      (tile {
        title = "Power";
        expr = "nvidia_smi_power_draw_watts";
        unit = "watt";
        decimals = 0;
        spark = true;
      })
      (tile {
        title = "Temperature";
        expr = "nvidia_smi_temperature_gpu";
        unit = "celsius";
        limits = thresholds.above 80 90;
      })
      (tile {
        title = "Thermal headroom";
        expr = "nvidia_smi_temperature_gpu_tlimit";
        unit = "celsius";
        limits = thresholds.below 15 5;
        desc = "Degrees left before the card starts to slow itself down.";
      })
      (tile {
        title = "Fan";
        expr = "nvidia_smi_fan_speed_ratio * 100";
        unit = "percent";
        decimals = 0;
      })
      (tile {
        title = "Models loaded";
        expr = ''count(up{job="llama-server"} == 1) or vector(0)'';
      })
      (tile {
        title = "NVENC sessions";
        expr = "nvidia_smi_encoder_stats_session_count";
        desc = "NVENC sessions: Sunshine streams and Jellyfin transcodes.";
      })
    ])

    (row "Load" [
      (fast {
        title = "Utilisation";
        targets = [
          (q "nvidia_smi_utilization_gpu_ratio * 100" "compute")
          (q "nvidia_smi_utilization_memory_ratio * 100" "memory bus")
        ];
        unit = "percent";
        min = 0;
        max = 100;
      })
      (fast {
        title = "Memory by tenant";
        targets = [ (q "nvidia_tenant_memory_used_bytes" "{{tenant}}") ];
        unit = "bytes";
        stack = true;
        many = true;
        min = 0;
        desc = "Who holds VRAM, by systemd unit or container. The card has 32 GiB.";
      })
      (fast {
        title = "Power draw against the limit";
        targets = [
          (q "nvidia_smi_power_draw_watts" "draw")
          (q "nvidia_smi_enforced_power_limit_watts" "limit")
        ];
        unit = "watt";
        min = 0;
        w = 8;
      })
      (fast {
        title = "Temperature";
        targets = [ (q "nvidia_smi_temperature_gpu" "") ];
        unit = "celsius";
        limits = thresholds.above 80 90;
        w = 8;
      })
      (fast {
        title = "Fan speed";
        targets = [ (q "nvidia_smi_fan_speed_ratio * 100" "") ];
        unit = "percent";
        min = 0;
        max = 100;
        w = 8;
      })
    ])

    (row "Models" [
      (d.timeline {
        title = "Which model is loaded";
        targets = [ (q ''up{job="llama-server"}'' "{{model}}") ];
        states = d.mapValues {
          "1" = [
            "loaded"
            (lib.head d.palette)
          ];
          "0" = [
            "not loaded"
            idle
          ];
        };
        h = 6;
        desc = "llama-swap unloads a model after 15 idle minutes. Only models started with --metrics appear.";
      })
      (timeseries {
        title = "Generation speed";
        targets = [ (q (llama "predicted_tokens_seconds") "{{model}}") ];
        unit = "suffix: tok/s";
        many = true;
        min = 0;
        w = 8;
        interval = "15s";
        desc = "Average tokens generated per second of generation time.";
      })
      (timeseries {
        title = "Prompt processing speed";
        targets = [ (q (llama "prompt_tokens_seconds") "{{model}}") ];
        unit = "suffix: tok/s";
        many = true;
        min = 0;
        w = 8;
        interval = "15s";
      })
      (timeseries {
        title = "Requests in flight";
        targets = [
          (q "sum(${llama "requests_processing"})" "processing")
          (q "sum(${llama "requests_deferred"})" "waiting for a slot")
        ];
        min = 0;
        w = 8;
        interval = "15s";
      })
      (timeseries {
        title = "Tokens generated per minute";
        targets = [ (q "rate(${llama "tokens_predicted_total"}[$__rate_interval]) * 60" "{{model}}") ];
        many = true;
        min = 0;
      })
      (timeseries {
        title = "Prompt tokens read per minute";
        targets = [ (q "rate(${llama "prompt_tokens_total"}[$__rate_interval]) * 60" "{{model}}") ];
        many = true;
        min = 0;
      })
    ])

    (row "Throttling and link" [
      (d.timeline {
        title = "Is the card slowing itself down";
        targets = [
          (q (throttle "hw_thermal_slowdown") "hardware: too hot")
          (q (throttle "hw_power_brake_slowdown") "hardware: power brake")
          (q (throttle "sw_thermal_slowdown") "driver: too hot")
          (q (throttle "sw_power_cap") "driver: power cap")
        ];
        states = d.mapValues {
          "1" = [
            "throttling"
            status.warning
          ];
          "0" = [
            "clear"
            idle
          ];
        };
        w = 16;
        h = 7;
      })
      (tile {
        title = "PCIe lanes";
        expr = "nvidia_smi_pcie_link_width_current";
        w = 4;
        h = 7;
        desc = "8 is expected on this board: the slot's 16 lanes are split 8 + 4 + 4 with the two NVMe drives. At PCIe 5.0 that is as much bandwidth as 16 lanes at 4.0.";
      })
      (tile {
        title = "PCIe generation, 24h peak";
        expr = "max_over_time(nvidia_smi_pcie_link_gen_current[1d])";
        limits = thresholds.below 5 4;
        w = 4;
        h = 7;
        desc = "The link drops to generation 1 when idle to save power, so the peak is what matters.";
      })
      (fast {
        title = "Graphics clock against its maximum";
        targets = [
          (q "nvidia_smi_clocks_current_graphics_clock_hz" "current")
          (q "nvidia_smi_clocks_max_graphics_clock_hz" "maximum")
        ];
        unit = "hertz";
      })
      (fast {
        title = "Video encode and decode";
        targets = [
          (q "nvidia_smi_utilization_encoder_ratio * 100" "encode")
          (q "nvidia_smi_utilization_decoder_ratio * 100" "decode")
        ];
        unit = "percent";
        min = 0;
        max = 100;
      })
    ])
  ];
}
