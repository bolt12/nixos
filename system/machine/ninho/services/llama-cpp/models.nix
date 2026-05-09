# llama-swap model table.
#
# Imported from ../llama-cpp.nix; receives the wrappers and CUDA packages
# as plain values so each model entry stays trivially grep-able. Resist
# the urge to factor the repeated `--metrics --host 0.0.0.0 --port ${PORT}
# --flash-attn on --no-mmap` lines into a helper — readability of each
# concrete model wins over deduplication.
{
  wyoming-wrapper,
  whisper-wrapper,
  sd-wrapper,
  sd3-wrapper,
  llama-cpp-cuda,
  whisper-cpp-cuda,
  stable-diffusion-cpp-cuda,
  whisper-model-path,
  sd-model-dir,
  sd3-model-dir,
}:
{

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
    aliases = [
      "fim"
      "qwen-coder-fim"
    ];
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
    aliases = [
      "gpt-oss-full"
      "gpt-oss-20b-full"
    ];
  };

  # GPT-OSS 120B F16 - ~65GB base, MoE (5.1B active)
  # --n-cpu-moe N keeps the first N layers' MoE expert weights on CPU; gpt-oss-120b
  # has 36 layers, so 18 splits experts roughly half/half. Reduce on OOM, raise for
  # more VRAM headroom for KV cache.
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
        --n-cpu-moe 18 \
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

  # Qwen3.5-27B Creative - instruct mode (no reasoning), Unsloth instruct-general params
  "qwen3.5-27B-creative" = {
    cmd = ''
      ${wyoming-wrapper} ${llama-cpp-cuda}/bin/llama-server \
        -hf unsloth/Qwen3.5-27B-GGUF:Q6_K \
        --metrics \
        --host 0.0.0.0 \
        --port ''${PORT} \
        --temp 0.7 \
        --top-p 0.8 \
        --top-k 20 \
        --min-p 0.0 \
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
        --chat-template-kwargs '{"preserve_thinking": true}' \
        --jinja
    '';
    aliases = [ "qwen3.6-35B-A3B-full" ];
  };

  # Qwen3.6 27B (262K native context)
  "qwen3.6-27B-full" = {
    cmd = ''
      ${wyoming-wrapper} ${llama-cpp-cuda}/bin/llama-server \
        -hf unsloth/Qwen3.6-27B-GGUF:Q5_K_M \
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
        --chat-template-kwargs '{"preserve_thinking": true}' \
        --jinja
    '';
    aliases = [ "qwen3.6-27B-full" ];
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

  # Gemma 4 31B Dense — thinking mode enabled via chat-template kwarg.
  # Emits <|channel>thought\n...<channel|> blocks before final answers.
  "gemma-4-31B-thinking" = {
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
        --chat-template-kwargs '{"enable_thinking": true}' \
        --jinja
    '';
    aliases = [ "gemma-4-31B-thinking" ];
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
    aliases = [
      "rerank"
      "jina-reranker"
    ];
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
    aliases = [
      "whisper"
      "whisper-v3"
      "transcription"
    ];
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
    aliases = [
      "image"
      "flux"
      "image-generation"
    ];
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
    aliases = [
      "sd3"
      "sd3.5-medium"
    ];
  };
}
