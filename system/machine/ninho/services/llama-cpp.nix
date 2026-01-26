{ config, pkgs, lib, constants, ... }:
let
  inherit (constants) ports;
  inherit (pkgs) llama-cpp-cuda writeShellScript;

  # llama-swap configuration - RTX 5090 (32GB VRAM), 128GB RAM
  # Models optimized for quality/context balance
  # Note: llama-cpp-cuda is now defined in system/common/overlays.nix

  # Wrapper script for full-power models - stops Wyoming, restarts on exit
  # Uses a FIFO-based helper to avoid sudo (llama-swap drops all capabilities)
  # Note: We don't use 'exec' because it replaces the shell and loses the trap handler
  wyoming-wrapper = writeShellScript "wyoming-wrapper" ''
    set -euo pipefail

    WYOMING_CONTROL="/run/wyoming-control"
    MODEL_PID="$$"

    echo "STOPPING WYOMING VOICE MODELS (PID: $MODEL_PID)"
    echo "stop $MODEL_PID" > "$WYOMING_CONTROL"

    # Restart Wyoming when this script exits (normal, error, or signal)
    cleanup() {
      echo "STARTING WYOMING VOICE MODELS (PID: $MODEL_PID)"
      echo "start $MODEL_PID" > "$WYOMING_CONTROL" || true
    }
    trap cleanup EXIT

    # Run llama-server as child process (not exec) so trap handler remains active
    "$@"
  '';

in
{
  services.llama-swap = {
    enable = true;
    port = ports.llamaswap;
    openFirewall = true;

    settings = {
      # Health check timeout - set high to allow large model downloads
      healthCheckTimeout = 1800;  # 30 minutes

      # startPort: sets the starting port number for the automatic ${PORT} macro.
      # - optional, default: 5800
      # - the ${PORT} macro can be used in model.cmd and model.proxy settings
      # - it is automatically incremented for every model that uses it
      startPort = 10000;

      # Peers configuration - route cloud models to Anthropic API
      # This allows using both local models and Anthropic's Claude models in the same session
      peers = {
        anthropic = {
          proxy = "https://api.anthropic.com";
          models = [
            "claude-sonnet-4-5-20250929"
            "claude-opus-4-5-20251101"
            "claude-haiku-4-20250515"
            "claude-sonnet-3-5-20240620"
            "claude-opus-3-20240229"
          ];
        };
      };
      models = {
        # ===========================================================================
        # HOME ASSISTANT MODELS (-hass) - Optimized for Tool Calling
        # ===========================================================================
        # Parameters: Low temperature (0.1-0.2) for deterministic JSON output
        #             Low top-p (0.1-0.3) for focused token selection
        #             No repeat penalty (breaks structured output)
        #             Moderate context (16k-32k) to fit in VRAM with Wyoming (~3GB)
        # Target: Fit entirely in 32GB VRAM for maximum speed

        # Qwen 2.5 32B Q5_K_M - ~22GB base, tool calling optimized
        "qwen2.5-instruct-hass" = {
          cmd = ''
            ${llama-cpp-cuda}/bin/llama-server \
              -hf Qwen/Qwen2.5-32B-Instruct-GGUF:Q5_K_M \
              --metrics \
              --host 0.0.0.0 \
              --port ''${PORT} \
              --temp 0.1 \
              --top-p 0.2 \
              --top-k 40 \
              -ngl 99 \
              -c 32000 \
              --cache-type-k q4_0 \
              --cache-type-v q4_0 \
              --flash-attn on \
              --batch-size 4096 \
              --ubatch-size 1024 \
              --jinja
          '';
          aliases = [ "qwen2.5-hass" ];
        };

        # Devstral Small 24B Q5_K_M - ~16GB base, tool calling optimized
        # Using Q5_K_M instead of Q6_K_XL to ensure full GPU fit
        "devstral-small-hass" = {
          cmd = ''
            ${llama-cpp-cuda}/bin/llama-server \
              -hf unsloth/Devstral-Small-2-24B-Instruct-2512-GGUF:Q5_K_M \
              --metrics \
              --host 0.0.0.0 \
              --port ''${PORT} \
              --temp 0.1 \
              --top-p 0.2 \
              --top-k 40 \
              -ngl 99 \
              -c 64000 \
              --cache-type-k q8_0 \
              --cache-type-v q8_0 \
              --flash-attn on \
              --batch-size 4096 \
              --ubatch-size 1024 \
              --jinja
          '';
          aliases = [ "devstral-hass" ];
        };

        # Nemotron 3 Nano 30B Q5_K_M - ~20GB base, MoE (3B active)
        # Using Q5_K_M instead of Q8_0 to fit entirely in GPU
        "nemotron-3-nano-hass" = {
          cmd = ''
            ${llama-cpp-cuda}/bin/llama-server \
              -hf unsloth/Nemotron-3-Nano-30B-A3B-GGUF:Q5_K_M \
              --metrics \
              --host 0.0.0.0 \
              --port ''${PORT} \
              --temp 0.1 \
              --top-p 0.2 \
              --top-k 40 \
              -ngl 99 \
              -c 64000 \
              --cache-type-k q8_0 \
              --cache-type-v q8_0 \
              --flash-attn on \
              --batch-size 4096 \
              --ubatch-size 1024 \
              --jinja
          '';
          aliases = [ "nemotron-hass" ];
        };

        # Qwen3 VL 32B Q5_K_M - ~22GB base, vision/multimodal
        "qwen3-vl-32b-hass" = {
          cmd = ''
            ${llama-cpp-cuda}/bin/llama-server \
              -hf unsloth/Qwen3-VL-30B-A3B-Instruct-GGUF:Q5_K_M \
              --metrics \
              --host 0.0.0.0 \
              --port ''${PORT} \
              --temp 0.1 \
              --top-p 0.2 \
              --top-k 40 \
              -ngl 99 \
              -c 64000 \
              --cache-type-k q8_0 \
              --cache-type-v q8_0 \
              --batch-size 1536 \
              --ubatch-size 512 \
              --flash-attn on \
              --jinja
          '';
          aliases = [ "qwen-vl-hass" "vision-hass" ];
        };

        # GPT-OSS 20B F16 - ~15GB base, MoE (3.6B active)
        # OpenAI recommends temp=1, top_p=1 for gpt-oss, but we use lower for tool calling
        "gpt-oss-20b-hass" = {
          cmd = ''
            ${llama-cpp-cuda}/bin/llama-server \
              -hf unsloth/gpt-oss-20b-GGUF:F16 \
              --metrics \
              --host 0.0.0.0 \
              --port ''${PORT} \
              --temp 0.1 \
              --top-p 0.2 \
              --top-k 40 \
              -ngl 99 \
              -c 64000 \
              --cache-type-k q8_0 \
              --cache-type-v q8_0 \
              --flash-attn on \
              --batch-size 4096 \
              --ubatch-size 1024 \
              --jinja
          '';
          aliases = [ "gpt-oss-hass" ];
        };

        # GPT-OSS 120B F16 - ~65GB base, MoE (5.1B active)
        # Requires CPU offload, lower context for -hass
        "gpt-oss-120b-hass" = {
          cmd = ''
            ${llama-cpp-cuda}/bin/llama-server \
              -hf unsloth/gpt-oss-120b-GGUF:F16 \
              --metrics \
              --host 0.0.0.0 \
              --port ''${PORT} \
              --temp 0.1 \
              --top-p 0.2 \
              --top-k 40 \
              -ngl 99 \
              -ot ".ffn_(up|down)_exps.=CPU" \
              -c 64000 \
              --cache-type-k q8_0 \
              --cache-type-v q8_0 \
              --flash-attn on \
              --batch-size 4096 \
              --ubatch-size 1024 \
              --jinja
          '';
          aliases = [ "gpt-oss-120b-hass" ];
        };

        # GLM 4.7 Flash Q5_K_M - ~15GB base
        "glm-4.7-flash-hass" = {
          cmd = ''
            ${llama-cpp-cuda}/bin/llama-server \
              -hf unsloth/GLM-4.7-Flash-REAP-23B-A3B-GGUF:Q8_0 \
              --metrics \
              --host 0.0.0.0 \
              --port ''${PORT} \
              --temp 0.7 \
              --top-p 1.0 \
              --min-p 0.01 \
              -ot ".ffn_(up)_exps.=CPU" \
              --repeat-penalty 1.0 \
              -ngl 99 \
              -c 64000 \
              --flash-attn on \
              --batch-size 4096 \
              --ubatch-size 1024 \
              --jinja
          '';
          aliases = [ "glm-hass" ];
        };

        # ===========================================================================
        # FULL-POWER MODELS (-full) - Optimized for Agentic Coding
        # ===========================================================================
        # Uses wyoming-wrapper script to stop Wyoming services and restart on exit
        # Parameters: temp 0.2, top-p 0.9, min-p 0.01 for precise yet creative code
        # GPT-OSS models use official OpenAI params: temp=1, top_p=1

        "qwen2.5-instruct-full" = {
          cmd = ''
            ${wyoming-wrapper} ${llama-cpp-cuda}/bin/llama-server \
              -hf Qwen/Qwen2.5-32B-Instruct-GGUF:Q5_K_M \
              --metrics \
              --host 0.0.0.0 \
              --port ''${PORT} \
              --temp 0.2 \
              --top-p 0.9 \
              --min-p 0.01 \
              -ngl 99 \
              -c 128000 \
              --cache-type-k q8_0 \
              --cache-type-v q8_0 \
              --flash-attn on \
              --batch-size 8192 \
              --ubatch-size 2048 \
              --jinja
          '';
          aliases = [ "qwen2.5-full" ];
        };

        "devstral-small-full" = {
          cmd = ''
            ${wyoming-wrapper} ${llama-cpp-cuda}/bin/llama-server \
              -hf unsloth/Devstral-Small-2-24B-Instruct-2512-GGUF:Q6_K_XL \
              --metrics \
              --host 0.0.0.0 \
              --port ''${PORT} \
              --temp 0.2 \
              --top-p 0.9 \
              --min-p 0.01 \
              -ngl 99 \
              -c 131072 \
              --cache-type-k q8_0 \
              --cache-type-v q8_0 \
              --flash-attn on \
              --batch-size 8192 \
              --ubatch-size 2048 \
              --jinja
          '';
          aliases = [ "devstral-full" ];
        };

        "nemotron-3-nano-full" = {
          cmd = ''
            ${wyoming-wrapper} ${llama-cpp-cuda}/bin/llama-server \
              -hf unsloth/Nemotron-3-Nano-30B-A3B-GGUF:Q8_0 \
              --metrics \
              --host 0.0.0.0 \
              --port ''${PORT} \
              --temp 0.2 \
              --top-p 0.9 \
              --min-p 0.01 \
              -ngl 99 \
              -c 220000 \
              --cache-type-k q8_0 \
              --cache-type-v q8_0 \
              --flash-attn on \
              --batch-size 8192 \
              --ubatch-size 2048 \
              --jinja
          '';
          aliases = [ "nemotron-full" ];
        };

        "qwen3-vl-32b-full" = {
          cmd = ''
            ${wyoming-wrapper} ${llama-cpp-cuda}/bin/llama-server \
              -hf unsloth/Qwen3-VL-30B-A3B-Instruct-GGUF:Q5_K_M \
              --metrics \
              --host 0.0.0.0 \
              --port ''${PORT} \
              --temp 0.2 \
              --top-p 0.9 \
              --min-p 0.01 \
              -ngl 99 \
              -c 131072 \
              --cache-type-k q8_0 \
              --cache-type-v q8_0 \
              --flash-attn on \
              --batch-size 2048 \
              --ubatch-size 1024 \
              --jinja
          '';
          aliases = [ "vision-full" "vl-full" ];
        };

        # GPT-OSS models use OpenAI recommended params: temp=1.0, top_p=1.0
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
              -ngl 99 \
              -c 131072 \
              --cache-type-k q8_0 \
              --cache-type-v q8_0 \
              --flash-attn on \
              --batch-size 8192 \
              --ubatch-size 2048 \
              --chat-template-kwargs '{"reasoning_effort": "high"}' \
              --jinja
          '';
          aliases = [ "gpt-oss-full" "gpt-oss-20b-full" ];
        };

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
              -ngl 99 \
              -ot ".ffn_(up|down)_exps.=CPU" \
              -c 131072 \
              --cache-type-k q8_0 \
              --cache-type-v q8_0 \
              --flash-attn on \
              --batch-size 8192 \
              --ubatch-size 2048 \
              --chat-template-kwargs '{"reasoning_effort": "high"}' \
              --jinja
          '';
          aliases = [ "gpt-oss-120b-full" ];
        };

        "glm-4.7-flash-full" = {
          cmd = ''
            ${wyoming-wrapper} ${llama-cpp-cuda}/bin/llama-server \
              -hf unsloth/GLM-4.7-Flash-GGUF:Q8_0 \
              --metrics \
              --host 0.0.0.0 \
              --port ''${PORT} \
              --temp 0.7 \
              --top-p 0.95 \
              --min-p 0.01 \
              --repeat-penalty 1.0 \
              -ngl 99 \
              -ot ".ffn_(up)_exps.=CPU" \
              -c 150000 \
              --flash-attn on \
              --batch-size 4096 \
              --ubatch-size 2048 \
              --jinja
          '';
          aliases = [ "glm-full" ];
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

        echo "wyoming-control: Listening on $FIFO"

        while read -r cmd pid < "$FIFO"; do
          case "$cmd" in
            stop)
              echo "wyoming-control: Stopping Wyoming services (requested by PID $pid)"
              /run/current-system/sw/bin/systemctl stop wyoming-faster-whisper-en || true
              /run/current-system/sw/bin/systemctl stop wyoming-faster-whisper-pt || true
              /run/current-system/sw/bin/systemctl stop wyoming-piper-en || true
              /run/current-system/sw/bin/systemctl stop wyoming-piper-pt || true
              echo "wyoming-control: Wyoming services stopped"
              ;;
            start)
              echo "wyoming-control: Starting Wyoming services (requested by PID $pid)"
              /run/current-system/sw/bin/systemctl start wyoming-faster-whisper-en || true
              /run/current-system/sw/bin/systemctl start wyoming-faster-whisper-pt || true
              /run/current-system/sw/bin/systemctl start wyoming-piper-en || true
              /run/current-system/sw/bin/systemctl start wyoming-piper-pt || true
              echo "wyoming-control: Wyoming services started"
              ;;
            *)
              echo "wyoming-control: Unknown command: $cmd" >&2
              ;;
          esac
        done
      ''}'";
      Restart = "on-failure";
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
      Environment = [
        "HOME=/var/lib/llama-cpp"
        "XDG_CACHE_HOME=/var/lib/llama-cpp/cache"
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
