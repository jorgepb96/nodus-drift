#!/usr/bin/env python3
"""Build the licensed replacement bank entirely offline, without audio output.

Requires NumPy and FFmpeg with libmp3lame. Original input hashes are mandatory.
The checked-in recipes preserve the existing option IDs, assets and byte budgets.
Only apply a complete, audited staging bank with --install.
"""
import argparse
import concurrent.futures
import hashlib
import json
import math
from pathlib import Path
import shutil
import subprocess

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
RIGHTS = ROOT / "docs/rights/replacement-audio"
RATE = 44_100


def command(args, **kwargs):
    return subprocess.run(args, check=True, capture_output=True, **kwargs)


def probe(path):
    return json.loads(command(["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(path)]).stdout)


def read_pcm(path, channels, highpass=0):
    args = ["ffmpeg", "-v", "error", "-nostdin", "-threads", "1", "-i", str(path)]
    if highpass:
        args += ["-af", f"highpass=f={highpass}"]
    args += ["-ar", str(RATE), "-ac", str(channels), "-f", "f32le", "pipe:1"]
    return np.frombuffer(command(args).stdout, dtype="<f4").reshape(-1, channels).copy()


def circular(samples, overlap):
    """A continuous circular join: end -> mixed tail/head -> head continuation."""
    overlap = min(overlap, len(samples) // 4)
    if overlap < 2:
        return samples
    blend = np.linspace(0, 1, overlap, dtype=np.float32)[:, None]
    return np.concatenate((samples[overlap:-overlap], samples[-overlap:] * (1 - blend) + samples[:overlap] * blend))


def radio(seed):
    """Original station-search sound design. No third-party broadcast samples."""
    rng = np.random.default_rng(seed)
    t = np.arange(RATE * 24, dtype=np.float32) / RATE
    noise = rng.normal(0, 0.1, len(t)).astype(np.float32)
    # AM-like tuning hiss and heterodyne whistles, with independently made tones.
    carrier = 480 + 180 * np.sin(2 * np.pi * t / 7) + 55 * np.sin(2 * np.pi * t / 2.7)
    phase = np.cumsum(carrier, dtype=np.float64) * (2 * np.pi / RATE)
    gate = np.maximum(0, np.sin(2 * np.pi * t / 4.3)) ** 5
    hiss = noise * (0.45 + 0.45 * np.sin(2 * np.pi * t / 5) ** 2)
    out = hiss + np.sin(phase).astype(np.float32) * gate * 0.025
    out -= np.mean(out)
    return out[:, None]


def metrics(samples):
    peak = float(np.max(np.abs(samples)))
    rms = float(np.sqrt(np.mean(samples.astype(np.float64) ** 2)))
    dc = float(np.max(np.abs(np.mean(samples, axis=0))))
    return dict(peak_dbfs=round(20 * math.log10(max(peak, 1e-12)), 3), rms_dbfs=round(20 * math.log10(max(rms, 1e-12)), 3), dc_max=round(dc, 8), finite=bool(np.all(np.isfinite(samples))))


def make(recipe, sources, source_dir, output_dir):
    sid = recipe["id"]
    key = recipe["source"]
    if key:
        source = sources[key]
        path = source_dir / f"{key}.wav"
        data = path.read_bytes()
        if len(data) != source["source_bytes"] or hashlib.sha256(data).hexdigest() != source["source_sha256"]:
            raise ValueError(f"Source hash mismatch: {key}")
        info = probe(path)
        channels = min(2, int(info["streams"][0]["channels"]))
        samples = read_pcm(path, channels, recipe["highpass_hz"])
        offset = int(recipe["offset_seconds"] * RATE)
        if offset:
            if offset >= len(samples):
                raise ValueError(f"Invalid crop for {sid}")
            samples = samples[offset:]
    else:
        channels = 1
        samples = radio(recipe["seed"])
    samples -= np.mean(samples, axis=0)
    gap = recipe["event_gap_seconds"]
    if gap:
        # Event spacing is deliberate sound design, rather than MP3 size padding.
        fade = min(int(RATE * 0.025), len(samples) // 8)
        ramp = np.linspace(0, 1, fade, dtype=np.float32)[:, None]
        samples[:fade] *= ramp
        samples[-fade:] *= ramp[::-1]
        samples = np.concatenate((samples, np.zeros((int(gap * RATE), channels), dtype=np.float32)))
    cycle = circular(samples, int(RATE * 0.4))
    rms = float(np.sqrt(np.mean(cycle.astype(np.float64) ** 2)))
    peak = float(np.max(np.abs(cycle)))
    if rms < 1e-7 or not np.all(np.isfinite(cycle)):
        raise ValueError(f"Empty or invalid source: {sid}")
    old_bitrate = recipe["target_bytes"] * 8 / recipe["previous_duration"] / 1000
    allowed = [96, 112, 128, 160, 192, 224, 256, 320] if channels == 1 else [128, 160, 192, 224, 256, 320]
    bitrate = min(allowed, key=lambda v: abs(v - old_bitrate))
    target = recipe["target_bytes"]
    duration = (target - 800) * 8 / (bitrate * 1000)
    dest = output_dir / recipe["asset"]
    dest.parent.mkdir(parents=True, exist_ok=True)
    for _ in range(3):
        count = int(duration * RATE)
        output = np.tile(cycle, (math.ceil(count / len(cycle)), 1))[:count]
        # Normalize the actual excerpt, not its longer source. Soft compression
        # keeps isolated field-recording knocks from making the ambience inaudible.
        desired_rms, ceiling = 10 ** (-24 / 20), 10 ** (-8 / 20)
        gain = desired_rms / float(np.sqrt(np.mean(output.astype(np.float64) ** 2)))
        for _ in range(8):
            limited = (ceiling * np.tanh(output * gain / ceiling)).astype(np.float32)
            actual_rms = float(np.sqrt(np.mean(limited.astype(np.float64) ** 2)))
            if abs(20 * math.log10(actual_rms / desired_rms)) < 0.1:
                break
            gain *= min(4, desired_rms / actual_rms)
        output = limited
        args = ["ffmpeg", "-v", "error", "-nostdin", "-y", "-f", "f32le", "-ar", str(RATE), "-ac", str(channels), "-i", "pipe:0", "-map_metadata", "-1", "-c:a", "libmp3lame", "-b:a", f"{bitrate}k", "-id3v2_version", "0", "-write_xing", "1", str(dest)]
        command(args, input=output.astype("<f4").tobytes())
        size = dest.stat().st_size
        if abs(size / target - 1) <= 0.01:
            break
        duration += (target - size) * 8 / (bitrate * 1000)
    if abs(size / target - 1) > 0.01:
        raise ValueError(f"Byte budget failed: {sid}: {size}/{target}")
    info = probe(dest)
    decoded = read_pcm(dest, channels)
    quality = metrics(decoded)
    # Check after MP3 decoding too: sparse transients can cause codec overshoot.
    # Attenuate the encoded loop as needed instead of accepting a clipped result.
    for _ in range(3):
        if quality["peak_dbfs"] <= -3:
            break
        correction = 10 ** ((-3.5 - quality["peak_dbfs"]) / 20)
        output *= correction
        gain *= correction
        command(args, input=output.astype("<f4").tobytes())
        decoded = read_pcm(dest, channels)
        quality = metrics(decoded)
    # A codec may overshoot the PCM peaks slightly; keep generous mix headroom.
    if not quality["finite"] or quality["peak_dbfs"] > -2 or quality["rms_dbfs"] < -32 or quality["dc_max"] > 0.002:
        raise ValueError(f"Signal check failed: {sid}: {quality}")
    seam = circular(decoded, int(recipe["crossfade_ms"] / 1000 * RATE))
    jumps = np.abs(np.diff(seam, axis=0))
    quality["wrap_jump"] = round(float(np.max(np.abs(seam[-1] - seam[0]))), 8)
    quality["max_internal_sample_jump"] = round(float(np.max(jumps)), 8)
    if quality["wrap_jump"] > max(0.02, quality["max_internal_sample_jump"] * 1.1):
        raise ValueError(f"Discontinuous runtime seam: {sid}: {quality}")
    return dict(id=sid, asset=recipe["asset"], source=key, bytes=size, previous_bytes=target, byte_change_percent=round((size / target - 1) * 100, 4), sha256=hashlib.sha256(dest.read_bytes()).hexdigest(), duration=float(info["format"]["duration"]), decoded_duration=len(decoded) / RATE, channels=channels, sample_rate=RATE, bitrate_kbps=bitrate, source_cycle_seconds=len(cycle) / RATE, gain_db=round(20 * math.log10(gain), 3), crossfade_ms=recipe["crossfade_ms"], license_id="LicenseRef-Nodus-loop-CC0-sources" if key else "LicenseRef-Nodus-original-audio", checks=quality)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--sources", type=Path, default=ROOT / ".build/replacement-audio/sources")
    ap.add_argument("--output", type=Path, default=ROOT / ".build/replacement-audio/loops")
    ap.add_argument("--jobs", type=int, default=3)
    ap.add_argument("--install", action="store_true")
    args = ap.parse_args()
    recipes = json.loads((RIGHTS / "recipes.json").read_text())["recipes"]
    sources = json.loads((RIGHTS / "sources.json").read_text())
    baseline = json.loads((RIGHTS / "baseline-catalog.json").read_text())
    assert len(recipes) == 81 and len({r["id"] for r in recipes}) == 81
    outputs = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futures = [pool.submit(make, r, sources, args.sources, args.output) for r in recipes]
        for future in concurrent.futures.as_completed(futures):
            result = future.result()
            outputs.append(result)
            print(f"{len(outputs)}/81 loops complete: {result['id']} ({result['byte_change_percent']:+.2f}% bytes)", flush=True)
    outputs.sort(key=lambda v: next(i for i, r in enumerate(recipes) if r["id"] == v["id"]))
    encoder = command(["ffmpeg", "-version"]).stdout.decode().splitlines()[0]
    report = dict(schema=1, date="2026-10-09", encoder=encoder, numpy=np.__version__, playback_performed=False, outputs=outputs)
    (args.output / "build-report.json").write_text(json.dumps(report, indent=2) + "\n")
    if args.install:
        byid = {v["id"]: v for v in outputs}
        for sound in baseline:
            if sound["kind"] != "file":
                continue
            output = byid[sound["id"]]
            assert output["sha256"] != sound["sha256"], sound["id"]
            dest = ROOT / "ios/NodusDrift/Resources/Audio" / sound["asset"]
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(args.output / sound["asset"], dest)
            sound.update(sha256=output["sha256"], bytes=output["bytes"], duration=output["duration"], crossfadeMs=output["crossfade_ms"], licenseStatus="verified", licenseId=output["license_id"])
        (ROOT / "ios/NodusDrift/Resources/catalog.json").write_text(json.dumps(baseline, indent=2, ensure_ascii=False) + "\n")
        shutil.copy2(args.output / "build-report.json", RIGHTS / "build-report.json")
        print("Installed complete 81-loop bank; all 89 catalogue options preserved.", flush=True)


if __name__ == "__main__":
    main()
