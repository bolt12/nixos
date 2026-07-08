#!/usr/bin/env python3
"""Long-form transcription + diarization for MOSS-Transcribe-Diarize.

MOSS runs single-pass over the whole audio inside a 131072-token context
(12.5 audio tokens/sec, verified from the checkpoint's config), so one call
tops out near 85 minutes. Multi-hour D&D sessions must therefore be split.

This driver probes the duration, cuts the recording into fixed chunks with
ffmpeg, transcribes each chunk with the model loaded once, offsets every
chunk's timestamps by its start, and merges the result into a single
subtitle.srt + segments.json.

Output is written incrementally: each chunk's raw transcript is saved as soon
as it finishes and the merged SRT/JSON is rewritten after every chunk, so an
out-of-memory error or crash on a late chunk keeps all completed work. A chunk
that fails is logged and skipped rather than aborting the whole run.

Speaker labels ([Sxx]) are assigned per chunk by the model and are NOT
consistent across chunks; pass --label-chunks to keep them distinct
(C1-S01, C2-S01, ...) rather than silently implying they are the same person.

All MOSS imports are deferred past the --dry-run branch so that --dry-run and
--help do not pay torch's import cost and need no GPU.
"""
from __future__ import annotations

import argparse
import gc
import json
import subprocess
import sys
import tempfile
import time
from pathlib import Path

MODEL_CTX = 131072
# 12.5 audio tokens/sec plus a small allowance for the 5-second time markers.
EFF_TOK_PER_SEC = 13.5
DEFAULT_MODEL = "OpenMOSS-Team/MOSS-Transcribe-Diarize"
PROGRESS_EVERY_SEC = 10.0

_START = time.monotonic()


def fmt_dur(seconds: float) -> str:
    total = int(seconds)
    h, rem = divmod(total, 3600)
    m, s = divmod(rem, 60)
    return f"{h}h{m:02d}m{s:02d}s" if h else f"{m}m{s:02d}s"


def log(msg: str) -> None:
    print(f"[{fmt_dur(time.monotonic() - _START)}] {msg}", file=sys.stderr, flush=True)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="Chunked long-form transcription + diarization via MOSS-Transcribe-Diarize.",
    )
    p.add_argument("input", help="Input audio or video file.")
    p.add_argument("--model", default=DEFAULT_MODEL, help="HF repo id or local model path.")
    p.add_argument("--out-dir", default=None, help="Output dir (default runs/dnd_<timestamp>).")
    p.add_argument("--chunk-min", type=float, default=50.0, help="Chunk length in minutes.")
    p.add_argument("--max-new-tokens", type=int, default=65536, help="Output token budget per chunk.")
    p.add_argument("--device", default="auto")
    p.add_argument("--dtype", default="bf16")
    p.add_argument(
        "--label-chunks",
        action="store_true",
        help="Prefix speaker labels with the chunk id (C1-S01) so per-chunk speakers stay distinct.",
    )
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the chunk plan and token budget, then exit without loading the model.",
    )
    return p.parse_args()


def ffprobe_duration(path: Path) -> float:
    out = subprocess.check_output(
        [
            "ffprobe", "-v", "error",
            "-show_entries", "format=duration",
            "-of", "default=noprint_wrappers=1:nokey=1",
            str(path),
        ],
        text=True,
    )
    return float(out.strip())


def plan_chunks(total: float, chunk_sec: float) -> list[tuple[float, float]]:
    chunks: list[tuple[float, float]] = []
    start = 0.0
    while start < total - 1e-3:
        chunks.append((start, min(chunk_sec, total - start)))
        start += chunk_sec
    return chunks


def extract_chunk(src: Path, start: float, dur: float, dst: Path) -> None:
    subprocess.run(
        [
            "ffmpeg", "-nostdin", "-v", "error", "-y",
            "-ss", f"{start:.3f}", "-t", f"{dur:.3f}", "-i", str(src),
            "-ac", "1", "-ar", "16000", str(dst),
        ],
        check=True,
    )


def write_outputs(out_dir: Path, segments: list) -> None:
    """(Re)write the merged SRT + JSON. Called after every chunk so partial
    results are always on disk if a later chunk fails."""
    from moss_transcribe_diarize.subtitle import export_json, export_srt, write_text

    for idx, seg in enumerate(segments, start=1):
        seg.id = str(idx)
    write_text(out_dir / "subtitle.srt", export_srt(segments, show_speaker=True), encoding="utf-8-sig")
    write_text(out_dir / "segments.json", export_json(segments))


def make_progress_cb(chunk_no: int):
    """Throttled callback for ModelRunner.status_callback: reports decode rate
    so a long chunk does not look frozen."""
    state = {"t": time.monotonic(), "tok": 0}

    def cb(_stage: str, _progress, tokens) -> None:
        if not tokens:
            return
        now = time.monotonic()
        if now - state["t"] >= PROGRESS_EVERY_SEC:
            rate = (tokens - state["tok"]) / (now - state["t"])
            log(f"  chunk {chunk_no}: generating... {tokens} tokens ({rate:.0f} tok/s)")
            state["t"] = now
            state["tok"] = tokens

    return cb


def main() -> None:
    args = parse_args()
    input_path = Path(args.input).expanduser()
    if not input_path.exists():
        raise SystemExit(f"Input not found: {input_path}")

    chunk_sec = args.chunk_min * 60.0
    peak_tokens = EFF_TOK_PER_SEC * chunk_sec + args.max_new_tokens
    if peak_tokens > MODEL_CTX:
        max_min = (MODEL_CTX - args.max_new_tokens) / EFF_TOK_PER_SEC / 60.0
        raise SystemExit(
            f"--chunk-min {args.chunk_min:g} with --max-new-tokens {args.max_new_tokens} needs "
            f"~{peak_tokens:.0f} tokens > {MODEL_CTX} context. "
            f"Use --chunk-min <= {max_min:.0f}, or lower --max-new-tokens."
        )

    total = ffprobe_duration(input_path)
    chunks = plan_chunks(total, chunk_sec)

    if args.dry_run:
        print(f"input: {input_path}")
        print(f"duration: {total / 60:.1f} min   chunks: {len(chunks)}   chunk-min: {args.chunk_min:g}")
        for i, (start, dur) in enumerate(chunks, start=1):
            audio_tok = int(EFF_TOK_PER_SEC * dur)
            peak = audio_tok + args.max_new_tokens
            print(
                f"  chunk {i:02d}: {start / 60:6.1f}-{(start + dur) / 60:6.1f} min   "
                f"~{audio_tok} audio + {args.max_new_tokens} out = {peak}/{MODEL_CTX} tok"
            )
        return

    out_dir = Path(args.out_dir or f"runs/dnd_{time.strftime('%Y%m%d_%H%M%S')}").expanduser()
    out_dir.mkdir(parents=True, exist_ok=True)

    # Deferred so --dry-run / --help stay torch-free (the package __init__ pulls in torch).
    import torch

    from moss_transcribe_diarize.app.model_runner import ModelRunner
    from moss_transcribe_diarize.subtitle import subtitle_segments_from_transcript

    cuda = torch.cuda.is_available()
    log(f"input {input_path.name}: {total / 60:.1f} min -> {len(chunks)} chunk(s) of <= {args.chunk_min:g} min")
    log(f"output: {out_dir}")
    log("first run downloads ~1.8GB to ~/.cache/huggingface and loads the model into VRAM ...")

    runner = ModelRunner(args.model, device=args.device, dtype=args.dtype)
    all_segments: list = []
    proc_start = time.monotonic()

    with tempfile.TemporaryDirectory() as td:
        for i, (start, dur) in enumerate(chunks):
            chunk_no = i + 1
            span = f"{start / 60:.1f}-{(start + dur) / 60:.1f} min"
            chunk_t0 = time.monotonic()
            log(f"[chunk {chunk_no}/{len(chunks)}] {span} | extracting audio ...")
            wav = Path(td) / f"chunk_{chunk_no:02d}.wav"
            extract_chunk(input_path, start, dur, wav)

            if cuda:
                torch.cuda.reset_peak_memory_stats()
            try:
                result = runner.transcribe(
                    wav,
                    max_length=MODEL_CTX,
                    max_new_tokens=args.max_new_tokens,
                    decoding="greedy",
                    status_callback=make_progress_cb(chunk_no),
                )
            except Exception as exc:  # noqa: BLE001 - one bad chunk must not lose the rest
                log(f"[chunk {chunk_no}/{len(chunks)}] FAILED after {fmt_dur(time.monotonic() - chunk_t0)}: {exc}")
                gc.collect()
                if cuda:
                    torch.cuda.empty_cache()
                continue

            # Persist the raw model output immediately, before parsing.
            (out_dir / f"chunk_{chunk_no:02d}_raw.txt").write_text(result.text, encoding="utf-8")
            try:
                segments = subtitle_segments_from_transcript(result.text, postprocess=False)
            except Exception as exc:  # noqa: BLE001
                log(f"[chunk {chunk_no}/{len(chunks)}] parse failed ({exc}); raw text kept, skipping merge")
                segments = []
            for seg in segments:
                seg.start += start
                seg.end += start
                if args.label_chunks:
                    seg.speaker = f"C{chunk_no}-{seg.speaker}"
            all_segments.extend(segments)
            write_outputs(out_dir, all_segments)

            chunk_dt = time.monotonic() - chunk_t0
            done = chunk_no
            eta = (time.monotonic() - proc_start) / done * (len(chunks) - done)
            vram = f" | peak VRAM {torch.cuda.max_memory_allocated() / 2**30:.1f} GiB" if cuda else ""
            log(
                f"[chunk {chunk_no}/{len(chunks)}] done in {fmt_dur(chunk_dt)} | "
                f"{len(segments)} segments{vram} | total {fmt_dur(time.monotonic() - proc_start)} | "
                f"ETA {fmt_dur(eta)}"
            )

            del result, segments
            gc.collect()
            if cuda:
                torch.cuda.empty_cache()

    log(
        f"done | {len(chunks)} chunks | {len(all_segments)} segments | "
        f"total {fmt_dur(time.monotonic() - proc_start)}"
    )
    print(
        json.dumps(
            {
                "input": str(input_path),
                "out_dir": str(out_dir),
                "duration_min": round(total / 60, 1),
                "chunks": len(chunks),
                "segments": len(all_segments),
                "files": {
                    "srt": str(out_dir / "subtitle.srt"),
                    "segments": str(out_dir / "segments.json"),
                },
            },
            ensure_ascii=False,
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
