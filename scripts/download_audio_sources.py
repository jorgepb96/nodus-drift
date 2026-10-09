#!/usr/bin/env python3
"""Public CC0 downloads only. Every extracted WAV is SHA-256 checked.

FSD50K uses bounded ranges from its split ZIP. Clotho uses its canonical
archive from a public mirror, verified against the primary Zenodo MD5.
"""
import concurrent.futures
import hashlib
import json
from pathlib import Path
import struct
import urllib.request
import zlib

ROOT = Path(__file__).resolve().parents[1]
RIGHTS = ROOT / 'docs/rights/replacement-audio'
CACHE = ROOT / '.build/replacement-audio'


def range_read(url, offset, length, total):
    end = offset + length - 1
    req = urllib.request.Request(url, headers={'Range': f'bytes={offset}-{end}'})
    with urllib.request.urlopen(req, timeout=120) as r:
        if r.status != 206 or r.headers.get('Content-Range') != f'bytes {offset}-{end}/{total}':
            raise ValueError(f'Incorrect byte range from {url}')
        data = r.read()
        if len(data) != length:
            raise ValueError(f'Truncated download: {url}')
        return data


def fsd_bytes(archive, offset, length):
    subset, disk = archive['subset'], archive['disk']
    parts = 6 if subset == 'dev' else 2
    result = bytearray()
    while length:
        ext = 'zip' if disk == parts - 1 else f'z{disk + 1:02d}'
        total = (2306663327 if subset == 'dev' else 3037675767) if ext == 'zip' else 3221225472
        take = min(length, total - offset)
        url = f'https://zenodo.org/api/records/4060432/files/FSD50K.{subset}_audio.{ext}/content'
        result += range_read(url, offset, take, total)
        length -= take
        disk += 1
        offset = 0
    return bytes(result)


def valid(dest, source):
    if not dest.exists() or dest.stat().st_size != source['source_bytes']:
        return False
    with dest.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest() == source['source_sha256']


def get_clotho_archive(a):
    dest = CACHE / a['filename']
    if dest.exists() and dest.stat().st_size == a['bytes']:
        with dest.open('rb') as f:
            if hashlib.file_digest(f, 'md5').hexdigest() == a['md5']:
                return dest
    entry = a['mirror_entry']
    assert entry['method'] == 0
    h = range_read(a['mirror_url'], entry['offset'], 30, a['mirror_zip_bytes'])
    fields = struct.unpack('<4s5H3I2H', h)
    assert fields[0] == b'PK\x03\x04'
    start = entry['offset'] + 30 + fields[-2] + fields[-1]
    end = start + a['bytes'] - 1
    req = urllib.request.Request(a['mirror_url'], headers={'Range': f'bytes={start}-{end}'})
    temp = dest.with_suffix('.part')
    md5, count = hashlib.md5(), 0
    with urllib.request.urlopen(req, timeout=120) as r, temp.open('wb') as out:
        assert r.status == 206 and r.headers.get('Content-Range') == f"bytes {start}-{end}/{a['mirror_zip_bytes']}"
        while block := r.read(8 * 1024 * 1024):
            out.write(block)
            md5.update(block)
            count += len(block)
    if count != a['bytes'] or md5.hexdigest() != a['md5']:
        raise ValueError('Clotho archive does not match primary Zenodo checksum')
    temp.replace(dest)
    return dest


def fetch(key, source):
    assert source['license_id'] == 'CC0-1.0'
    dest = CACHE / 'sources' / f'{key}.wav'
    if valid(dest, source):
        return key
    if key.startswith('bank-'):
        with urllib.request.urlopen(source['download_url'], timeout=120) as r:
            data = r.read()
    elif key.startswith('fsd-'):
        a = source['archive']
        h = fsd_bytes(a, a['offset'], 30)
        fields = struct.unpack('<4s5H3I2H', h)
        assert fields[0] == b'PK\x03\x04'
        skip = 30 + fields[-2] + fields[-1]
        compressed = fsd_bytes(a, a['offset'], skip + a['compressed_bytes'])[skip:]
        data = zlib.decompress(compressed, -15) if a['method'] == 8 else compressed
        assert len(data) == a['bytes'] and zlib.crc32(data) == a['crc32']
    else:
        raise ValueError(f'Unexpected source: {key}')
    if len(data) != source['source_bytes'] or hashlib.sha256(data).hexdigest() != source['source_sha256']:
        raise ValueError(f'Source digest mismatch: {key}')
    dest.write_bytes(data)
    return key


def main():
    sources = json.loads((RIGHTS / 'sources.json').read_text())
    (CACHE / 'sources').mkdir(parents=True, exist_ok=True)
    missing = [(k, v) for k, v in sources.items() if k.startswith('clotho-') and not valid(CACHE / 'sources' / f'{k}.wav', v)]
    if missing:
        import py7zr
        archive = get_clotho_archive(missing[0][1]['archive'])
        with py7zr.SevenZipFile(archive) as z:
            z.extract(path=CACHE / 'clotho-extracted', targets=[v['archive']['member'] for _, v in missing])
        for key, source in missing:
            data = (CACHE / 'clotho-extracted' / source['archive']['member']).read_bytes()
            if len(data) != source['source_bytes'] or hashlib.sha256(data).hexdigest() != source['source_sha256']:
                raise ValueError(f'Clotho source digest mismatch: {key}')
            (CACHE / 'sources' / f'{key}.wav').write_bytes(data)
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        futures = [pool.submit(fetch, k, v) for k, v in sources.items() if not k.startswith('clotho-')]
        count = len(sources) - len(futures)
        for future in concurrent.futures.as_completed(futures):
            key = future.result()
            count += 1
            print(f'{count}/{len(sources)} unique CC0 sources verified: {key}', flush=True)
    print('80 file options covered by 77 verified CC0 inputs; radio is original synthesis.')


if __name__ == '__main__':
    main()
