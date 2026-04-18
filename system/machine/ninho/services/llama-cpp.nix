{ config, pkgs, lib, constants, ... }:
let
  inherit (constants) ports;
  inherit (pkgs) llama-cpp-cuda whisper-cpp-cuda stable-diffusion-cpp-cuda writeShellScript;

  # Model paths
  whisper-model-path = "/var/lib/llama-cpp/models/ggml-large-v3-q8_0.bin";
  sd-model-dir = "/var/lib/llama-cpp/models/sd";
  sd3-model-dir = "/var/lib/llama-cpp/models/sd3";

  # Whisper wrapper: downloads model on first use, then execs whisper-server
  # llama-swap uses shlex + exec (no sh -c), so && chains don't work in cmd
  whisper-wrapper = writeShellScript "whisper-wrapper" ''
    if [ ! -f "${whisper-model-path}" ]; then
      echo "Downloading whisper large-v3 Q8_0 model..."
      mkdir -p "$(dirname "${whisper-model-path}")"
      ${pkgs.wget}/bin/wget -q --show-progress -O "${whisper-model-path}.tmp" \
        "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-q8_0.bin"
      mv "${whisper-model-path}.tmp" "${whisper-model-path}"
      echo "Whisper large-v3 model download complete."
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
      ${pkgs.wget}/bin/wget -q --show-progress -O "$dest.tmp" "$url"
      mv "$dest.tmp" "$dest"
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
      ${pkgs.wget}/bin/wget -q --show-progress -O "$dest.tmp" "$url"
      mv "$dest.tmp" "$dest"
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
      healthCheckTimeout = 3600;  # 60 minutes

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
      models = {

        # ===========================================================================
        # FIM MODEL - Fill-In-Middle for Code Completion (llama.vim)
        # ===========================================================================
        # Lightweight model that runs alongside Wyoming for code completion
        # Uses /infill endpoint, no jinja needed

        # Qwen2.5 Coder 14B Q8_0 - ~16GB VRAM, FIM-capable
        "qwen2.5-coder-14b-fim" = {
          cmd = ''
            ${wyoming-wrapper} ${llama-cpp-cuda}/bin/llama-server \
              -hf bartowski/Qwen2.5-Coder-14B-GGUF:Q8_0 \
              --metrics \
              --host 0.0.0.0 \
              --port ''${PORT} \
              -fit on \
              -c 32768 \
              --flash-attn on \
              --batch-size 2048 \
              --ubatch-size 2048
          '';
          aliases = [ "fim" "qwen-coder-fim" ];
        };

        # ===========================================================================
        # FULL-POWER MODELS (-full) - Optimized for Agentic Coding
        # ===========================================================================
        # Uses wyoming-wrapper script to stop Wyoming services and restart on exit
        # Parameters: temp 0.2, top-p 0.9, min-p 0.01 for precise yet creative code
        # GPT-OSS models use official OpenAI params: temp=1, top_p=1

        # GPT-OSS 20B F16 - ~15GB base, MoE (3.6B active)
        "gpt-oss-20b-full" = {
          cmd = ''
            ${wyoming-wrapper} ${llama-cpp-cuda}/bin/llama-server \
              -hf unsloth/gpt-oss-20b-GGUF:F16 \
              --metrics \
              --host 0.0.0.0 \
              --port ''${PORT} \
              --temp 1.0 \
              --top-p 1.0 \
              --top-k 0 \
              -fit on \
              --fit-ctx 131072 \
              --fit-target 256 \
              --flash-attn on \
              --batch-size 8192 \
              --ubatch-size 2048 \
              --no-mmap \
              --chat-template-kwargs '{"reasoning_effort": "high"}' \
              --jinja
          '';
          aliases = [ "gpt-oss-full" "gpt-oss-20b-full" ];
        };

        # GPT-OSS 120B F16 - ~65GB base, MoE (5.1B active)
        # Requires CPU offload for full context
        "gpt-oss-120b-full" = {
          cmd = ''
            ${wyoming-wrapper} ${llama-cpp-cuda}/bin/llama-server \
              -hf unsloth/gpt-oss-120b-GGUF:F16 \
              --metrics \
              --host 0.0.0.0 \
              --port ''${PORT} \
              --temp 1.0 \
              --top-p 1.0 \
              --top-k 0 \
              -fit on \
              --fit-ctx 131072 \
              --fit-target 256 \
              --flash-attn on \
              --batch-size 8192 \
              --ubatch-size 2048 \
              --no-mmap \
              --chat-template-kwargs '{"reasoning_effort": "high"}' \
              --jinja
          '';
          aliases = [ "gpt-oss-120b-full" ];
        };

        "qwen3.5-27B-full" = {
          cmd = ''
            ${wyoming-wrapper} ${llama-cpp-cuda}/bin/llama-server \
              -hf unsloth/Qwen3.5-27B-GGUF:Q6_K \
              --metrics \
              --host 0.0.0.0 \
              --port ''${PORT} \
              --temp 0.6 \
              --top-p 0.95 \
              --top-k 20 \
              --min-p 0.0 \
              --presence-penalty 0.0 \
              --repeat-penalty 1.0 \
              -n 32768 \
              -c 196000 \
              -fit on \
              --flash-attn on \
              --cache-type-k q8_0 \
              --cache-type-v q8_0 \
              --no-mmap \
              --jinja
          '';
          aliases = [ "qwen3.5-27B-full" ];
        };

        # Qwen3.5-27B Creative - higher temp, no reasoning, optimized for journal/creative tasks
        "qwen3.5-27B-creative" = {
          cmd = ''
            ${wyoming-wrapper} ${llama-cpp-cuda}/bin/llama-server \
              -hf unsloth/Qwen3.5-27B-GGUF:Q6_K \
              --metrics \
              --host 0.0.0.0 \
              --port ''${PORT} \
              --temp 1.0 \
              --top-p 0.95 \
              --top-k 20 \
              --min-p 0.01 \
              --presence-penalty 1.5 \
              --repeat-penalty 1.0 \
              --flash-attn on \
              --cache-type-k q8_0 \
              --cache-type-v q8_0 \
              --no-mmap \
              --chat-template-kwargs '{"enable_thinking": false}' \
              --jinja
          '';
          aliases = [ "qwen3.5-27B-creative" ];
        };

        # Qwen3.5-9B UD-Q4_K_XL - ~6GB, thinking mode for agentic coding
        "qwen3.5-9B-full" = {
          cmd = ''
            ${wyoming-wrapper} ${llama-cpp-cuda}/bin/llama-server \
              -hf unsloth/Qwen3.5-9B-GGUF:BF16 \
              --metrics \
              --host 0.0.0.0 \
              --port ''${PORT} \
              --temp 0.6 \
              --top-p 0.95 \
              --top-k 20 \
              --min-p 0.0 \
              --presence-penalty 0.0 \
              --repeat-penalty 1.0 \
              -fit on \
              --flash-attn on \
              --no-mmap \
              -n 32768 \
              --chat-template-kwargs '{"enable_thinking": true}' \
              --jinja
          '';
          aliases = [ "qwen3.5-9B-full" ];
        };

        # Qwen3.6 35B A3B MoE (~3B active, 262K native context)
        "qwen3.6-35B-A3B-full" = {
          cmd = ''
            ${wyoming-wrapper} ${llama-cpp-cuda}/bin/llama-server \
              -hf unsloth/Qwen3.6-35B-A3B-GGUF:MXFP4_MOE \
              --metrics \
              --host 0.0.0.0 \
              --port ''${PORT} \
              --temp 0.6 \
              --top-p 0.95 \
              --top-k 20 \
              --min-p 0.0 \
              --presence-penalty 0.0 \
              --repeat-penalty 1.0 \
              -n 32768 \
              -fit on \
              --flash-attn on \
              --cache-type-k q8_0 \
              --cache-type-v q8_0 \
              --no-mmap \
              --jinja
          '';
          aliases = [ "qwen3.6-35B-A3B-full" ];
        };

        # Gemma 4 26B A4B MoE (~4B active, fast inference)
        "gemma-4-26B-A4B" = {
          cmd = ''
            ${wyoming-wrapper} ${llama-cpp-cuda}/bin/llama-server \
              -hf unsloth/gemma-4-26B-A4B-it-GGUF:Q8_0 \
              --metrics \
              --host 0.0.0.0 \
              --port ''${PORT} \
              --temp 1.0 \
              --top-p 0.95 \
              --top-k 64 \
              -fit on \
              --fit-ctx 180000 \
              --flash-attn on \
              --no-mmap \
              --jinja
          '';
          aliases = [ "gemma-4-26B-A4B" ];
        };

        # Gemma 4 31B Dense
        "gemma-4-31B" = {
          cmd = ''
            ${wyoming-wrapper} ${llama-cpp-cuda}/bin/llama-server \
              -hf unsloth/gemma-4-31B-it-GGUF:Q6_K \
              --metrics \
              --host 0.0.0.0 \
              --port ''${PORT} \
              --temp 1.0 \
              --top-p 0.95 \
              --top-k 64 \
              -fit on \
              --fit-ctx 150000 \
              --flash-attn on \
              --no-mmap \
              --jinja
          '';
          aliases = [ "gemma-4-31B" ];
        };

        # ===========================================================================
        # RERANK MODEL - Cross-encoder reranking for RAG pipelines
        # ===========================================================================
        # Lightweight (~500MB), runs alongside Wyoming without VRAM pressure

        "jina-reranker-v2" = {
          cmd = ''
            ${llama-cpp-cuda}/bin/llama-server \
              -hf gpustack/jina-reranker-v2-base-multilingual-GGUF:Q8_0 \
              --rerank \
              -ngl 99 \
              -c 16000 \
              --host 0.0.0.0 \
              --port ''${PORT}
          '';
          aliases = [ "rerank" "jina-reranker" ];
        };

        # ===========================================================================
        # TRANSCRIPTION MODEL - Whisper large-v3 via whisper-server
        # ===========================================================================
        # ~2GB VRAM, auto-downloads model on first use

        "whisper-large-v3" = {
          cmd = ''
            ${whisper-wrapper} ${whisper-cpp-cuda}/bin/whisper-server \
              --host 0.0.0.0 \
              --port ''${PORT} \
              -m ${whisper-model-path} \
              --request-path /v1/audio/transcriptions \
              --inference-path ""
          '';
          checkEndpoint = "/v1/audio/transcriptions/";
          aliases = [ "whisper" "whisper-v3" "transcription" ];
        };

        # ===========================================================================
        # IMAGE GENERATION - FLUX.1-schnell via stable-diffusion.cpp
        # ===========================================================================
        # Apache 2.0 license, 4-step generation, ~23GB total model files
        # Downloads on first use (like -hf models), subsequent loads are instant

        "flux1-schnell" = {
          cmd = ''
            ${wyoming-wrapper} ${sd-wrapper} ${stable-diffusion-cpp-cuda}/bin/sd-server \
              --listen-ip 0.0.0.0 \
              --listen-port ''${PORT} \
              --diffusion-model ${sd-model-dir}/flux1-schnell-q8_0.gguf \
              --vae ${sd-model-dir}/ae.safetensors \
              --clip_l ${sd-model-dir}/clip_l.safetensors \
              --t5xxl ${sd-model-dir}/t5xxl_fp16.safetensors
          '';
          checkEndpoint = "/v1/models";
          aliases = [ "image" "flux" "image-generation" ];
        };

        # ===========================================================================
        # IMAGE GENERATION - SD3.5 Medium via stable-diffusion.cpp
        # ===========================================================================
        # Stability AI's SD3.5 Medium, Q8_0 GGUF + safetensors VAE (~9.4GB download)
        # VAE not included in GGUF quantization — downloaded separately from ungated mirror

        "sd3.5-medium" = {
          cmd = ''
            ${wyoming-wrapper} ${sd3-wrapper} ${stable-diffusion-cpp-cuda}/bin/sd-server \
              --listen-ip 0.0.0.0 \
              --listen-port ''${PORT} \
              --diffusion-model ${sd3-model-dir}/sd3.5_medium-Q8_0.gguf \
              --vae ${sd3-model-dir}/vae.safetensors \
              --clip_g ${sd3-model-dir}/clip_g-Q8_0.gguf \
              --clip_l ${sd3-model-dir}/clip_l-Q8_0.gguf \
              --t5xxl ${sd3-model-dir}/t5xxl-Q8_0.gguf
          '';
          checkEndpoint = "/v1/models";
          aliases = [ "sd3" "sd3.5-medium" ];
        };
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
  users.groups.llama-swap = {};

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
      TimeoutStartSec = "infinity";  # No timeout during download
      TimeoutStopSec = "30s";
    };
  };

  # Add llama-cpp-cuda to system packages for manual testing
  environment.systemPackages = [ llama-cpp-cuda ];
}
