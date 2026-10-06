# llama-swap model table.
#
# Imported from ../llama-cpp.nix; receives the wrappers and CUDA packages
# as plain values so each model entry stays trivially grep-able.
{
  gpu-tenant-wrapper,
  gpu-tenant-wrapper-frigate,
  llama-cpp-cuda,
  qwenChatTemplate,
  strata,
  strataConfigLink,
}:
{

  # Qwen3.8 27B (hybrid SSM/attention, 262K native context).
  # gpu-tenant-wrapper-frigate also stops Frigate (~1.85 GiB) for headroom.
  # -fit + fit-target 2048 sizes context to available VRAM per load; do not go
  # below 1024 (MTP draft context is not accounted for; 512 OOM'd).
  # --cache-ram 32768 keeps the KV eviction cliff beyond 3 concurrent agents.
  # --spec-draft-n-max 4: b11069 deepened MTP draft (+10%); on sm_120 the optimal
  # depth shifts from 2 to 4 (+120% net MTP gain vs no-spec).
  "qwen3.8-27B-full" = {
    cmd = ''
      ${gpu-tenant-wrapper-frigate} ${llama-cpp-cuda}/bin/llama-server \
        -hf unsloth/Qwen3.8-27B-GGUF:UD-Q4_K_M \
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
        --load-mode none \
        --parallel 1 \
        --no-mmproj \
        -t 16 \
        --spec-type draft-mtp \
        --spec-draft-n-max 4 \
        --spec-default \
        --chat-template-file ${qwenChatTemplate} \
        --reasoning-format deepseek \
        --chat-template-kwargs '{"preserve_thinking": true, "reasoning_effort": "xhigh"}' \
        --jinja
    '';
  };

  # Qwen3.8 27B vision. Same model as -full but keeps Frigate alive (pet-report
  # reads its HTTP API) and pins a short context for captioning.
  # --image-min-tokens 1024: Qwen-VL needs this for reliable grounding.
  "qwen3.8-27B-vision" = {
    cmd = ''
      ${gpu-tenant-wrapper} ${llama-cpp-cuda}/bin/llama-server \
        -hf unsloth/Qwen3.8-27B-GGUF:UD-Q4_K_M \
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
        --load-mode none \
        --parallel 1 \
        -t 16 \
        --chat-template-file ${qwenChatTemplate} \
        --reasoning-format deepseek \
        --chat-template-kwargs '{"preserve_thinking": true, "reasoning_effort": "low"}' \
        --jinja
    '';
    aliases = [
      "qwen-vision"
      "vision"
    ];
  };

  # Qwen3.8-Flash-Next (125B MoE / 6B active, qwen4exp architecture, 262K context).
  # --n-cpu-moe 36: engram table (33 GiB) exceeds VRAM; below ~24 fails at cudaMalloc.
  # -fit on: b11249 fixes the graph_max_nodes assert that blocked -fit on qwen4exp.
  # -b/-ub 4096: with the experts on the CPU, prompt processing copies them to the GPU once per
  # ubatch over the card's x8 PCIe link, so 4096-token batches read prompts ~4.5x faster than the
  # default 512 (~290 -> ~1,300 tok/s at 4-32K, decode unchanged, -fit still left ~240K context).
  # Measured with the ZFS ARC cap from boot.nix; with an uncapped ARC the page cache thrashes and
  # the gain disappears.
  # No MTP: b11408 can attach ggml-org's standalone head (-hfd ggml-org/Qwen3.8-Flash-Next-GGUF:Q8_0
  # --spec-type draft-mtp; unsloth's own heads predate that merge and assert), but with the routed
  # experts on the CPU every drafted token adds expert reads: ~7% more decode on UD-IQ4_XS while -fit
  # drops the context to ~99K for the head's VRAM, and slower on IQ2_XS (decode 49 -> 44 tok/s).
  "qwen3.8-flash-next-full" = {
    cmd = ''
      ${gpu-tenant-wrapper} ${llama-cpp-cuda}/bin/llama-server \
        -hf unsloth/Qwen3.8-Flash-Next-GGUF:UD-IQ4_XS \
        --metrics \
        --host 0.0.0.0 \
        --port ''${PORT} \
        --temp 1.0 \
        --top-p 0.95 \
        --top-k 20 \
        --min-p 0.0 \
        --presence-penalty 0.0 \
        --repeat-penalty 1.0 \
        -fit on \
        --fit-target 2048 \
        --flash-attn on \
        --cache-type-k q8_0 \
        --cache-type-v q8_0 \
        --n-cpu-moe 36 \
        -b 4096 \
        -ub 4096 \
        --parallel 1 \
        --no-mmproj \
        -t 16 \
        --chat-template-file ${qwenChatTemplate} \
        --reasoning-format deepseek \
        --chat-template-kwargs '{"preserve_thinking": true, "reasoning_effort": "xhigh"}' \
        --jinja
    '';
  };

  # Qwen3.8-Flash-Next on Strata (../../strata.nix), from the same UD-IQ4_XS files as -full.
  # Strata keeps the busiest experts in VRAM and the rest page-locked in RAM (hence LimitMEMLOCK
  # on llama-swap), computes cache misses on the CPU alongside the GPU, and drafts with the
  # model's own MTP layer. Measured here with the ZFS ARC capped: prompts at ~3,700 tok/s and
  # decode at ~116 tok/s (~105 sampled) at 32K, against ~1,300 and ~35 for -full. It serves one
  # request at a time and has no grammar-constrained JSON (it prompts, then validates), so
  # pet-report and other structured-output clients stay on the llama.cpp entries.
  # strata-prepare (llama-cpp.nix) must have run once before the first load.
  "qwen3.8-flash-next-strata" = {
    cmd = ''
      ${gpu-tenant-wrapper} ${strata}/bin/strata-serve \
        --engine strata \
        --config ${strataConfigLink} \
        --host 127.0.0.1 \
        --port ''${PORT}
    '';
    # The server binds IPv4 loopback only; the default http://localhost could resolve to ::1.
    proxy = "http://127.0.0.1:\${PORT}";
    aliases = [ "flash-next-fast" ];
  };

  # Qwen3.8-Flash-Next vision. Drops MTP (incompatible with mmproj) and pins
  # short context for image captioning. Slower than the 27B vision entry due
  # to CPU offloading, but higher quality on ambiguous frames.
  "qwen3.8-flash-next-vision" = {
    cmd = ''
      ${gpu-tenant-wrapper} ${llama-cpp-cuda}/bin/llama-server \
        -hf unsloth/Qwen3.8-Flash-Next-GGUF:UD-IQ4_XS \
        --metrics \
        --host 0.0.0.0 \
        --port ''${PORT} \
        --temp 1.0 \
        --top-p 0.95 \
        --top-k 20 \
        --min-p 0.0 \
        --presence-penalty 0.0 \
        --repeat-penalty 1.0 \
        -fit on \
        --fit-target 2048 \
        --flash-attn on \
        --cache-type-k q8_0 \
        --cache-type-v q8_0 \
        --n-cpu-moe 36 \
        --image-min-tokens 1024 \
        --parallel 1 \
        -t 16 \
        --chat-template-file ${qwenChatTemplate} \
        --reasoning-format deepseek \
        --chat-template-kwargs '{"preserve_thinking": true, "reasoning_effort": "low"}' \
        --jinja
    '';
  };

}
