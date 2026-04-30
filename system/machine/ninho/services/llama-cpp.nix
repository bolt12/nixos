# llama-swap orchestrator + 13 model definitions (see llama-cpp/models.nix).
{
  config,
  pkgs,
  lib,
  constants,
  ...
}:
let
  inherit (constants) ports;
  inherit (pkgs)
    llama-cpp-cuda
    whisper-cpp-cuda
    stable-diffusion-cpp-cuda
    writeShellScript
    ;

  # Model paths
  whisper-model-path = "/var/lib/llama-cpp/models/ggml-large-v3.bin";
  sd-model-dir = "/var/lib/llama-cpp/models/sd";
  sd3-model-dir = "/var/lib/llama-cpp/models/sd3";

  # Whisper wrapper: downloads model on first use, then execs whisper-server
  # llama-swap uses shlex + exec (no sh -c), so && chains don't work in cmd
  # `-s` (not `-f`) guards against a prior aborted wget leaving a 0-byte file;
  # `wget && mv` ensures the tmp file is only promoted on full success.
  whisper-wrapper = writeShellScript "whisper-wrapper" ''
    if [ ! -s "${whisper-model-path}" ]; then
      echo "Downloading whisper large-v3 F16 model..."
      mkdir -p "$(dirname "${whisper-model-path}")"
      ${pkgs.wget}/bin/wget -q --show-progress -O "${whisper-model-path}.tmp" \
          "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin" \
        && mv "${whisper-model-path}.tmp" "${whisper-model-path}" \
        || { rm -f "${whisper-model-path}.tmp"; echo "Whisper model download failed" >&2; exit 1; }
      echo "Whisper large-v3 F16 model download complete."
    fi
    exec "$@"
  '';

  # FLUX wrapper: downloads 4 model files on first use, then execs sd-server
  # ~23GB total across diffusion model, VAE, CLIP-L, T5-XXL
  sd-wrapper = writeShellScript "sd-wrapper" ''
    download() {
      local url="$1" dest="$2"
      if [ -s "$dest" ]; then
        return
      fi
      echo "Downloading $(basename "$dest")..."
      mkdir -p "$(dirname "$dest")"
      ${pkgs.wget}/bin/wget -q --show-progress -O "$dest.tmp" "$url" \
        && mv "$dest.tmp" "$dest" \
        || { rm -f "$dest.tmp"; echo "Download failed: $url" >&2; exit 1; }
    }
    download "https://huggingface.co/leejet/FLUX.1-schnell-gguf/resolve/main/flux1-schnell-q8_0.gguf" \
      "${sd-model-dir}/flux1-schnell-q8_0.gguf"
    # BFL repos are gated; use ungated community mirror for the VAE
    download "https://huggingface.co/camenduru/FLUX.1-dev-ungated/resolve/main/ae.safetensors" \
      "${sd-model-dir}/ae.safetensors"
    download "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors" \
      "${sd-model-dir}/clip_l.safetensors"
    download "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp16.safetensors" \
      "${sd-model-dir}/t5xxl_fp16.safetensors"
    exec "$@"
  '';

  # SD3.5 Medium wrapper: downloads 5 model files on first use, then execs sd-server
  # ~9.4GB total across diffusion model, VAE, CLIP-G, CLIP-L, T5-XXL
  sd3-wrapper = writeShellScript "sd3-wrapper" ''
    download() {
      local url="$1" dest="$2"
      if [ -s "$dest" ]; then
        return
      fi
      echo "Downloading $(basename "$dest")..."
      mkdir -p "$(dirname "$dest")"
      ${pkgs.wget}/bin/wget -q --show-progress -O "$dest.tmp" "$url" \
        && mv "$dest.tmp" "$dest" \
        || { rm -f "$dest.tmp"; echo "Download failed: $url" >&2; exit 1; }
    }
    download "https://huggingface.co/second-state/stable-diffusion-3.5-medium-GGUF/resolve/main/sd3.5_medium-Q8_0.gguf" \
      "${sd3-model-dir}/sd3.5_medium-Q8_0.gguf"
    # VAE not included in GGUF — download from ungated mirror (~167MB)
    download "https://huggingface.co/adamo1139/stable-diffusion-3.5-medium-ungated/resolve/main/vae/diffusion_pytorch_model.safetensors" \
      "${sd3-model-dir}/vae.safetensors"
    download "https://huggingface.co/second-state/stable-diffusion-3.5-medium-GGUF/resolve/main/clip_g-Q8_0.gguf" \
      "${sd3-model-dir}/clip_g-Q8_0.gguf"
    download "https://huggingface.co/second-state/stable-diffusion-3.5-medium-GGUF/resolve/main/clip_l-Q8_0.gguf" \
      "${sd3-model-dir}/clip_l-Q8_0.gguf"
    download "https://huggingface.co/second-state/stable-diffusion-3.5-medium-GGUF/resolve/main/t5xxl-Q8_0.gguf" \
      "${sd3-model-dir}/t5xxl-Q8_0.gguf"
    exec "$@"
  '';

  # llama-swap configuration - RTX 5090 (32GB VRAM), 128GB RAM
  # Models optimized for quality/context balance
  # Note: llama-cpp-cuda is now defined in system/common/overlays.nix

  # Wrapper script for full-power models - stops Wyoming, restarts on exit
  # Uses a FIFO-based helper to avoid sudo (llama-swap drops all capabilities)
  # Runs child in background with signal forwarding so llama-swap can unload models
  wyoming-wrapper = writeShellScript "wyoming-wrapper" ''
    set -euo pipefail

    WYOMING_CONTROL="/run/wyoming-control"
    MODEL_PID="$$"

    echo "stop $MODEL_PID" > "$WYOMING_CONTROL"

    cleanup() {
      echo "start $MODEL_PID" > "$WYOMING_CONTROL" || true
    }

    # Run llama-server in background so we can trap signals
    "$@" &
    CHILD_PID=$!

    # Forward termination signals to the child process
    trap 'kill $CHILD_PID 2>/dev/null; wait $CHILD_PID 2>/dev/null; cleanup' EXIT TERM INT HUP

    # Wait for child to complete
    wait $CHILD_PID
  '';

in
{
  services.llama-swap = {
    enable = true;
    port = ports.llamaswap;
    openFirewall = true;

    settings = {
      # Health check timeout - set high to allow large model downloads
      # FLUX.1-schnell is ~23GB across 4 files on first load
      healthCheckTimeout = 3600; # 60 minutes

      # startPort: sets the starting port number for the automatic ${PORT} macro.
      # - optional, default: 5800
      # - the ${PORT} macro can be used in model.cmd and model.proxy settings
      # - it is automatically incremented for every model that uses it
      startPort = 10000;

      # Show model aliases in /v1/models (for Open WebUI model picker)
      includeAliasesInList = true;

      # Peers configuration - route cloud models to Anthropic API
      # This allows using both local models and Anthropic's Claude models in the same session
      peers = {
        anthropic = {
          proxy = "https://api.anthropic.com";
          models = [
            # Current generation
            "claude-opus-4-6"
            "claude-sonnet-4-6"
            "claude-haiku-4-5-20251001"
            # Legacy (still active)
            "claude-sonnet-4-5-20250929"
            "claude-opus-4-5-20251101"
            "claude-opus-4-1-20250805"
            "claude-sonnet-4-20250514"
          ];
        };

        z-ai = {
          proxy = "https://api.z.ai/api/anthropic";
          apiKey = "a4fa0ae51579418d8a4fe5d547c0f0e5.8tEPzRTbIBYKmfpI";
          models = [
            "GLM-5"
            "GLM-4.7"
            "GLM-4.6"
            "GLM-4.5"
            "GLM-4.5-Air"
          ];
        };
      };
      models = import ./llama-cpp/models.nix {
        inherit
          wyoming-wrapper
          whisper-wrapper
          sd-wrapper
          sd3-wrapper
          llama-cpp-cuda
          whisper-cpp-cuda
          stable-diffusion-cpp-cuda
          whisper-model-path
          sd-model-dir
          sd3-model-dir
          ;
      };

    };
  };

  # Create static llama-swap user (required for sudoers rules to work)
  # DynamicUser creates temporary users that don't match sudoers rules
  users.users.llama-swap = {
    isSystemUser = true;
    group = "llama-swap";
    home = "/var/lib/llama-cpp";
    description = "llama-swap service user";
  };
  users.groups.llama-swap = { };

  # Create directory for models and cache
  systemd.tmpfiles.rules = [
    "d /var/lib/llama-cpp 0755 llama-swap llama-swap - -"
    "d /var/lib/llama-cpp/models 0755 llama-swap llama-swap - -"
    "d /var/lib/llama-cpp/cache 0755 llama-swap llama-swap - -"
    "d /var/lib/llama-cpp/models/sd 0755 llama-swap llama-swap - -"
    "d /var/lib/llama-cpp/models/sd3 0755 llama-swap llama-swap - -"
    # FIFO for Wyoming service control (avoids sudo from within llama-swap)
    "p /run/wyoming-control 0660 llama-swap root - -"
  ];

  # Helper service to control Wyoming services (runs with privileges)
  systemd.services.wyoming-control = {
    description = "Wyoming service control helper for llama-swap";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.bash}/bin/bash -c '${writeShellScript "wyoming-control-helper" ''
        set -euo pipefail

        FIFO="/run/wyoming-control"

        # Create FIFO if it doesn't exist
        if [[ ! -p "$FIFO" ]]; then
          rm -f "$FIFO"
          mkfifo -m 0660 "$FIFO"
          chown llama-swap:root "$FIFO"
        fi

        # Double-loop pattern: the inner loop reads until the writer closes
        # (EOF), then the outer loop re-opens the FIFO for the next writer.
        # Without this, a single writer closing causes the while-read to exit.
        while true; do
          while read -r cmd pid; do
            case "$cmd" in
              stop)
                /run/current-system/sw/bin/systemctl stop wyoming-faster-whisper-en || true
                /run/current-system/sw/bin/systemctl stop wyoming-faster-whisper-pt || true
                /run/current-system/sw/bin/systemctl stop wyoming-piper-en || true
                /run/current-system/sw/bin/systemctl stop wyoming-piper-pt || true
                /run/current-system/sw/bin/systemctl --user -M bolt@ stop sunshine || true
                ;;
              start)
                /run/current-system/sw/bin/systemctl start wyoming-faster-whisper-en || true
                /run/current-system/sw/bin/systemctl start wyoming-faster-whisper-pt || true
                /run/current-system/sw/bin/systemctl start wyoming-piper-en || true
                /run/current-system/sw/bin/systemctl start wyoming-piper-pt || true
                /run/current-system/sw/bin/systemctl --user -M bolt@ start sunshine || true
                ;;
              *)
                echo "wyoming-control: Unknown command: $cmd" >&2
                ;;
            esac
          done < "$FIFO"
        done
      ''}'";
      Restart = "always";
      RestartSec = 0;
      # This service runs as root to control system services
      User = "root";
    };
  };

  # Configure llama-swap service
  systemd.services.llama-swap = {
    serviceConfig = {
      # Use static user instead of DynamicUser (for FIFO compatibility)
      DynamicUser = lib.mkForce false;
      User = "llama-swap";
      Group = "llama-swap";

      # Set environment variables for llama-cpp cache
      # GGML_CUDA_DISABLE_GRAPHS: prevent CUDA graph corruption when
      # two llama-server processes share the same GPU (see llama.cpp #20027, #7492)
      Environment = [
        "HOME=/var/lib/llama-cpp"
        "XDG_CACHE_HOME=/var/lib/llama-cpp/cache"
        "GGML_CUDA_DISABLE_GRAPHS=1"
      ];

      # Grant write access to state directory
      StateDirectory = "llama-cpp";
      StateDirectoryMode = "0755";

      # Increase timeouts for large model downloads (up to 142GB!)
      TimeoutStartSec = "infinity"; # No timeout during download
      TimeoutStopSec = "30s";
    };
  };

  # Add llama-cpp-cuda to system packages for manual testing
  environment.systemPackages = [ llama-cpp-cuda ];
}
