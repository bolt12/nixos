# Cameras: whether Frigate is receiving frames, how the detector keeps up,
# and what it has seen. pet-report reads from the same streams.
{ d, ... }:
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

  perCamera =
    title: metric: desc:
    timeseries {
      inherit title desc;
      targets = [ (q metric "{{camera_name}}") ];
      unit = "suffix: fps";
      many = true;
      min = 0;
      w = 8;
    };

  # Despite its name this is not a counter: it is the number of events Frigate
  # still keeps, and it falls as old ones expire. increase() would read every
  # fall as a reset and invent thousands of events.
  kept = by: "sum by (${by}) (frigate_camera_events_total)";
in
d.dashboard {
  uid = "cameras";
  title = "Cameras";
  description = "Frigate: frames received per camera, detector speed, events seen, and recording storage.";
  from = "now-24h";
  rows = [
    (row null [
      (tile {
        title = "Streaming";
        expr = "count(frigate_camera_fps >= 1) or vector(0)";
        limits = thresholds.below 4 1;
        desc = "Of four. A camera counts when Frigate receives at least one frame a second from it.";
      })
      (tile {
        title = "Stalled";
        expr = "count(frigate_camera_fps < 1) or vector(0)";
        limits = thresholds.zero;
      })
      (tile {
        title = "Detector speed";
        expr = "max(frigate_detector_inference_speed_seconds)";
        unit = "s";
        limits = thresholds.above 5.0e-2 0.2;
        desc = "Time to run the model on one frame.";
      })
      (tile {
        title = "Detections";
        expr = "frigate_detection_total_fps";
        unit = "suffix: fps";
        decimals = 1;
        spark = true;
      })
      (tile {
        title = "Events kept";
        expr = "sum(frigate_camera_events_total)";
        decimals = 0;
      })
      (tile {
        title = "Recordings";
        expr = ''max(frigate_storage_used_bytes{storage=~".*recordings"})'';
        unit = "bytes";
        decimals = 1;
      })
      (tile {
        title = "Events, net 24h";
        expr = "sum(delta(frigate_camera_events_total[1d]))";
        decimals = 0;
        desc = "New events minus expired ones. Negative for a whole day means nothing new is being recorded.";
      })
      (tile {
        title = "Frigate on the GPU";
        expr = ''nvidia_tenant_memory_used_bytes{tenant="frigate"}'';
        unit = "bytes";
        decimals = 1;
      })
    ])

    (row "Are frames arriving" [
      (d.timeline {
        title = "Streams";
        targets = [ (q "frigate_camera_fps >= bool 1" "{{camera_name}}") ];
        states = d.mapValues {
          "1" = [
            "streaming"
            status.good
          ];
          "0" = [
            "STALLED"
            status.critical
          ];
        };
        h = 6;
      })
      (perCamera "Frames received" "frigate_camera_fps"
        "What ffmpeg decodes from each camera. Zero means the stream is down."
      )
      (perCamera "Frames processed" "frigate_process_fps" "Frames that went through motion detection.")
      (perCamera "Frames skipped" "frigate_skipped_fps"
        "Frames dropped because processing could not keep up."
      )
    ])

    (row "Detection" [
      (timeseries {
        title = "Detector speed";
        targets = [ (q "frigate_detector_inference_speed_seconds" "{{name}}") ];
        unit = "s";
        many = true;
        min = 0;
        w = 8;
      })
      (perCamera "Detections run" "frigate_detection_fps"
        "Model runs per second, per camera. Follows motion."
      )
      (timeseries {
        title = "Frigate CPU, by job";
        targets = [ (q "sum by (process) (frigate_cpu_usage_percent{type=\"Camera\"})" "{{process}}") ];
        unit = "percent";
        many = true;
        min = 0;
        w = 8;
        desc = "Percent of one core, summed across cameras.";
      })
    ])

    (row "What it saw" [
      (timeseries {
        title = "Events kept, by camera";
        targets = [ (q (kept "camera") "{{camera}}") ];
        many = true;
        min = 0;
        desc = "A line that only falls is a camera recording nothing new while its old events expire.";
      })
      (timeseries {
        title = "Events kept, by kind";
        targets = [ (q (kept "label") "{{label}}") ];
        many = true;
        min = 0;
      })
      (d.bars {
        title = "Events kept, by kind";
        targets = [ (q "sort_desc(${kept "label"})" "{{label}}") ];
        decimals = 0;
        h = 7;
      })
      (d.bars {
        title = "Events kept, by camera";
        targets = [ (q "sort_desc(${kept "camera"})" "{{camera}}") ];
        decimals = 0;
        h = 7;
      })
    ])

    (row "Storage" [
      (d.bars {
        title = "Space used";
        targets = [ (q "frigate_storage_used_bytes" "{{storage}}") ];
        unit = "bytes";
        h = 6;
        desc = "Recordings and clips share one filesystem, so they report the same figure.";
      })
      (timeseries {
        title = "Recordings over time";
        targets = [ (q ''max(frigate_storage_used_bytes{storage=~".*recordings"})'' "") ];
        unit = "bytes";
        min = 0;
        h = 6;
      })
    ])
  ];
}
