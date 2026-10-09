#!/usr/bin/env python3
"""Prepare development audio; preserve upstream bytes, check every digest."""
import concurrent.futures
import hashlib
import json
from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
COMMIT = '11c0be2200116a3635880d600fd6953899cc51a3'
CATALOG = json.loads((ROOT / 'ios/NodusDrift/Resources/catalog.json').read_text())

def prepare(sound):
    destination = ROOT / 'ios/NodusDrift/Resources/Audio' / sound['asset']
    if destination.exists():
        data = destination.read_bytes()
        if len(data) == sound['bytes'] and hashlib.sha256(data).hexdigest() == sound['sha256']:
            return sound['id']
    url = f"https://raw.githubusercontent.com/remvze/moodist/{COMMIT}/public/sounds/{sound['asset']}"
    data = urllib.request.urlopen(url, timeout=60).read()
    if len(data) != sound['bytes'] or hashlib.sha256(data).hexdigest() != sound['sha256']:
        raise ValueError(f"Upstream bytes changed: {sound['id']}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_suffix('.part')
    temporary.write_bytes(data)
    temporary.replace(destination)
    return sound['id']

if __name__ == '__main__':
    recordings = [s for s in CATALOG if s['kind'] == 'file']
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        for index, name in enumerate(pool.map(prepare, recordings), 1):
            print(f"{index}/{len(recordings)} checked: {name}", flush=True)
    print('All 81 recordings match the pinned upstream catalogue.')
