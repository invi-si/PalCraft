# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright Invi
"""Build VC's separate offline UI candidate and a sparse six-module overlay."""
from __future__ import annotations
import os
import argparse
from datetime import datetime
import hashlib
import os
from pathlib import Path
import subprocess
import sys
import zipfile
import json
from common import ROOT, MOD, check_interrupt, leak_scan, read_json, release_lua, sha, write_json
from build_creative_candidate import rebuild_archive, verify_archive
RUNTIME = ['creative_catalog.lua', 'creative_layout.lua', 'creative_ui.lua', 'phase_b.lua', 'ui20.lua', 'ui46.lua']
OUT = ROOT / 'local/taskVC'

def scoped_modules():
    """Preserve VA's concurrent manifest; VC adds exactly one dependency."""
    baseline = OUT / 'source-before/release/modules.json'
    modules = read_json(baseline)
    row = next((r for r in modules['lua'] if r['module'] == 'ui20'))
    row['dependencies'] = sorted(set(row['dependencies']) | {'creative_layout'})
    raw = (json.dumps(modules, indent=2, ensure_ascii=False) + '\n').encode('utf-8')
    if b'\r\n' in baseline.read_bytes():
        raw = raw.replace(b'\n', b'\r\n')
    target = OUT / 'modules-vc.json'
    target.write_bytes(raw)
    return (modules, target)

def build(candidate: Path, output: Path):
    os.environ['PALCRAFT_TASK_PREFIX'] = 'VC'
    check_interrupt()
    candidate, output = (candidate.absolute(), output.absolute())
    assert output.parent.resolve() == (ROOT / 'release/dist').resolve()
    assert output.resolve() != candidate.resolve() and (not output.exists())
    original_sha = sha(candidate)
    behavior = read_json(OUT / 'ui-behavior.json')
    preview = read_json(OUT / 'previews/preview-manifest.json')
    assert behavior['status'] == preview['status'] == 'PASS'
    for name, digest in preview['production_source_sha256'].items():
        assert sha(ROOT / 'runtime/MinecraftBlocks' / name) == digest, 'Preview source changed: ' + name
    stamp = datetime.now().strftime('%Y%m%d-%H%M%S')
    package = OUT / ('overlay-' + stamp) / 'PalCraft-v1.1-CANDIDATE'
    package.mkdir(parents=True)
    modules, modules_path = scoped_modules()
    packs = {r['module']: r['pack'] for r in modules['lua']}
    tests = [r['module'] for r in modules['lua'] if r['pack'] == 'test']
    with zipfile.ZipFile(candidate) as z:
        prefix = 'PalCraft-v1.1-CANDIDATE/'
        info = __import__('json').loads(z.read(prefix + 'manifest.json'))
        assert info['status'] == 'CANDIDATE' and (not info['live_verified'])
        before = {r['path']: r for r in info['files']}
        verify_archive(candidate, package, info)
        for name in RUNTIME:
            prior = OUT / 'source-before/runtime/MinecraftBlocks' / name
            rel = 'payload/' + packs[prior.stem] + '/' + MOD + '/' + name
            expected = release_lua(prior, prior.read_text(encoding='utf-8-sig'), tests).encode('utf-8')
            assert z.read(prefix + rel) == expected, 'Baseline changed; explicitly merge: ' + name
    changed = []
    files = dict(before)
    for name in RUNTIME:
        source = ROOT / 'runtime/MinecraftBlocks' / name
        data = release_lua(source, source.read_text(encoding='utf-8-sig'), tests).encode('utf-8')
        rel = 'payload/' + packs[source.stem] + '/' + MOD + '/' + name
        dest = package / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(data)
        row = dict(path=rel, bytes=len(data), sha256=hashlib.sha256(data).hexdigest())
        files[rel] = row
        changed.append(dict(**row, before_sha256=before[rel]['sha256']))
    info.update(status='CANDIDATE', live_verified=False, modules_sha256=sha(modules_path))
    info['taskVC'] = dict(status='OFFLINE_PASS_VISUAL_AND_LIVE_PENDING', base_candidate_sha256=original_sha, runtime_files=RUNTIME, no_asset_changes=True, all_64_paks_unchanged=True, game_launches=0, live_verified=False, opus_visual_approved=False, preview_languages=['en', 'ko'], preview_gui_texel_scales=[4, 6], source_sha256=preview['production_source_sha256'])
    info['incomplete_reasons'] = list(dict.fromkeys(info.get('incomplete_reasons', []) + ['VC Creative UI polish: Opus ko/en 100%/150% visual review and native acceptance pending']))
    info['files'] = sorted(files.values(), key=lambda r: r['path'])
    leak_scan(package, approved_binaries={r['path']: r['sha256'] for r in info['files']})
    write_json(package / 'manifest.json', info)
    pending = output.with_name('.VC-' + output.name)
    assert not pending.exists()
    print('VC rebuilding separate candidate; preserving VB and shared VA archives', flush=True)
    rebuild_archive(candidate, pending, package, info['files'], before)
    verify_archive(pending, package, info)
    graph_root = OUT / ('packaged-lua-' + stamp)
    with zipfile.ZipFile(pending) as z:
        assert len(z.namelist()) == len(info['files']) + 1
        for entry in z.namelist():
            rel = entry.split('/', 1)[1]
            if rel.startswith('payload/') and rel.endswith('.lua'):
                dest = graph_root / rel
                assert dest.resolve().is_relative_to(graph_root.resolve())
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_bytes(z.read(entry))
    env = dict(os.environ, PALCRAFT_TEST_OUTPUT=str(OUT), PALCRAFT_TASK_PREFIX='VC', MC_LUA54_DIR=str(ROOT / 'local/taskVB/tools/lua54-tool'))
    fixtures = ROOT / 'local/release/rs/data-fixtures-20261016-153014'
    graph = subprocess.run([sys.executable, '-X', 'utf8', str(ROOT / 'tools/taskVC_graph.py'), '--payload', str(graph_root / 'payload'), '--generated-data', str(fixtures), '--manifest', str(modules_path)], cwd=ROOT, env=env, capture_output=True, encoding='utf-8')
    (OUT / 'packaged-module-graph.log').write_text(graph.stdout + graph.stderr, encoding='utf-8')
    assert graph.returncode == 0, graph.stdout + graph.stderr
    assert sha(candidate) == original_sha, 'Input archive changed concurrently'
    check_interrupt()
    os.replace(pending, output)
    digest = sha(output)
    output.with_name(output.name + '.sha256').write_text(digest + '  ' + output.name + '\n', encoding='ascii')
    report = dict(status='PASS', candidate=output.relative_to(ROOT).as_posix(), sha256=digest, bytes=output.stat().st_size, base_candidate=candidate.relative_to(ROOT).as_posix(), base_candidate_sha256=original_sha, manifest_files=len(info['files']), changed_files=changed, source_overlay=package.relative_to(ROOT).as_posix(), zip_crc_and_all_sha256='PASS', packaged_six_configuration_graph='PASS', all_paks_unchanged=64, game_launches=0, game_deployments=0, live_verified=False, shared_candidate_written=False)
    write_json(OUT / 'candidate-verification.json', report)
    print('VC candidate PASS ' + digest)
    print('VC ' + graph.stdout.strip().replace('\n', '\nVC '))
    return report
if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--candidate', type=Path, default=ROOT / 'release/dist/PalCraft-v1.1-VB-CANDIDATE.zip')
    p.add_argument('--output', type=Path, default=ROOT / 'release/dist/PalCraft-v1.1-VC-CANDIDATE.zip')
    args = p.parse_args()
    build(args.candidate, args.output)
