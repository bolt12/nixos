{ config, pkgs, inputs, ... }:
let
  # Overlay to update Ollama to latest version
  ollamaOverlay = import ../ollama-overlay.nix;

  # Import unstable packages for latest ollama with overlay
  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs) system;
    overlays = [ ollamaOverlay ];
    config.allowUnfree = true;
  };

  # Define modelfiles with custom parameters
  modelfiles = {
    # Thinking models - optimized for reasoning tasks
    "qwen3-vl-thinking" = pkgs.writeText "qwen3-vl-thinking.modelfile" ''
      FROM qwen3-vl:32b-thinking-q4_K_M

      # Thinking mode settings (enable_thinking=True)
      PARAMETER temperature 0.6
      PARAMETER top_p 0.95
      PARAMETER top_k 20
      PARAMETER min_p 0

      # Extended output for complex math/programming problems
      PARAMETER num_predict 38912

      # Reduce repetitions without degrading performance
      PARAMETER repeat_penalty 1.05
    '';

    "deepseek-r1-70b" = pkgs.writeText "deepseek-r1-70b.modelfile" ''
      FROM deepseek-r1:70b-llama-distill-q4_K_M

      # Thinking mode settings for reasoning model
      PARAMETER temperature 0.6
      PARAMETER top_p 0.95
      PARAMETER top_k 20
      PARAMETER min_p 0

      # Extended output for complex math/programming problems
      PARAMETER num_predict 38912

      PARAMETER repeat_penalty 1.05
    '';

    "deepseek-r1-32b" = pkgs.writeText "deepseek-r1-32b.modelfile" ''
      FROM deepseek-r1:32b-qwen-distill-q4_K_M

      # Thinking mode settings for reasoning model
      PARAMETER temperature 0.6
      PARAMETER top_p 0.95
      PARAMETER top_k 20
      PARAMETER min_p 0

      # Extended output for complex math/programming problems
      PARAMETER num_predict 38912

      PARAMETER repeat_penalty 1.05
    '';

    "qwen3-thinking" = pkgs.writeText "qwen3-thinking.modelfile" ''
      FROM qwen3:30b-a3b-thinking-2507-q4_K_M

      # Thinking mode settings (enable_thinking=True)
      PARAMETER temperature 0.6
      PARAMETER top_p 0.95
      PARAMETER top_k 20
      PARAMETER min_p 0

      # Extended output for complex math/programming problems
      PARAMETER num_predict 38912

      PARAMETER repeat_penalty 1.05
    '';

    # Non-thinking models - standard conversation/coding
    "gpt-oss-optimized" = pkgs.writeText "gpt-oss-optimized.modelfile" ''
      FROM gpt-oss:120b

      # Non-thinking mode settings (enable_thinking=False)
      PARAMETER temperature 0.7
      PARAMETER top_p 0.8
      PARAMETER top_k 20
      PARAMETER min_p 0

      # Standard output length
      PARAMETER num_predict 32768

      PARAMETER repeat_penalty 1.05
    '';

    "qwen3-coder-optimized" = pkgs.writeText "qwen3-coder-optimized.modelfile" ''
      FROM qwen3-coder:30b-a3b-q4_K_M

      # Non-thinking mode settings for coding
      PARAMETER temperature 0.7
      PARAMETER top_p 0.8
      PARAMETER top_k 20
      PARAMETER min_p 0

      # Extended output for complex programming problems
      PARAMETER num_predict 38912

      PARAMETER repeat_penalty 1.05
    '';
  };

  # Create a script that sets up all models
  setupModelsScript = pkgs.writeShellScript "setup-ollama-models" ''
    set -e
    export OLLAMA_HOST="http://localhost:11434"

    echo "Starting Ollama model setup..."
    echo "Checking connectivity to Ollama at $OLLAMA_HOST"

    # First check if ollama is listening on the port
    MAX_RETRIES=30
    RETRY_COUNT=0

    while ! ${pkgs.curl}/bin/curl -sf "$OLLAMA_HOST/api/tags" > /dev/null; do
      if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo "ERROR: Timeout waiting for Ollama API after 60 seconds"
        echo "Ollama may not be running or not accessible at $OLLAMA_HOST"
        exit 1
      fi
      echo "Waiting for Ollama API to be ready... (attempt $((RETRY_COUNT + 1))/$MAX_RETRIES)"
      sleep 2
      RETRY_COUNT=$((RETRY_COUNT + 1))
    done

    echo "✓ Ollama API is responding"
    echo "Creating custom models from modelfiles..."

    ${pkgs.lib.concatStringsSep "\n" (pkgs.lib.mapAttrsToList (name: modelfile: ''
      echo "  → Creating model: ${name}"
      if ${unstable.ollama}/bin/ollama create ${name} -f ${modelfile} 2>&1 | grep -v "already exists"; then
        echo "    ✓ Model ${name} created successfully"
      else
        echo "    ℹ Model ${name} already exists or failed to create"
      fi
    '') modelfiles)}

    echo "✓ All models configured successfully"
  '';
in
{
  # Disable the stable service
  disabledModules = [ "${inputs.nixpkgs}/nixos/modules/services/misc/open-webui.nix" ];
  # Get the unstable service version
  imports = [
    "${inputs.nixpkgs-unstable}/nixos/modules/services/misc/open-webui.nix"
  ];

  services = {
    ollama = {
      enable = true;
      package = unstable.ollama;
      acceleration = "cuda";  # RTX 5090
      host = "0.0.0.0";
      port = 11434;
    };

    open-webui = {
      enable = true;
      package = unstable.open-webui;
      openFirewall = true;
      host = "0.0.0.0";  # Listen on all interfaces
      port = 8080;
    };
  };


  # Ensure GPU is ready
  systemd.services.ollama = {
    after = [ "nvidia-persistenced.service" ];
    requires = [ "nvidia-persistenced.service" ];
  };

  # Setup models from modelfiles after ollama starts
  systemd.services.ollama-setup-models = {
    description = "Setup Ollama models from modelfiles";
    after = [ "ollama.service" "network.target" ];
    wants = [ "ollama.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${setupModelsScript}";
      User = "ollama";
      Group = "ollama";
      TimeoutStartSec = "5min";
    };
  };
}
