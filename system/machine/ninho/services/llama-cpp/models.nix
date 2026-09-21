# llama-swap model table.
#
# Imported from ../llama-cpp.nix; receives the wrappers and CUDA packages
# as plain values so each model entry stays trivially grep-able.
{
  gpu-tenant-wrapper,
  gpu-tenant-wrapper-frigate,
  llama-cpp-cuda,
  qwenChatTemplate,
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
        --spec-type draft-mtp \
        --spec-draft-n-max 4 \
        --spec-default \
        --chat-template-file ${qwenChatTemplate} \
        --reasoning-format deepseek \
        --chat-template-kwargs '{"preserve_thinking": true, "reasoning_effort": "xhigh"}' \
        --jinja
    '';
    aliases = [ "qwen3.8-27B-full" ];
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

  # Qwen3.8-Flash-Next (125B MoE / 6B active, qwen4exp architecture, 262K context).
  # MTP draft head (PR #27836) and recurrent state rollback (PR #28123) in b10903.
  # --n-cpu-moe 36: engram table (33 GiB) exceeds VRAM; below ~24 fails at cudaMalloc.
  # -c 262144 pinned: -fit hits a graph_max_nodes assert on this architecture.
  # --spec-draft-n-max 4: deeper MTP draft in b11069 (+120% net on sm_120 vs 2).
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
        -c 262144 \
        --flash-attn on \
        --cache-type-k q8_0 \
        --cache-type-v q8_0 \
        -ngl 99 \
        --n-cpu-moe 36 \
        --parallel 1 \
        --no-mmproj \
        --spec-type draft-mtp \
        --spec-draft-n-max 4 \
        --spec-default \
        --chat-template-file ${qwenChatTemplate} \
        --reasoning-format deepseek \
        --chat-template-kwargs '{"preserve_thinking": true, "reasoning_effort": "xhigh"}' \
        --jinja
    '';
    aliases = [ "qwen3.8-flash-next-full" ];
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
        -c 32768 \
        --flash-attn on \
        --cache-type-k q8_0 \
        --cache-type-v q8_0 \
        -ngl 99 \
        --n-cpu-moe 36 \
        --image-min-tokens 1024 \
        --parallel 1 \
        --chat-template-file ${qwenChatTemplate} \
        --reasoning-format deepseek \
        --chat-template-kwargs '{"preserve_thinking": true, "reasoning_effort": "low"}' \
        --jinja
    '';
    aliases = [ "qwen3.8-flash-next-vision" ];
  };

}
