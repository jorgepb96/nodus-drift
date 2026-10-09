#!/usr/bin/env python3
"""Check replacement identity, permissions evidence and silent technical checks."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
D = ROOT / 'docs/rights/replacement-audio'


def main():
    old = json.loads((D / 'baseline-catalog.json').read_text())
    new = json.loads((ROOT / 'ios/NodusDrift/Resources/catalog.json').read_text())
    report = json.loads((D / 'build-report.json').read_text())
    sources = json.loads((D / 'sources.json').read_text())
    recipes = json.loads((D / 'recipes.json').read_text())['recipes']
    outputs = {v['id']: v for v in report['outputs']}
    assert len(old) == len(new) == 89
    assert len(outputs) == len(recipes) == 81
    assert report['playback_performed'] is False
    for original, sound in zip(old, new):
        for field in ['id', 'name', 'detail', 'category', 'icon', 'kind', 'asset']:
            assert original.get(field) == sound.get(field), (sound['id'], field)
        if sound['kind'] != 'file':
            assert sound == original, sound['id']
            continue
        output = outputs[sound['id']]
        data = (ROOT / 'ios/NodusDrift/Resources/Audio' / sound['asset']).read_bytes()
        sha = hashlib.sha256(data).hexdigest()
        assert len(data) == sound['bytes'] == output['bytes']
        assert sha == sound['sha256'] == output['sha256'] and sha != original['sha256']
        assert abs(sound['bytes'] / original['bytes'] - 1) <= 0.01
        assert sound['licenseStatus'] == 'verified' and sound['licenseId'] == output['license_id']
        assert sound['crossfadeMs'] == 200
        assert output['sample_rate'] == 44100 and output['channels'] in (1, 2)
        checks = output['checks']
        assert checks['finite'] and checks['peak_dbfs'] <= -2 and checks['rms_dbfs'] >= -32
        assert checks['dc_max'] < 0.002
        source = sources.get(output['source'])
        if source:
            assert source['license_id'] == 'CC0-1.0'
            assert source['author'] and source['page_url'] and source['source_sha256']
            if output['source'].startswith('bank-'):
                evidence = ROOT / source['evidence_file']
                assert hashlib.sha256(evidence.read_bytes()).hexdigest() == source['evidence_sha256']
                assert 'CC0 (public domain)' in evidence.read_text()
            elif output['source'].startswith('fsd-'):
                assert '/zero/1.0/' in source['primary_metadata_row']['license']
            else:
                assert '/zero/1.0/' in source['metadata_row']['license']
        else:
            assert sound['id'] == 'tuning-radio'
    expected = {v['asset'] for v in new if v['kind'] == 'file'}
    bundled = {str(p.relative_to(ROOT / 'ios/NodusDrift/Resources/Audio')) for p in (ROOT / 'ios/NodusDrift/Resources/Audio').rglob('*.mp3')}
    assert expected == bundled
    summary = dict(date='2026-10-09', loop_files=81, replaced_files=81, retained_total_options=89, cc0_based_options=80, unique_cc0_sources=len(sources), original_radio_options=1, native_generators_unchanged=8, min_byte_change_percent=min(v['byte_change_percent'] for v in outputs.values()), max_byte_change_percent=max(v['byte_change_percent'] for v in outputs.values()), old_total_bytes=sum(v['bytes'] for v in old if v['kind'] == 'file'), new_total_bytes=sum(v['bytes'] for v in new if v['kind'] == 'file'), min_rms_dbfs=min(v['checks']['rms_dbfs'] for v in outputs.values()), max_peak_dbfs=max(v['checks']['peak_dbfs'] for v in outputs.values()), playback_performed=False, all_checks_passed=True)
    (D / 'audit-summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()
