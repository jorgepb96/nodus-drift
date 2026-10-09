#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-only
"""Compare a recording with a public Freesound preview without playing audio.

Requires numpy and ffmpeg. Only decodes audio to memory; never opens an audio device.
Three independent five-second windows are searched across the whole candidate.
The output measures signal identity, not rights ownership or distribution clearance.
"""
import argparse
import datetime
import hashlib
import json
import re
import subprocess
import time
import urllib.request
from pathlib import Path

import numpy as np

RATE = 8000


def decode(path, rate=RATE):
    result = subprocess.run(
        ["ffmpeg", "-nostdin", "-v", "error", "-i", str(path), "-ac", "1",
         "-ar", str(rate), "-f", "f32le", "pipe:1"],
        capture_output=True, check=True,
    )
    return np.frombuffer(result.stdout, dtype="<f4").astype(np.float64)


def best_match(signal, window, rate=RATE):
    window = window - window.mean()
    length = len(window)
    fft_length = 1 << (len(signal) + length - 2).bit_length()
    cross = np.fft.irfft(
        np.fft.rfft(signal, fft_length) *
        np.fft.rfft(window[::-1], fft_length), fft_length,
    )[length - 1:len(signal)]
    sums = np.r_[0.0, np.cumsum(signal)]
    squares = np.r_[0.0, np.cumsum(signal * signal)]
    variance = squares[length:] - squares[:-length] - (
        sums[length:] - sums[:-length]) ** 2 / length
    denominator = np.sqrt(np.maximum(variance, 0) * np.dot(window, window))
    correlation = np.divide(cross, denominator, out=np.zeros_like(cross),
                            where=denominator > 1e-12)
    offset = int(np.argmax(correlation))
    # Different resamplers can leave a fractional-sample delay. Refine only the
    # strongest integer alignment; this cannot manufacture a match elsewhere.
    left = max(0, offset - 128)
    right = min(len(signal), offset + length + 128)
    segment = signal[left:right]
    padding = 1 << (len(segment) - 1).bit_length()
    spectrum = np.fft.rfft(segment, padding)
    frequencies = np.fft.rfftfreq(padding)
    best = float(correlation[offset])
    best_delta = 0.0
    for delta in np.linspace(-0.5, 0.5, 17):
        shifted = np.fft.irfft(spectrum * np.exp(2j * np.pi * frequencies * delta), padding)
        aligned = shifted[offset - left:offset - left + length]
        aligned = aligned - aligned.mean()
        norm = np.sqrt(np.dot(aligned, aligned) * np.dot(window, window))
        score = float(np.dot(aligned, window) / norm) if norm > 1e-12 else 0.0
        if score > best:
            best, best_delta = score, float(delta)
    return (offset + best_delta) / rate, best


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--recording", required=True, type=Path)
    parser.add_argument("--source-page", required=True)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--window-starts", help="Explicit, distinct interior starts in seconds, for edited loop tails")
    parser.add_argument("--sample-rate", type=int, default=RATE)
    parser.add_argument("--reuse-cache", action="store_true", help="Reuse a saved page and preview after checking their recorded URLs and hashes")
    parser.add_argument("--preview-quality", choices=["hq", "lq"], default="hq")
    args = parser.parse_args()
    if not re.fullmatch(r"https://freesound\.org/people/[^/]+/sounds/\d+/", args.source_page):
        parser.error("Use a public Freesound sound page URL")
    args.output_dir.mkdir(parents=True, exist_ok=True)
    if not 1000 <= args.sample_rate <= RATE:
        parser.error("Sample rate must be between 1000 and 8000 Hz")
    rate = args.sample_rate
    page_path = args.output_dir / "source-page.html"
    preview_path = args.output_dir / "source-preview.mp3"
    cache_record = None
    if args.reuse_cache:
        evidence_path = args.output_dir / "comparison.json"
        if not all(p.exists() for p in (page_path, preview_path, evidence_path)):
            parser.error("Reusing a cache requires a completed comparison with its page and preview")
        cache_record = json.loads(evidence_path.read_text())
        if cache_record["source_page"] != args.source_page:
            parser.error("Cached source page does not match the requested source")
        page = page_path.read_bytes()
        if hashlib.sha256(page).hexdigest() != cache_record["source_page_sha256"]:
            parser.error("Cached source page hash does not match its evidence")
    else:
        page = urllib.request.urlopen(args.source_page, timeout=30).read()
    text = page.decode("utf-8")
    page_path.write_bytes(page)
    previews = re.findall(r"https://cdn\.freesound\.org/[^\"<>\s]+-" + args.preview_quality + r"\.mp3", text)
    if not previews:
        raise RuntimeError("No public preview found; do not bypass login")
    preview_url = previews[0]
    if cache_record:
        if cache_record["public_preview_url"] != preview_url:
            parser.error("Cached preview URL or quality does not match the requested preview")
        preview = preview_path.read_bytes()
        if hashlib.sha256(preview).hexdigest() != cache_record["public_preview_sha256"]:
            parser.error("Cached preview hash does not match its evidence")
    else:
        chunks = []
        deadline = time.monotonic() + 180
        with urllib.request.urlopen(preview_url, timeout=15) as response:
            while True:
                if time.monotonic() > deadline:
                    raise TimeoutError("Public preview download exceeded 180 seconds")
                chunk = response.read(65536)
                if not chunk:
                    break
                chunks.append(chunk)
                if sum(map(len, chunks)) > 20_000_000:
                    raise RuntimeError("Preview exceeds the research download size limit")
        preview = b"".join(chunks)
    preview_path.write_bytes(preview)
    local = decode(args.recording, rate)
    remote = decode(preview_path, rate)
    window_size = min(5 * rate, len(local) // 4, len(remote) // 4)
    starts = [min(rate, len(local) - window_size),
              (len(local) - window_size) // 2,
              max(0, len(local) - window_size - rate)]
    if args.window_starts:
        starts = [int(float(x) * rate) for x in args.window_starts.split(",")]
        if len(starts) < 3 or len(set(starts)) != len(starts) or any(
                x < 0 or x + window_size > len(local) for x in starts):
            parser.error("Provide at least three distinct, valid five-second window starts")
    matches = []
    for start in starts:
        offset, correlation = best_match(remote, local[start:start + window_size], rate)
        matches.append({"recording_start_seconds": start / rate,
                        "source_start_seconds": offset,
                        "source_minus_recording_seconds": offset - start / rate,
                        "normalized_correlation": correlation})
    spread = float(np.ptp([x["source_minus_recording_seconds"] for x in matches]))
    strong_match = min(x["normalized_correlation"] for x in matches) >= 0.95 and spread <= 0.02
    loop_offsets = np.array([x["source_minus_recording_seconds"] for x in matches])
    loop_offsets -= np.round((loop_offsets - loop_offsets[0]) / (len(local) / rate)) * (len(local) / rate)
    loop_spread = float(np.ptp(loop_offsets))
    strong_loop_match = min(x["normalized_correlation"] for x in matches) >= 0.95 and loop_spread <= 0.02
    licenses = sorted(set(re.findall(r"https?://creativecommons\.org/[^\"<>\s]+", text)))
    result = {
        "compared_at_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "source_retrieval": "validated saved evidence" if cache_record else "public page and preview fetched for this comparison",
        "method": f"three-window exhaustive normalized cross-correlation with fractional-sample refinement; mono {rate} Hz; silent PCM decoding",
        "recording": str(args.recording),
        "recording_sha256": hashlib.sha256(args.recording.read_bytes()).hexdigest(),
        "source_page": args.source_page,
        "source_page_sha256": hashlib.sha256(page).hexdigest(),
        "public_preview_url": preview_url,
        "public_preview_sha256": hashlib.sha256(preview).hexdigest(),
        "source_license_links": licenses,
        "recording_decoded_seconds": len(local) / rate,
        "source_decoded_seconds": len(remote) / rate,
        "window_seconds": window_size / rate,
        "window_selection": "explicit interior starts" if args.window_starts else "start, middle, end",
        "matches": matches,
        "offset_spread_seconds": spread,
        "strong_signal_identity": strong_match,
        "loop_adjusted_offset_spread_seconds": loop_spread,
        "strong_signal_identity_allowing_loop_rotation": strong_loop_match,
        "limits": "A match supports the identified source, not legal ownership. A non-match does not exclude time stretching, edits, or other transformations.",
    }
    (args.output_dir / "comparison.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"recording": args.recording.name, "source": args.source_page,
                      "correlations": [round(x["normalized_correlation"], 4) for x in matches],
                      "offset_spread": spread, "strong_signal_identity": strong_match}))


if __name__ == "__main__":
    main()
