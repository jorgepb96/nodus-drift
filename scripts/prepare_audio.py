#!/usr/bin/env python3
"""Reconstruct the current licensed audio bank; never fetch Moodist recordings."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'ios/NodusDrift/Resources/Audio'


def matches(path, sound):
    if not path.exists() or path.stat().st_size != sound['bytes']:
        return False
    with path.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest() == sound['sha256']


def main():
    catalog = json.loads((ROOT / 'ios/NodusDrift/Resources/catalog.json').read_text())
    recordings = [s for s in catalog if s['kind'] == 'file']
    if all(matches(DEST / s['asset'], s) for s in recordings):
        print('81/81 current licensed loops match the catalogue; no download needed.')
        return
    subprocess.run([sys.executable, str(ROOT / 'scripts/download_audio_sources.py')], check=True)
    subprocess.run([sys.executable, str(ROOT / 'scripts/create_audio_loops.py')], check=True)
    stage = ROOT / '.build/replacement-audio/loops'
    # Validate the complete reconstruction before touching any bundled asset.
    for sound in recordings:
        if not matches(stage / sound['asset'], sound):
            raise ValueError(f"Reconstructed bytes differ for {sound['id']}. Use the encoder and NumPy versions in docs/rights/replacement-audio/build-report.json; do not overwrite the release catalogue.")
    for sound in recordings:
        dest = DEST / sound['asset']
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(stage / sound['asset'], dest)
    print('81/81 licensed loops prepared. All 89 options preserved.')


if __name__ == '__main__':
    main()
