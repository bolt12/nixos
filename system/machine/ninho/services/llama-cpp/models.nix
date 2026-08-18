# llama-swap model table.
#
# Imported from ../llama-cpp.nix; receives the wrappers and CUDA packages
# as plain values so each model entry stays trivially grep-able. Resist
# the urge to factor the repeated `--metrics --host 0.0.0.0 --port ${PORT}
# --flash-attn on --no-mmap` lines into a helper: readability of each
# concrete model wins over deduplication.
{
  gpu-tenant-wrapper,
  gpu-tenant-wrapper-frigate,
  llama-cpp-cuda,
  qwenChatTemplate,
}:
{

  # ===========================================================================
  # FULL-POWER MODELS (-full) - Optimized for Agentic Coding
  # ===========================================================================
  # Each entry runs under a gpu-tenant-* wrapper that frees GPU tenants while the
  # model is resident (see llama-cpp.nix); which tenants depends on the wrapper.
  # Parameters: temp 0.2, top-p 0.9, min-p 0.01 for precise yet creative code
  # GPT-OSS models use official OpenAI params: temp=1, top_p=1

  # GPT-OSS 20B F16 - ~15GB base, MoE (3.6B active)
  "gpt-oss-20b-full" = {
    cmd = ''
      ${gpu-tenant-wrapper} ${llama-cpp-cuda}/bin/llama-server \
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
      ${gpu-tenant-wrapper} ${llama-cpp-cuda}/bin/llama-server \
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

  # Qwen3.6 35B A3B MoE (~3B active, 262K native context)
  # MTP speculative decoding: --spec-type draft-mtp requires the -MTP-GGUF
  # variant (carries the multi-token-prediction head) and --no-mmproj (the MTP
  # repos ship an auto-download mmproj that's incompatible with MTP and wastes
  # ~1GB VRAM).
  # --parallel 1 is a CHOICE here, not a requirement: MTP was single-stream when
  # this was written, but on build 10408 it loads fine with more slots (measured
  # --parallel 2 and 4). One slot keeps the whole context in one place; more slots
  # divide it but let concurrent agents run without evicting each other (4 agents:
  # 6.5s vs 10.8s wall). Note --parallel 1 also opts out of the unified KV buffer,
  # which llama.cpp enables when the slot count is left at its -1 default.
  # --spec-default layers ngram-mod on top of MTP (per ggerganov's recommendation
  # in the Qwen3.6 appreciation thread); makes edits/verbatim copies near-instant.
  # Expected ~1.5-2x speedup.
  "qwen3.6-35B-A3B-full" = {
    cmd = ''
      ${gpu-tenant-wrapper} ${llama-cpp-cuda}/bin/llama-server \
        -hf unsloth/Qwen3.6-35B-A3B-MTP-GGUF:MXFP4_MOE \
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
        --parallel 1 \
        --no-mmproj \
        --spec-type draft-mtp \
        --spec-draft-n-max 2 \
        --spec-default \
        --chat-template-kwargs '{"preserve_thinking": true}' \
        --jinja
    '';
    aliases = [ "qwen3.6-35B-A3B-full" ];
  };

  # Qwen3.8 27B. Split into -full (interactive, long context) and -vision (batch
  # captioning) because the two need different GPU tenants alive, NOT because of
  # the MTP/mmproj conflict that forced the 3.6 split. See the -vision entry.
  #
  # gpu-tenant-wrapper-frigate (not the plain one) also stops Frigate, whose detector
  # and embedding models hold ~1.85 GiB. Camera detection is down while this model
  # is resident, which is why pet-report gets its own entry below.
  #
  # The architecture is HYBRID: only 16 of 64 layers carry KV (every 4th), the rest
  # are recurrent SSM. That is why a 27B model reaches six-figure contexts at all,
  # and why the flags below differ from the dense 3.6-27B entry.
  #
  # --fit-target 2048, NOT the 6144 that entry needs: 6144 covers a dense model's
  # spec-decode compute spike, which this hybrid does not have, so the margin is
  # pure lost context (6144 -> 150784 ctx, 2048 -> 258560, at identical throughput).
  # Do not go below 1024: -fit does not account for the MTP draft context, and 512
  # OOM'd outright. Context is left to -fit rather than pinned with -c so that it
  # re-measures free VRAM per load and shrinks rather than failing when Immich's
  # GPU models are resident.
  #
  # --cache-ram 32768 is what makes multi-agent workflows viable, and the 8192 MiB
  # default is a cliff, not a slope: agents taking turns on one slot spill to host
  # RAM on eviction, and once the working set exceeds the cap EVERY turn reprocesses
  # that agent's whole history. Measured with 3 agents at ~88k tokens: 792k tokens
  # reprocessed at the default vs 264k above it, 2.8x wall-clock. 32768 keeps the
  # cliff beyond three agents each filling the context (~22 GiB). It is a cap, not
  # a reservation.
  #
  # Do NOT "improve" this to -1. There are two limits (server-task.cpp update()):
  # a byte limit, and a token limit that floors at n_ctx but is RAISED to whatever
  # fits the byte budget. -1 zeroes the byte limit, which drops the token limit
  # back to its n_ctx floor: "no limit" yields ~n_ctx tokens of cache, a quarter
  # of what an explicit 32768 buys. Bigger number, smaller cache.
  #
  # --parallel 1 was measured against the alternatives and wins. Extra slots do not
  # reduce reprocessing (--cache-ram already covers that) and cost context: 3 slots
  # gave 50176 each vs 202496 for one. --kv-unified restores full context per
  # sequence but ran 2x slower, the penalty llama.h documents for sequences that do
  # not share a prefix. --cache-reuse changed nothing measurable.
  "qwen3.8-27B-full" = {
    cmd = ''
      ${gpu-tenant-wrapper-frigate} ${llama-cpp-cuda}/bin/llama-server \
        -hf unsloth/Qwen3.8-27B-GGUF:Q5_K_M \
        --metrics \
        --host 0.0.0.0 \
        --port ''${PORT} \
        --temp 1.0 \
        --top-p 0.95 \
        --top-k 20 \
        --min-p 0.0 \
        --presence-penalty 0.0 \
        --repeat-penalty 1.0 \
        -n 32768 \
        -fit on \
        --fit-target 2048 \
        --flash-attn on \
        --cache-type-k q8_0 \
        --cache-type-v q8_0 \
        --cache-ram 32768 \
        --no-mmap \
        --parallel 1 \
        --no-mmproj \
        --spec-type draft-mtp \
        --spec-draft-n-max 2 \
        --spec-default \
        --chat-template-file ${qwenChatTemplate} \
        --reasoning-format deepseek \
        --chat-template-kwargs '{"preserve_thinking": true, "reasoning_effort": "xhigh"}' \
        --jinja
    '';
    aliases = [ "qwen3.8-27B-full" ];
  };

  # Qwen3.8 27B for the camera pipeline. Same model and template as -full; the
  # differences are all about coexisting with Frigate rather than displacing it:
  #  - plain gpu-tenant-wrapper, so Frigate STAYS UP. pet-report reads Frigate's HTTP
  #    API for events and snapshots, so a wrapper that stopped Frigate would kill
  #    the service feeding it.
  #  - -c 32768 pinned: captioning a snapshot needs nothing like the -full entry's
  #    ~258K, and the small KV leaves room to sit alongside Frigate's ~1.85 GiB.
  #    Pinned rather than left to -fit because this entry shares the card with
  #    Frigate, so a fit-chosen context would swing with whatever Frigate is doing.
  #  - --image-min-tokens 1024: llama.cpp warns at load that Qwen-VL needs at least
  #    1024 image tokens to be reliable on grounding tasks, which is exactly what
  #    pet-report does (telling one animal from another).
  #  - reasoning_effort low: this is an unattended batch job over many frames, so
  #    the xhigh steering the -full entry wants is just latency here.
  "qwen3.8-27B-vision" = {
    cmd = ''
      ${gpu-tenant-wrapper} ${llama-cpp-cuda}/bin/llama-server \
        -hf unsloth/Qwen3.8-27B-GGUF:Q5_K_M \
        --metrics \
        --host 0.0.0.0 \
        --port ''${PORT} \
        --temp 1.0 \
        --top-p 0.95 \
        --top-k 20 \
        --min-p 0.0 \
        --presence-penalty 0.0 \
        --repeat-penalty 1.0 \
        -n 32768 \
        -c 32768 \
        -fit off \
        -ngl 99 \
        --image-min-tokens 1024 \
        --flash-attn on \
        --cache-type-k q8_0 \
        --cache-type-v q8_0 \
        --no-mmap \
        --parallel 1 \
        --spec-type draft-mtp \
        --spec-draft-n-max 2 \
        --spec-default \
        --chat-template-file ${qwenChatTemplate} \
        --reasoning-format deepseek \
        --chat-template-kwargs '{"preserve_thinking": true, "reasoning_effort": "low"}' \
        --jinja
    '';
    aliases = [
      "qwen3.8-27B-vision"
      "qwen-vision"
      "vision"
    ];
  };

  # Qwen3.6 35B A3B with VISION enabled (mmproj), for the camera report pipeline.
  # Same base model as qwen3.6-35B-A3B-full but the NON-MTP GGUF: MTP speculative
  # decoding is incompatible with an mmproj, so this entry drops the MTP flags and
  # loads the vision projector instead. The unsloth non-MTP repo ships the mmproj
  # (auto-downloaded by -hf; do NOT pass --no-mmproj). Slower than the MTP text
  # entry, which is fine for background image/clip description.
  "qwen3.6-35B-A3B-vision" = {
    cmd = ''
      ${gpu-tenant-wrapper} ${llama-cpp-cuda}/bin/llama-server \
        -hf unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q4_K_XL \
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
    # Kept as rollback only. The generic "qwen-vision"/"vision" aliases moved to
    # qwen3.8-27B-vision, so they follow the current model; llama-swap would
    # reject them being defined twice anyway.
    aliases = [ "qwen3.6-35B-A3B-vision" ];
  };

  # Qwen3.6 27B (DENSE) with VISION enabled (mmproj), for A/B-ing the camera pipeline
  # against qwen3.6-35B-A3B-vision. The 27B is dense (all ~27B params active) vs the 35B's
  # MoE (~3B active): slower per token, but it may read ambiguous frames (the orange cat vs
  # dog) better. Non-MTP GGUF ships the mmproj (do NOT pass --no-mmproj / the MTP flags).
  # Q5_K_M (~19GB) fits the 32GB 5090 alongside the projector and 32K KV cache; drop to
  # Q4_K_M if VRAM is tight. Same Qwen3.6 sampling as the 35B-vision entry for a fair test.
  "qwen3.6-27B-vision" = {
    cmd = ''
      ${gpu-tenant-wrapper} ${llama-cpp-cuda}/bin/llama-server \
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
        --jinja
    '';
    aliases = [
      "qwen3.6-27B-vision"
      "qwen-vision-27b"
    ];
  };

  # Qwen3.6 27B (262K native context)
  # MTP speculative decoding: see note on qwen3.6-35B-A3B-full above.
  #
  # --fit-target 6144: `-fit on` defaults to leaving only 1024 MiB free, so it
  # sized the KV cache to n_ctx=216576 and filled the 5090 to ~1 GiB headroom.
  # This DENSE 27B has a large per-step compute buffer, and --spec-default layers
  # ngram-mod on top of MTP, which drafts variable-length verify batches. A long
  # verbatim match drafts a big batch whose mul_mat_q buffer overran the 1 GiB
  # margin and CUDA-OOM'd mid-generation. Reserving 6 GiB (~131K ctx, still far
  # above the -n 32768 cap) leaves room for the spec spike. The MoE 35B entry
  # above shares the spec setup but has a tiny compute footprint, so it's fine.
  "qwen3.6-27B-full" = {
    cmd = ''
      ${gpu-tenant-wrapper} ${llama-cpp-cuda}/bin/llama-server \
        -hf unsloth/Qwen3.6-27B-MTP-GGUF:UD-Q5_K_XL \
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
        --fit-target 6144 \
        --flash-attn on \
        --cache-type-k q8_0 \
        --cache-type-v q8_0 \
        --no-mmap \
        --parallel 1 \
        --no-mmproj \
        --spec-type draft-mtp \
        --spec-draft-n-max 2 \
        --spec-default \
        --chat-template-kwargs '{"preserve_thinking": true}' \
        --jinja
    '';
    aliases = [ "qwen3.6-27B-full" ];
  };

  # Gemma 4 26B A4B MoE (~4B active, fast inference)
  "gemma-4-26B-A4B" = {
    cmd = ''
      ${gpu-tenant-wrapper} ${llama-cpp-cuda}/bin/llama-server \
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
      ${gpu-tenant-wrapper} ${llama-cpp-cuda}/bin/llama-server \
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
    aliases = [
      "rerank"
      "jina-reranker"
    ];
  };

}
