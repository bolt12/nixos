{ config, pkgs, lib, constants, ... }:
let
  inherit (constants) ports;
  inherit (pkgs) llama-cpp-cuda writeShellScript;

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

        z-ai = {
          proxy = "https://api.z.ai/api/anthropic";
          apiKey = "";
          models = [
            "GLM-5"
            "GLM-4.7"
            "GLM-4.5"
            "GLM-4.5-Air"
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

        # GLM 4.7 Flash REAP Q8_0 - ~15GB base (ONLY hass model to keep)
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
          aliases = [ "glm-4.7-flash-hass" ];
        };

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

        # Nemotron 3 Nano 30B Q8_0 - ~20GB base, MoE (3B active)
        "nemotron-3-nano-full" = {
          cmd = ''
            ${wyoming-wrapper} ${llama-cpp-cuda}/bin/llama-server \
              -hf unsloth/Nemotron-3-Nano-30B-A3B-GGUF:Q8_0 \
              --metrics \
              --host 0.0.0.0 \
              --port ''${PORT} \
              --temp 0.6 \
              --top-p 0.95 \
              --min-p 0.01 \
              -fit on \
              --fit-ctx 180000 \
              --fit-target 256 \
              --no-mmap \
              --flash-attn on \
              --batch-size 8192 \
              --ubatch-size 2048 \
              --jinja
          '';
          aliases = [ "nemotron-full" ];
        };

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

        "step-3.5-flash-full" = {
          cmd = ''
            ${wyoming-wrapper} ${llama-cpp-cuda}/bin/llama-server \
              -hf stepfun-ai/Step-3.5-Flash-Int4:Q4_K_S \
              --metrics \
              --host 0.0.0.0 \
              --port ''${PORT} \
              --temp 1.0 \
              --top-p 0.95 \
              --top-k 40 \
              --min-p 0.01 \
              -fit on \
              --fit-ctx 120000 \
              --fit-target 256 \
              --cache-type-k q8_0 \
              --cache-type-v q8_0 \
              --no-mmap \
              --flash-attn on \
              --batch-size 4096 \
              --ubatch-size 2048 \
              --jinja
          '';
          aliases = [ "step-3.5-flash-full" ];
        };

        # Qwen3 Coder Next - ~1.6B? REAM - Best coding model
        "qwen3-coder-next-full" = {
          cmd = ''
            ${wyoming-wrapper} ${llama-cpp-cuda}/bin/llama-server \
              -hf mradermacher/Qwen3-Coder-Next-REAM-GGUF:Q4_K_M \
              --metrics \
              --host 0.0.0.0 \
              --port ''${PORT} \
              --temp 1.0 \
              --top-p 0.95 \
              --top-k 40 \
              --min-p 0.01 \
              --repeat-penalty 1.1 \
              -fit on \
              --fit-ctx 180000 \
              --fit-target 128 \
              --flash-attn on \
              --batch-size 4096 \
              --ubatch-size 2048 \
              --no-mmap \
              --jinja
          '';
          aliases = [ "qwen3-coder-next-full" ];
        };

        # GLM-4.7-Flash Q8_0 - ~15GB base
        "glm-4.7-flash-full" = {
          cmd = ''
            ${wyoming-wrapper} ${llama-cpp-cuda}/bin/llama-server \
              -hf unsloth/GLM-4.7-Flash-GGUF:Q8_0 \
              --metrics \
              --host 0.0.0.0 \
              --port ''${PORT} \
              --temp 0.7 \
              --top-p 1.0 \
              --min-p 0.01 \
              --repeat-penalty 1.0 \
              -fit on \
              --fit-ctx 180000 \
              --fit-target 256 \
              --flash-attn on \
              --batch-size 4096 \
              --ubatch-size 2048 \
              --no-mmap \
              --chat-template-kwargs '{"reasoning_effort": "high"}' \
              --jinja
          '';
          aliases = [ "glm-full" ];
        };

        # GLM-4.7-Flash Creative - ~15GB base, temp=1.0 for more creative output
        "glm-4.7-flash-full-creative" = {
          cmd = ''
            ${wyoming-wrapper} ${llama-cpp-cuda}/bin/llama-server \
              -hf unsloth/GLM-4.7-Flash-GGUF:Q8_0 \
              --metrics \
              --host 0.0.0.0 \
              --port ''${PORT} \
              --temp 1.0 \
              --top-p 0.95 \
              --min-p 0.01 \
              --repeat-penalty 1.0 \
              -fit on \
              --fit-ctx 202752 \
              --fit-target 256 \
              --no-mmap \
              --flash-attn on \
              --batch-size 8192 \
              --ubatch-size 2048 \
              --jinja
          '';
          aliases = [ "glm-full-creative" ];
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
                ;;
              start)
                /run/current-system/sw/bin/systemctl start wyoming-faster-whisper-en || true
                /run/current-system/sw/bin/systemctl start wyoming-faster-whisper-pt || true
                /run/current-system/sw/bin/systemctl start wyoming-piper-en || true
                /run/current-system/sw/bin/systemctl start wyoming-piper-pt || true
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
