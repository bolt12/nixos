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

  # Single source of truth for the control FIFO: referenced by both wrappers, the
  # helper service, and the tmpfiles rule that creates it.
  controlFifo = "/run/gpu-tenant-control";

  # Derived from services/frigate.nix: oci-containers with the docker backend
  # names its units docker-<container>.service. Switching that backend renames
  # the unit, and every call here is `|| true`, so a stale name would fail
  # silently and simply never free Frigate's VRAM.
  frigateUnit = "docker-frigate.service";

  # Wrapper scripts for full-power models - free GPU tenants while the model is
  # resident. Uses a FIFO-based helper because llama-swap runs unprivileged with
  # all capabilities dropped and so cannot stop system services itself.
  #
  # The wrapper names the tenants it needs freed, rather than naming a verb that
  # stands for a fixed set. A new tenant is then one stop_/start_ pair in the
  # helper plus one list element here: no new protocol verb, no new case arm.
  #
  # Restore is the helper's job, not this script's. It watches the PID sent below
  # and restores once the process is gone, which is the only thing that survives
  # llama-swap SIGKILLing the wrapper. An EXIT trap here cannot be relied on: its
  # FIFO write blocks on a reader and llama-swap kills the wrapper first, so the
  # trap was observed never to complete. The trap that remains exists purely to
  # forward signals to llama-server so unloads are graceful.
  mkGpuWrapper =
    name: tenants:
    writeShellScript name ''
      set -euo pipefail

      echo "stop $$ ${lib.concatStringsSep " " tenants}" > "${controlFifo}"

      # Run llama-server in background so we can trap signals
      "$@" &
      CHILD_PID=$!

      # Forward termination signals to the child process
      trap 'kill $CHILD_PID 2>/dev/null; wait $CHILD_PID 2>/dev/null' EXIT TERM INT HUP

      # Wait for child to complete
      wait $CHILD_PID
    '';

  # The default for every model.
  gpu-tenant-wrapper = mkGpuWrapper "gpu-tenant-wrapper" [ "sunshine" ];

  # Additionally frees Frigate's ~1.85 GiB (detector ~976 MiB + embeddings ~878
  # MiB), which `-fit on` then spends on a materially larger context. Costs camera
  # detection and Frigate's HTTP API for as long as the model stays resident, so
  # only models that need the headroom should use this one. Note this frees the
  # two tenants we can cheaply stop, NOT every GPU consumer: Immich ML and
  # Jellyfin's NVENC also hold memory and are left alone.
  gpu-tenant-wrapper-frigate = mkGpuWrapper "gpu-tenant-wrapper-frigate" [
    "sunshine"
    "frigate"
  ];

  # froggeric's fixed Qwen chat template (v22), used by the qwen3.8 entry. The
  # official Qwen3.8 template throws a fatal exception on enable_thinking=false,
  # prepends blank <think></think> blocks to history, and crashes on JSON-string
  # tool arguments; this one fixes those and renders history chronologically so
  # the prefix cache actually hits.
  #
  # Pinned to a revision rather than `main`: the repo is actively updated, and a
  # `main` URL would silently change content under a fixed hash.
  qwenChatTemplate = pkgs.fetchurl {
    url = "https://huggingface.co/froggeric/Qwen-Fixed-Chat-Templates/resolve/9f14778c92c3b5ed3e0738085694c0d3452802dd/chat_template.jinja";
    hash = "sha256-OY7fW1u4AvtrnJqNumcNCfKq7vb9yqCyyjByZfWfeNw=";
  };

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
              gpu-tenant-wrapper
              gpu-tenant-wrapper-frigate
              llama-cpp-cuda
              qwenChatTemplate
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
    # FIFO for GPU tenant control (avoids sudo from within llama-swap)
    "p ${controlFifo} 0660 llama-swap root - -"
  ];

  # Frees GPU tenants on request from llama-swap's model wrappers, which cannot do
  # it themselves (they run unprivileged with all capabilities dropped). Runs as
  # root and takes commands over a FIFO.
  systemd.services.gpu-tenant-control = {
    description = "GPU tenant control helper for llama-swap";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    # util-linux for waitpid, systemd.package so systemctl matches the running
    # daemon. Declared here rather than pinned by hand inside the script.
    path = [
      pkgs.util-linux
      config.systemd.package
    ];

    serviceConfig = {
      Type = "simple";
      ExecStart = writeShellScript "gpu-tenant-control-helper" ''
        set -euo pipefail

        stop_sunshine()  { systemctl --user -M bolt@ stop  sunshine || true; }
        start_sunshine() { systemctl --user -M bolt@ start sunshine || true; }

        stop_frigate()  { systemctl stop  ${frigateUnit} || true; }
        start_frigate() { systemctl start ${frigateUnit} || true; }

        # The tenants a wrapper is allowed to name. Dispatch below resolves
        # "stop_$svc" to a function, and the writer is unprivileged while this
        # runs as root, so the set stays closed here rather than trusted.
        known_tenant() {
          case "$1" in
            sunshine | frigate) return 0 ;;
            *) echo "gpu-tenant-control: unknown tenant: $1" >&2; return 1 ;;
          esac
        }

        # The only restore path. The wrapper has no EXIT-trap restore: that write
        # blocks on a reader and llama-swap kills the wrapper first, so it was
        # observed never to complete. Watching the PID survives SIGKILL.
        #
        # waitpid blocks on a pidfd rather than polling, which matters because the
        # watched process is NOT our child (the wrapper is llama-swap's), so plain
        # `wait` cannot see it. --exited makes an already-dead PID return success
        # instead of erroring, covering the model dying before we get here.
        #
        # Callers must redirect from /dev/null, or this backgrounded watcher
        # inherits the loop's read end of the FIFO and holds it open for the
        # model's entire lifetime.
        restore_on_exit() {
          local pid="$1"; shift
          [[ -n "$pid" ]] || return 0
          waitpid --exited "$pid" >/dev/null 2>&1 || true
          local svc
          for svc in "$@"; do "start_$svc"; done
        }

        # Double-loop pattern: the inner loop reads until the writer closes
        # (EOF), then the outer loop re-opens the FIFO for the next writer.
        # Without this, a single writer closing causes the while-read to exit.
        while true; do
          while read -r cmd pid tenants; do
            case "$cmd" in
              stop)
                wanted=""
                for svc in $tenants; do
                  known_tenant "$svc" && wanted="$wanted $svc"
                done
                # word-splitting $wanted is intended: it is a vetted name list
                # shellcheck disable=SC2086
                restore_on_exit "$pid" $wanted </dev/null &
                for svc in $wanted; do "stop_$svc"; done
                ;;
              *)
                echo "gpu-tenant-control: Unknown command: $cmd" >&2
                ;;
            esac
          done < "${controlFifo}"
        done
      '';
      Restart = "always";
      RestartSec = 0;
      # This service runs as root to control system services
      User = "root";
    };
  };

  # Configure llama-swap service
  systemd.services.llama-swap = {
    # Every model wrapper opens the control FIFO for writing before exec'ing
    # llama-server, and opening a FIFO for write BLOCKS until a reader appears.
    # With no reader the load hangs until llama-swap's 3600s health check gives
    # up. Ordering after the helper closes that window at boot and across a
    # switch. `wants` rather than `requires`: the helper is Restart=always, and
    # stopping it should not tear down llama-swap with it.
    after = [ "gpu-tenant-control.service" ];
    wants = [ "gpu-tenant-control.service" ];

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
