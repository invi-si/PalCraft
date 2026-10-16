# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright Invi
"""Stage VB's UI overlay as a separate v1.1 candidate; never deploy or launch."""
from __future__ import annotations
import os
import argparse
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile
from common import ROOT, MOD, PAKS, check_interrupt, deps, leak_scan, read_json, release_lua, sha, write_json
from build_creative_candidate import rebuild_archive, verify_archive
from recover_candidate_inputs import log
os.environ.setdefault('PALCRAFT_TASK_PREFIX', 'VB')
RUNTIME = ['creative_catalog.lua', 'creative_layout.lua', 'creative_ui.lua', 'phase_b.lua', 'stringsCM.lua', 'ui_kit.lua']

def build(candidate, output):
    check_interrupt()
    candidate, output = (Path(candidate).absolute(), Path(output).absolute())
    assert candidate.resolve() != output.resolve(), 'Keep the game worker shared archive intact'
    assert output.parent.resolve() == (ROOT / 'release/dist').resolve()
    assert not output.exists(), 'Preserve previous candidate output; choose a unique name'
    original_hash = sha(candidate)
    log('VB_PACKAGE', 'START', 'separate sparse overlay; shared/game-worker candidate untouched')
    out = ROOT / 'local/taskVB'
    package = out / ('overlay-' + datetime.now().strftime('%Y%m%d-%H%M%S')) / 'PalCraft-v1.1-CANDIDATE'
    package.mkdir(parents=True)
    with zipfile.ZipFile(candidate) as z:
        root = z.namelist()[0].split('/')[0]
        info = json.loads(z.read(root + '/manifest.json'))
        before = {r['path']: r for r in info['files']}
        for name in ('cooked-patches.json', 'texture-recipes.json'):
            expected = sha(out / 'source-before/release/asset-runtime' / name)
            assert before['asset-runtime/' + name]['sha256'] == expected, 'Asset manifest changed; explicitly merge/rebase: ' + name
        for row in info['files']:
            digest = hashlib.sha256()
            with z.open(root + '/' + row['path']) as f:
                for b in iter(lambda: f.read(1024 * 1024), b''):
                    digest.update(b)
            assert digest.hexdigest() == row['sha256'], row['path']
    assert info['status'] == 'CANDIDATE' and info['version'] == '1.1-CANDIDATE'
    modules = read_json(ROOT / 'release/modules.json')
    by_name = {r['module']: r for r in modules['lua']}
    tests = [r['module'] for r in modules['lua'] if r['pack'] == 'test']
    changed = {}

    def emit(rel, data):
        target = package / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        changed[rel] = dict(path=rel, bytes=len(data), sha256=hashlib.sha256(data).hexdigest())
    for name in RUNTIME:
        source = ROOT / 'runtime/MinecraftBlocks' / name
        pack = by_name[source.stem]['pack']
        content = release_lua(source, source.read_text(encoding='utf-8-sig'), tests)
        emit('payload/' + pack + '/' + MOD + '/' + name, content.encode('utf-8'))
    for name in ('cooked-patches.json', 'texture-recipes.json'):
        emit('asset-runtime/' + name, (ROOT / 'release/asset-runtime' / name).read_bytes())
    for name in ('BUILD.md', 'CREATIVE_MODE.md'):
        emit(name, (ROOT / 'release' / name).read_bytes())
    asset_report = read_json(out / 'creative-assets/asset-build.json')
    pak = ROOT / asset_report['pak']
    assert sha(pak) == asset_report['sha256']
    emit('payload/hud_skins/' + PAKS + '/' + pak.name, pak.read_bytes())
    info.update(status='CANDIDATE', live_verified=False, modules_sha256=sha(ROOT / 'release/modules.json'))
    reason = 'VB Creative UI: Opus ko/en 100%/150% visual approval and native input/delete acceptance pending'
    info['incomplete_reasons'] = list(dict.fromkeys(info.get('incomplete_reasons', []) + [reason]))
    info['taskVB'] = dict(status='OFFLINE_PASS_VISUAL_AND_LIVE_PENDING', base_candidate_sha256=original_hash, added_pak=pak.name, added_blank_texture_identities=5, original_63_paks_byte_identical=True, no_user_pixels_bundled=True, game_launches=0, live_verified=False, opus_visual_approved=False, preview_gui_texel_scales=[4, 6], preview_languages=['en', 'ko'])
    files = dict(before)
    files.update(changed)
    info['files'] = sorted(files.values(), key=lambda r: r['path'])
    approved = {r['path']: r['sha256'] for r in info['files']}
    leak_scan(package, approved_binaries=approved)
    write_json(package / 'manifest.json', info)
    pending = output.with_name('.VB-' + output.name)
    assert not pending.exists()
    rebuild_archive(candidate, pending, package, info['files'], before)
    verify_archive(pending, package, info)
    assert sha(candidate) == original_hash, 'Input candidate changed concurrently'
    check_interrupt()
    os.replace(pending, output)
    digest = sha(output)
    output.with_name(output.name + '.sha256').write_text(digest + '  ' + output.name + '\n', encoding='ascii')
    graph_root = out / 'packaged-lua'
    with zipfile.ZipFile(output) as z:
        for entry in z.namelist():
            rel = entry.split('/', 1)[1]
            if rel.startswith('payload/') and rel.endswith('.lua'):
                dest = graph_root / rel
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_bytes(z.read(entry))
    env = dict(os.environ, PALCRAFT_TEST_OUTPUT=str(out), PALCRAFT_TASK_PREFIX='VB', MC_LUA54_DIR=os.environ.get('MC_LUA54_DIR', str(out / 'tools/lua54-tool')))
    fixtures = ROOT / 'local/release/rs/data-fixtures-20261016-153014'
    graph = subprocess.run([sys.executable, '-X', 'utf8', str(ROOT / 'tools/release/test_module_graph.py'), '--payload', str(graph_root / 'payload'), '--generated-data', str(fixtures)], cwd=ROOT, env=env, capture_output=True, encoding='utf-8')
    (out / 'packaged-module-graph.log').write_text(graph.stdout + graph.stderr, encoding='utf-8')
    assert graph.returncode == 0, graph.stdout + graph.stderr
    differences = [dict(path=k, before_sha256=before.get(k, {}).get('sha256'), sha256=v['sha256']) for k, v in changed.items() if before.get(k, {}).get('sha256') != v['sha256']]
    report = dict(status='PASS', candidate=output.relative_to(ROOT).as_posix(), sha256=digest, bytes=output.stat().st_size, base_candidate_sha256=original_hash, changed_files=differences, manifest_files=len(info['files']), zip_crc_and_all_sha256='PASS', packaged_six_configuration_graph='PASS', original_paks_identical=sum((r['path'].endswith('.pak') for r in before.values())), source_overlay=package.relative_to(ROOT).as_posix(), game_touched=False, live_verified=False, shared_candidate_unchanged=True)
    write_json(out / 'candidate-verification.json', report)
    log('VB_PACKAGE', 'PASS', f"{len(info['files'])} hashes/ZIP CRC; six pack configurations; separate ZIP {digest}")
    print('VB staged', output.name, digest)
    print(graph.stdout.strip())
    return report
if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--candidate', type=Path, default=ROOT / 'local/taskCW/PalCraft-v1.1-CW-20261016-191640-519223.zip')
    p.add_argument('--output', type=Path, default=ROOT / 'release/dist/PalCraft-v1.1-VB-CANDIDATE.zip')
    a = p.parse_args()
    build(a.candidate, a.output)
