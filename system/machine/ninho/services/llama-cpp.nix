{ config, pkgs, lib, constants, ... }:
let
  inherit (constants) ports;
  inherit (pkgs) llama-cpp-cuda;

  # llama-swap configuration - RTX 5090 (30GB VRAM), 128GB RAM
  # Models optimized for quality/context balance
  # Note: llama-cpp-cuda is now defined in system/common/overlays.nix

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
        # Devstral 24B Q8 - 25.1GB, 128k context - Coding tier
        "devstral-24b" = {
          cmd = ''
            ${llama-cpp-cuda}/bin/llama-server \
              -hf unsloth/Devstral-Small-2-24B-Instruct-2512-GGUF:Q4_K_XL \
              --metrics \
              --host 0.0.0.0 \
              --port ''${PORT}
              -ngl 99 \
              -c 200000 \
              --min_p 0.01 \
              --temp 0.15 \
              --top-p 0.8 \
              --top-k 64 \
              --cache-type-k q5_1 \
              --cache-type-v q5_1 \
              --flash-attn on \
              --batch-size 8192 \
              --ubatch-size 1024 \
              --jinja \
          '';
          aliases = [ "devstral" "code" "coding" ];
        };

        # Seed OSS MXFP4 - 20GB, 180k context
        "seed-oss-mxfp4" = {
          cmd = ''
            ${llama-cpp-cuda}/bin/llama-server \
              -hf magiccodingman/Seed-OSS-36B-Instruct-unsloth-MagicQuant-Hybrid-GGUF:MXFP4_MOE
              --metrics \
              --host 0.0.0.0 \
              --port ''${PORT} \
              --min_p 0.01 \
              --temp 0.7 \
              --top-p 0.8 \
              --top-k 20 \
              --repeat-penalty 1.05 \
              --reasoning-budget 2048 \
              -ngl 99 \
              -c 120000 \
              --cache-type-k q5_1\
              --cache-type-v q5_1 \
              --flash-attn on \
              --batch-size 8192 \
              --ubatch-size 1024 \
              --jinja \
          '';
          aliases = [ "seed-oss" ];
        };

        # Qwen3-Coder Q6_K - 25.1GB, 220k context - MoE Speed tier (3.2B active)
        "qwen3-coder" = {
          cmd = ''
            ${llama-cpp-cuda}/bin/llama-server \
              -hf unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF:Q8_0 \
              --metrics \
              --host 0.0.0.0 \
              --port ''${PORT} \
              --min_p 0.01 \
              --temp 0.7 \
              --top-p 0.8 \
              --top-k 20 \
              --repeat-penalty 1.05 \
              -ngl 99 \
              -ot ".ffn_(up)_exps.=CPU" \
              -c 200000 \
              -n 65536 \
              --flash-attn on \
              --batch-size 8192 \
              --ubatch-size 1024 \
              --jinja \
          '';
          aliases = [ "qwen3-coder" ];
        };

        # Nemotron 3 Nano 30B Q8 - 33.6GB, 220k context - MoE Speed tier (3.2B active)
        "nemotron-3-nano" = {
          cmd = ''
            ${llama-cpp-cuda}/bin/llama-server \
              -hf unsloth/Nemotron-3-Nano-30B-A3B-GGUF:Q8_0 \
              --metrics \
              --host 0.0.0.0 \
              --port ''${PORT} \
              --min_p 0.01 \
              --temp 0.6 \
              --top-p 0.8 \
              -ngl 99 \
              -ot ".ffn_(up)_exps.=CPU" \
              -c 200000 \
              --flash-attn on \
              --batch-size 8192 \
              --ubatch-size 1024 \
              --jinja \
          '';
          aliases = [ "nemotron-3-nano" ];
        };

        # Qwen3 VL 32B Q5 - 21.7GB, 128k context - Vision/multimodal tier
        "qwen3-vl-32b" = {
          cmd = ''
            ${llama-cpp-cuda}/bin/llama-server \
              -hf unsloth/Qwen3-VL-30B-A3B-Instruct-GGUF:Q5_K_M \
              --metrics \
              --host 0.0.0.0 \
              --port ''${PORT} \
              -ngl 30 \
              -c 131072 \
              --cache-type-k q8_0 \
              --cache-type-v q8_0 \
              --batch-size 1536 \
              --ubatch-size 512 \
              --flash-attn on \
              --jinja \
          '';
          aliases = [ "vision" "vl" "multimodal" "qwen-vl" ];
        };

        # GPT-OSS 20B F16 - 12.1GB, 132k context - Power MoE (21b/3.6B active, FP16 KV)
        "gpt-oss-20b" = {
          cmd = ''
            ${llama-cpp-cuda}/bin/llama-server \
              -hf unsloth/gpt-oss-20b-GGUF:F16 \
              --metrics \
              --host 0.0.0.0 \
              --port ''${PORT} \
              --min_p 0.01 \
              --temp 0.6 \
              --top-p 0.8 \
              -ngl 99 \
              -c 131072 \
              --batch-size 8192 \
              --ubatch-size 1024 \
              --flash-attn on \
              --chat-template-kwargs '{"reasoning_effort": "high"}' \
              --jinja \
          '';
          aliases = [ "gpt-oss-20b" ];
        };

        # GPT-OSS 120B F16 - 65.4GB, 100k context - Power MoE (117b/5.1B active, FP8 KV)
        # -ot ".ffn_.*_exps.=CPU"        - Less VRAM
        # -ot ".ffn_(up|down)_exps.=CPU" - More VRAM
        # -ot ".ffn_(up)_exps.=CPU"      - Even more VRAM
        "gpt-oss-120b" = {
          cmd = ''
            ${llama-cpp-cuda}/bin/llama-server \
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
              --batch-size 8192 \
              --ubatch-size 1024 \
              --flash-attn on \
              --chat-template-kwargs '{"reasoning_effort": "high"}' \
              --jinja \
          '';
          aliases = [ "gpt-oss-120b" ];
        };
      };
    };
  };

  # Create directory for models and cache
  systemd.tmpfiles.rules = [
    "d /var/lib/llama-cpp 0755 llama-swap llama-swap - -"
    "d /var/lib/llama-cpp/models 0755 llama-swap llama-swap - -"
    "d /var/lib/llama-cpp/cache 0755 llama-swap llama-swap - -"
  ];

  # Fix llama-cpp cache directory + increase timeouts
  systemd.services.llama-swap = {
    serviceConfig = {
      # Set environment variables for llama-cpp cache and API keys
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
