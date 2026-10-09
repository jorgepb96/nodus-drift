#!/usr/bin/env python3
"""Record byte identity, metadata and Git history; never infer a recording's license.

Requires ffprobe and local pinned Nodus/Moodist Git repositories. It does not
download audio, send requests to rights holders, or grant/change any license.
Git may fetch metadata/blobs when the supplied repository is a partial clone.
"""
import argparse
import concurrent.futures
import csv
import datetime
import hashlib
import json
import shutil
import subprocess
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NODUS_PIN = '68fa0210dc8407938d644978291840d85aeb49b1'
MOODIST_PIN = '11c0be2200116a3635880d600fd6953899cc51a3'
MIT_RELEASE = 'cfc0f7f03649fe4a6b80bd2ad97b4b7a81aa6441'  # v3.2.7
HISTORICAL_PATHS = [
    'src/components/nodi/Nodi.tsx', 'src/assets/nodus-logo.svg',
    'src/components/nodi/nodi.css',
]
SOURCE_PATHS = [
    *HISTORICAL_PATHS,
    'src/views/ToolkitDriftView.tsx', 'shared/drift.ts',
    'shared/driftCatalog.ts', 'src/components/drift',
]


def git(repo, *args, binary=False):
    return subprocess.check_output(['git', '-C', str(repo), *args], text=not binary)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def history(repo, pin, paths, follow=False):
    args = ['log'] + (['--follow'] if follow else [])
    args += [pin, '--format=%H%x1f%aI%x1f%an%x1f%s', '--', *paths]
    entries = []
    for line in git(repo, *args).splitlines():
        commit, date, author, subject = line.split('\x1f', 3)
        entries.append(dict(commit=commit, date=date, author=author, subject=subject))
    return entries


def audit_recording(sound, moodist, tree, ffprobe):
    data = (ROOT / 'ios/NodusDrift/Resources/Audio' / sound['asset']).read_bytes()
    sha256 = digest(data)
    blob = hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()
    source_path = 'public/sounds/' + sound['asset']
    expected_blob = tree[source_path]
    if sha256 != sound['sha256'] or len(data) != sound['bytes'] or blob != expected_blob:
        raise ValueError('Byte identity failure: ' + sound['asset'])
    metadata = json.loads(subprocess.check_output([
        ffprobe, '-v', 'error', '-show_format', '-show_streams', '-of', 'json',
        str(ROOT / 'ios/NodusDrift/Resources/Audio' / sound['asset']),
    ], text=True))
    format_tags = metadata.get('format', {}).get('tags', {})
    stream_tags = {str(s['index']): s['tags'] for s in metadata.get('streams', []) if s.get('tags')}
    tags = {**format_tags}
    for index, values in stream_tags.items():
        tags.update({f'stream_{index}.{k}': v for k, v in values.items()})
    changes = history(moodist, MOODIST_PIN, [source_path], follow=True)
    if not changes:
        raise ValueError('Missing source history: ' + source_path)
    return dict(
        id=sound['id'], name=sound['name'], category=sound['category'],
        asset=sound['asset'], bytes=len(data), sha256=sha256, git_blob_sha1=blob,
        identity_verified=True, catalog_duration_seconds=sound['duration'],
        ffprobe_duration_seconds=float(metadata['format']['duration']),
        metadata_tags=tags, format_tags=format_tags, stream_tags=stream_tags, upstream_path=source_path,
        upstream_url=f'https://github.com/remvze/moodist/blob/{MOODIST_PIN}/{source_path}',
        first_traced_commit=changes[-1], last_traced_commit=changes[0],
        original_source_url=None, original_creator=None,
        individual_license=None, license_evidence_url=None,
        upstream_license_declaration=['Pixabay Content License', 'CC0-1.0'],
        rights_status='individual provenance and distribution permission unverified',
        cleared_for_app_store=False,
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--nodus-repo', type=Path, required=True)
    parser.add_argument('--moodist-repo', type=Path, required=True)
    parser.add_argument('--out', type=Path, default=ROOT / 'docs/rights')
    args = parser.parse_args()
    ffprobe = shutil.which('ffprobe')
    if not ffprobe:
        parser.error('ffprobe is required')
    for repo, pin in [(args.nodus_repo, NODUS_PIN), (args.moodist_repo, MOODIST_PIN)]:
        git(repo, 'cat-file', '-e', pin + '^{commit}')
    catalog = json.loads((ROOT / 'ios/NodusDrift/Resources/catalog.json').read_text())
    sounds = [s for s in catalog if s['kind'] == 'file']
    if len(sounds) != 81 or len({s['id'] for s in sounds}) != 81:
        raise ValueError('Expected 81 distinct original recordings')
    tree = {}
    for line in git(args.moodist_repo, 'ls-tree', '-r', MOODIST_PIN, 'public/sounds').splitlines():
        details, path = line.split('\t', 1)
        tree[path] = details.split()[2]
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        recordings = list(pool.map(
            lambda s: audit_recording(s, args.moodist_repo, tree, ffprobe), sounds))
    timestamp = datetime.datetime.now(datetime.timezone.utc).isoformat()
    summary = dict(recordings=81, identity_verified=sum(r['identity_verified'] for r in recordings),
                   individual_original_sources_verified=0, individual_licenses_verified=0,
                   cleared_for_app_store=0, total_bytes=sum(r['bytes'] for r in recordings),
                   metadata_tag_counts=dict(Counter(tuple(sorted(r['metadata_tags'])) for r in recordings)))
    # JSON object keys must be strings; retain counts without making provenance claims.
    summary['metadata_tag_counts'] = {
        ','.join(k) or '(none)': v for k, v in summary['metadata_tag_counts'].items()}
    audio_report = dict(audited_at_utc=timestamp, moodist_pin=MOODIST_PIN,
                        catalog_sha256=digest((ROOT / 'ios/NodusDrift/Resources/catalog.json').read_bytes()),
                        summary=summary, recordings=recordings)
    historical_files = []
    for path in HISTORICAL_PATHS:
        current = git(args.nodus_repo, 'show', NODUS_PIN + ':' + path, binary=True)
        old = git(args.nodus_repo, 'show', MIT_RELEASE + ':' + path, binary=True)
        historical_files.append(dict(path=path, current_sha256=digest(current),
                                     historical_mit_sha256=digest(old), identical=current == old))
    first_party = dict(
        audited_at_utc=timestamp, nodus_pin=NODUS_PIN, upstream_license='AGPL-3.0-only',
        historical_mit_release=dict(tag='v3.2.7', commit=MIT_RELEASE,
                                    license_sha256=digest(git(args.nodus_repo, 'show', MIT_RELEASE + ':LICENSE', binary=True))),
        historical_mit_files=historical_files,
        scoped_upstream_history=history(args.nodus_repo, NODUS_PIN, SOURCE_PATHS),
        native_swift_files=[dict(path=str(p.relative_to(ROOT)), sha256=digest(p.read_bytes()))
                            for p in sorted([
                                *(p for folder in ['NodusDrift', 'NodusDriftTests', 'NodusDriftUITests']
                                  for p in (ROOT / 'ios' / folder).rglob('*.swift')),
                                ROOT / 'scripts/render_icon.swift',
                            ])],
        conclusions_not_automated='Git attribution and matching bytes are evidence; not a warranty of title or an Apple license grant.',
    )
    args.out.mkdir(parents=True, exist_ok=True)
    (args.out / 'audio-recordings.json').write_text(json.dumps(audio_report, indent=2, ensure_ascii=False) + '\n')
    (args.out / 'first-party-material.json').write_text(json.dumps(first_party, indent=2, ensure_ascii=False) + '\n')
    fields = ['id', 'name', 'category', 'asset', 'bytes', 'sha256', 'git_blob_sha1',
              'identity_verified', 'first_commit', 'first_commit_date', 'metadata_tags',
              'original_source_url', 'original_creator', 'individual_license',
              'license_evidence_url', 'cleared_for_app_store', 'upstream_url']
    with (args.out / 'audio-recordings.csv').open('w', newline='') as stream:
        writer = csv.DictWriter(stream, fieldnames=fields, lineterminator='\n')
        writer.writeheader()
        for recording in recordings:
            row = {k: recording.get(k) for k in fields}
            row.update(first_commit=recording['first_traced_commit']['commit'],
                       first_commit_date=recording['first_traced_commit']['date'],
                       metadata_tags=json.dumps(recording['metadata_tags'], ensure_ascii=False, sort_keys=True))
            writer.writerow(row)
    print(json.dumps(summary, indent=2))
    print('Historical MIT byte matches:', all(x['identical'] for x in historical_files))
    print('Evidence written to:', args.out)


if __name__ == '__main__':
    main()
