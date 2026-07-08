# Frigate NVR (Docker, 0.18-dev tensorrt): person/dog/cat detection on the Eufy
# cameras, GPU-accelerated via CDI (`--device nvidia.com/gpu=all`, verified: plain
# `--gpus all` misfires to an AMD hook on this host). Feeds the Phase-2 pet-report
# pipeline. Detector is LibreYOLO YOLOv9-c (MIT, pre-exported ONNX, 640x640 in,
# output [1,84,8400] which Frigate's `yolo-generic` parses cleanly). The 5090 has
# ample headroom for the larger `c` variant over the stock `s`.
#
# Image is a 0.18-dev build pinned by digest, NOT stable: the RTX 5090 is Blackwell
# (sm_120) and needs CUDA 12.8+. Stable 0.17.2-tensorrt ships CUDA 12.3 and the
# detector hangs in a watchdog loop on Blackwell. This dev build (commit c007661,
# 2026-07-02) verified to carry CUDA 12.8.90 + cuDNN 9.8 + onnxruntime-gpu 1.24.
# Bump to 0.18 stable-tensorrt once it is released.
{
  config,
  pkgs,
  lib,
  constants,
  ...
}:
let
  inherit (constants) storage ports;
  dataDir = "${storage.data}/frigate";

  # Single retention window for all heavy media (recordings, event clips, snapshots):
  # one month. The pet-report text log (observations + report narratives) is kept
  # separately and is not bounded here.
  retainDays = 30;

  # Pinned LibreYOLO YOLOv9-c ONNX (MIT). Reproducible: fetched into the nix
  # store, then copied into Frigate's writable model_cache so it can build the
  # TensorRT engine alongside it on first boot.
  yoloModel = pkgs.fetchurl {
    url = "https://huggingface.co/LibreYOLO/libreyolo-web/resolve/main/yolo9_c.onnx";
    hash = "sha256-+SHmIeEH4D2mR8b0E5jHQiiWXTz3lDofwfpG9Av9oQQ=";
  };

  # Cameras: Frigate key (also the go2rtc stream name), display name, RTSP URL.
  # Add one here and it is wired up for streaming, detection, recording and the
  # pet-report pipeline (mirror the name into PET_CAMERAS in pet-report.nix).
  # TODO(secrets): RTSP passwords are inline (matches the repo's existing
  # secret-in-nix pattern); move to a real secret alongside the nextcloud one.
  cameraDefs = [
    {
      name = "eufy_office";
      friendly = "Eufy Office Camera";
      url = "rtsp://Bolt12:Eufy12@192.168.1.66/live0";
    }
    {
      name = "family_room";
      friendly = "Family Room Camera";
      url = "rtsp://Bolt12:Eufy12@192.168.1.100:554/live0";
    }
    {
      name = "living_room";
      friendly = "Living Room Camera";
      url = "rtsp://Bolt12:Eufy12@192.168.1.65:554/live0";
    }
    {
      name = "bedroom";
      friendly = "Bedroom Camera";
      url = "rtsp://Bolt12:Eufy12@192.168.1.116/live0";
    }
  ];

  # Per-camera config. 1080p main stream only (Eufy exposes no substream); 5 fps
  # detect is Frigate's recommended rate, recordings stay full-framerate via stream
  # copy. Event-based recording only (no 24/7 continuous): person -> alerts, pets
  # -> detections by Frigate's defaults. Reads from the go2rtc restream so
  # detect/record + the pet-report sampler share one pull per camera.
  mkCamera = c: {
    friendly_name = c.friendly;
    enabled = true;
    ffmpeg.inputs = [
      {
        path = "rtsp://127.0.0.1:8554/${c.name}";
        input_args = "preset-rtsp-restream";
        roles = [
          "audio"
          "detect"
          "record"
        ];
      }
    ];
    detect = {
      enabled = true;
      width = 1920;
      height = 1080;
      fps = 5;
    };
    objects.track = [
      "person"
      "dog"
      "cat"
      "bird"
    ];
    record = {
      enabled = true;
      continuous.days = 0;
      motion.days = 0;
      alerts.retain = {
        days = retainDays;
        mode = "motion";
      };
      detections.retain = {
        days = retainDays;
        mode = "motion";
      };
    };
    snapshots = {
      enabled = true;
      quality = 80;
      retain.default = retainDays;
    };
  };

  # Whole config generated from the Nix attrset (no hand-indented YAML). LAN-only
  # + firewalled, so auth/TLS are off for plain-HTTP API access from pet-report.
  frigateConfig = (pkgs.formats.yaml { }).generate "frigate-config.yml" {
    auth.enabled = false;
    tls.enabled = false;
    mqtt.enabled = false;
    database.path = "/media/frigate/frigate.db";
    # Audio detection (YAMNet): every Eufy stream carries an AAC track, so Frigate can
    # raise sound events too. They flow through the events API and are ingested by
    # pet-report (keep this list in sync with PET_AUDIO_LABELS). The per-camera `audio`
    # role above feeds the detector. Labels are exact tokens from Frigate's 521-class
    # audio-labelmap.txt (bad tokens silently no-op). Grouped: dog / cat / people /
    # arrivals / safety alarms / breakage. Trim to cut false positives.
    audio = {
      enabled = true;
      listen = [
        "bark"
        "bow-wow"
        "howl"
        "growling"
        "whimper_dog"
        "meow"
        "speech"
        "yell"
        "doorbell"
        "ding-dong"
        "knock"
        "slam"
        "fire_alarm"
        "smoke_detector"
        "siren"
        "car_alarm"
        "glass"
        "shatter"
        "breaking"
        "thump"
        "bang"
      ];
    };
    # Face recognition (built-in, local, no Frigate+). Runs on a detected `person`
    # (already tracked above), locates the face within that box, then recognizes it
    # against identities enrolled in the UI. `large` = ArcFace embedding model,
    # GPU-accelerated on the 5090 (the CDI device is already passed through).
    # Enrollment is done in the Frigate UI (Add Face wizard -> Train tab), not here.
    face_recognition = {
      enabled = true;
      model_size = "large";
    };
    detectors.onnx.type = "onnx";
    model = {
      path = "/config/model_cache/yolo9_c.onnx";
      model_type = "yolo-generic";
      width = 640;
      height = 640;
      input_tensor = "nchw";
      input_pixel_format = "rgb";
      input_dtype = "float";
      labelmap_path = "/labelmap/coco-80.txt";
    };
    go2rtc.streams = lib.listToAttrs (map (c: lib.nameValuePair c.name [ c.url ]) cameraDefs);
    cameras = lib.listToAttrs (map (c: lib.nameValuePair c.name (mkCamera c)) cameraDefs);
  };
in
{
  # Data directories on the storage pool (recordings can grow).
  systemd.tmpfiles.rules = [
    "d ${dataDir} 0750 root root - -"
    "d ${dataDir}/config 0750 root root - -"
    "d ${dataDir}/config/model_cache 0750 root root - -"
    "d ${dataDir}/media 0750 root root - -"
  ];

  virtualisation.oci-containers = {
    backend = "docker";
    containers.frigate = {
      image = "ghcr.io/blakeblackshear/frigate@sha256:3feb1a95370f6cad6e9063fc2c1a1bd87519ea4c013b7f0a3535de49e0bce368";
      autoStart = true;
      ports = [
        "${toString ports.frigate}:8971" # UI + API (auth/TLS disabled: plain HTTP)
        "8554:8554" # go2rtc RTSP restream (for the Phase-2 sampler)
      ];
      volumes = [
        "${dataDir}/config:/config"
        "${dataDir}/media:/media/frigate"
        "/etc/localtime:/etc/localtime:ro"
      ];
      environment = {
        TZ = "Europe/Lisbon";
      };
      extraOptions = [
        "--device=nvidia.com/gpu=all" # CDI GPU for the ONNX/TensorRT detector
        "--shm-size=512m"
        # Frigate requires a tmpfs recording cache; on the overlay fs the record
        # muxer stalls, which (sharing one ffmpeg) also starves the detect pipe.
        "--tmpfs=/tmp/cache:size=1000000000"
      ];
    };
  };

  # Seed the Nix-managed config and the detector model into the writable /config
  # before the container starts (mirrors the llama-cpp download wrappers). Config
  # is copied every start so Nix stays the source of truth; the model is placed
  # once so Frigate's cached TensorRT engine survives restarts.
  systemd.services.docker-frigate.preStart = ''
    install -Dm644 ${frigateConfig} ${dataDir}/config/config.yml
    if [ ! -s ${dataDir}/config/model_cache/yolo9_c.onnx ]; then
      install -Dm644 ${yoloModel} ${dataDir}/config/model_cache/yolo9_c.onnx
    fi
  '';

  # LAN-only; WireGuard is already a trusted interface.
  networking.firewall.allowedTCPPorts = [ ports.frigate ];
}
