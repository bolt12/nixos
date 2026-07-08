# llama-swap orchestrator + 9 model definitions (see llama-cpp/models.nix).
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
    writeShellScript
    ;

  # llama-swap configuration - RTX 5090 (32GB VRAM), 128GB RAM
  # Models optimized for quality/context balance
  # Note: llama-cpp-cuda is now defined in system/common/overlays.nix

  # Wrapper script for full-power models - stops Sunshine, restarts on exit
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
    # Bind to all interfaces (module default is "localhost"); needed so
    # Open WebUI / other LAN clients can reach the proxy, not just ninho itself.
    listenAddress = "0.0.0.0";

    settings = {
      # Health check timeout - set high to allow large model downloads
      # (gpt-oss-120b F16 is ~65GB on first load)
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
      # Default idle TTL: llama-swap unloads a model after 15 min of inactivity
      # so it stops squatting on VRAM. A pinned model was holding ~31GB of the
      # 32GB card indefinitely, starving Immich's GPU machine-learning (CUDA
      # OOM). A model can set its own `ttl` to override this default.
      models =
        let
          rawModels = import ./llama-cpp/models.nix {
            inherit
              wyoming-wrapper
              llama-cpp-cuda
              ;
          };
        in
        builtins.mapAttrs (_name: model: { ttl = 900; } // model) rawModels;

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
                /run/current-system/sw/bin/systemctl --user -M bolt@ stop sunshine || true
                ;;
              start)
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
    # ffprobe/ffmpeg on PATH so llama.cpp's mtmd multimodal helper can demux
    # VIDEO inputs (mtmd_helper_video_init_from_buf shells out to ffprobe). The
    # llama-server children inherit this service's PATH.
    path = [ pkgs.ffmpeg-headless ];

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

      # Restore full /proc visibility: upstream module sets ProcSubset=pid,
      # which hides /proc/meminfo and breaks llama-swap's sys-stats polling
      # ("couldn't read /proc/meminfo: no such file or directory").
      ProcSubset = lib.mkForce "all";

      # Increase timeouts for large model downloads (up to 142GB!)
      TimeoutStartSec = "infinity"; # No timeout during download
      TimeoutStopSec = "30s";
    };
  };

  # Add llama-cpp-cuda to system packages for manual testing
  environment.systemPackages = [ llama-cpp-cuda ];
}
