# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright Invi
"""Overlay Creative mode onto the existing v1.1 audio candidate, offline only.

No released v1.0 archive, game installation, save or user asset store is written.
The input candidate is preserved by hash before replacing the candidate ZIP.
"""
from __future__ import annotations
import os
import argparse
import copy
from datetime import datetime
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import zipfile
from common import ROOT, MOD, check_interrupt, leak_scan, read_json, release_lua, sha, write_json
RUNTIME = ['Scripts/main.lua', 'world_mode.lua', 'creative_mode.lua', 'creative_ui.lua', 'stringsCM.lua', 'config.lua', 'config.ini', 'feature_flags.lua', 'language.lua', 'phase_a.lua', 'phase_b.lua', 'phase_c.lua', 'phase_d.lua', 'menu_input.lua', 'mechanics.lua', 'mobs.lua', 'beds.lua', 'elytra104.lua']

def rebuild_archive(original, target, package, files, old_files):
    """Keep unchanged compressed records verbatim; compress only changed files."""
    wanted = {row['path']: row for row in files}
    written = set()
    with zipfile.ZipFile(original) as old, zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as new:
        entries = old.infolist()
        for i, entry in enumerate(entries):
            rel = entry.filename.split('/', 1)[1]
            if rel not in wanted:
                continue
            row = wanted[rel]
            if old_files.get(rel, {}).get('sha256') != row['sha256']:
                continue
            limit = entries[i + 1].header_offset if i + 1 < len(entries) else old.start_dir
            old.fp.seek(entry.header_offset)
            info = copy.copy(entry)
            info.header_offset = new.fp.tell()
            new._writecheck(info)
            new._didModify = True
            remaining = limit - entry.header_offset
            while remaining:
                data = old.fp.read(min(1024 * 1024, remaining))
                assert data, 'Truncated input ZIP record'
                new.fp.write(data)
                remaining -= len(data)
            new.filelist.append(info)
            new.NameToInfo[info.filename] = info
            new.start_dir = new.fp.tell()
            written.add(rel)
        for rel in sorted(set(wanted) - written):
            new.write(package / rel, package.name + '/' + rel)
        new.write(package / 'manifest.json', package.name + '/manifest.json')

def event(item, status, detail):
    with (ROOT / 'coordination/CODEX_PROGRESS.txt').open('a', encoding='utf-8') as f:
        f.write(f'CM {datetime.now():%H:%M} {item} {status} {detail}\n')

def build():
    check_interrupt()
    event('CM_PACKAGE', 'START', 'overlay latest v1.1 candidate; immutable releases untouched')
    out = ROOT / 'local/taskCM'
    out.mkdir(parents=True, exist_ok=True)
    archive = ROOT / 'release/dist/PalCraft-v1.1-CANDIDATE.zip'
    input_sha = sha(archive)
    original = out / 'inputs' / (input_sha + '.zip')
    original.parent.mkdir(parents=True, exist_ok=True)
    if not original.exists():
        shutil.copy2(archive, original)
    assert sha(original) == input_sha
    stage = out / ('package-' + datetime.now().strftime('%Y%m%d-%H%M%S-%f'))
    stage.mkdir()
    with zipfile.ZipFile(original) as z:
        roots = {n.split('/')[0] for n in z.namelist()}
        assert roots == {'PalCraft-v1.1-CANDIDATE'}, roots
        for n in z.namelist():
            dest = (stage / n).resolve()
            assert dest.is_relative_to(stage.resolve()) and (not n.startswith(('/', '\\')))
        z.extractall(stage)
    package = stage / 'PalCraft-v1.1-CANDIDATE'
    info = read_json(package / 'manifest.json')
    assert info['version'] == '1.1-CANDIDATE' and info['status'] == 'CANDIDATE'
    before = {r['path']: r for r in info['files']}
    for rel, row in before.items():
        assert sha(package / rel) == row['sha256'], 'Input manifest mismatch: ' + rel
    modules = read_json(ROOT / 'release/modules.json')
    by_name = {r['module']: r for r in modules['lua']}
    tests = [r['module'] for r in modules['lua'] if r['pack'] == 'test']
    edited = []
    for name in RUNTIME:
        source = ROOT / 'runtime/MinecraftBlocks' / name
        pack = 'core' if name.endswith('.ini') else by_name[source.stem]['pack']
        dest = package / 'payload' / pack / MOD / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        data = release_lua(source, source.read_text(encoding='utf-8-sig'), tests) if source.suffix == '.lua' else source.read_text(encoding='utf-8-sig')
        dest.write_text(data, encoding='utf-8', newline='\n')
        edited.append(source.relative_to(ROOT).as_posix())
    installer = package / 'installer/PalCraft-Installer.ps1'
    old = installer.read_text(encoding='utf-8-sig')
    source = ROOT / 'release/installer/PalCraft-Installer.ps1'
    version = re.search("\\$script:InstallerVersion = '([^']+)'", old)[1]
    data = re.sub("\\$script:InstallerVersion = '[^']+'", f"$script:InstallerVersion = '{version}'", source.read_text(encoding='utf-8-sig'), count=1)
    installer.write_text(data, encoding='utf-8', newline='\n')
    edited.append(source.relative_to(ROOT).as_posix())
    guide = ROOT / 'release/CREATIVE_MODE.md'
    shutil.copy2(guide, package / 'CREATIVE_MODE.md')
    section = (ROOT / 'release/README.md').read_text(encoding='utf-8-sig').split('## Creative mode (v1.1 candidate)', 1)[1]
    readme = package / 'README.md'
    old = readme.read_text(encoding='utf-8-sig')
    if '## Creative mode (v1.1 candidate)' in old:
        old = old.split('## Creative mode (v1.1 candidate)', 1)[0]
    readme.write_text(old.rstrip() + '\n\n## Creative mode (v1.1 candidate)' + section, encoding='utf-8')
    (package / 'PLAYER_GUIDE.md').write_text('# Player guide — v1.1 Creative addition\n\nSee README.md for the baseline pack overview and CREATIVE_MODE.md for full bilingual controls.\n\n## Creative mode (v1.1 candidate)' + section, encoding='utf-8')
    info.update(status='CANDIDATE', live_verified=False)
    reason = 'Creative mode native input, flight, combat and visual acceptance pending'
    info['incomplete_reasons'] = [r for r in info.get('incomplete_reasons', []) if r != reason] + [reason]
    info['modules_sha256'] = sha(ROOT / 'release/modules.json')
    info['taskCM'] = dict(status='OFFLINE_PASS_LIVE_PENDING', pack='hud_skins', default='survival', sidecar_field='game_mode', sidecar_version=4, legacy_default='survival', no_native_stat_cap_edits=True, game_launches=0, base_candidate_sha256=input_sha, offline_test='tools/taskCM_offline.py', live_verified=False)
    assert all((sha(package / rel) == row['sha256'] for rel, row in before.items() if Path(rel).suffix.lower() in ('.pak', '.png', '.uasset', '.uexp', '.ubulk', '.dll', '.exe')))
    approved = {rel: row['sha256'] for rel, row in before.items()}
    leak_scan(package, approved_binaries=approved)
    info['files'] = [dict(path=p.relative_to(package).as_posix(), bytes=p.stat().st_size, sha256=sha(p)) for p in sorted(package.rglob('*')) if p.is_file() and p != package / 'manifest.json']
    write_json(package / 'manifest.json', info)
    sys.path.insert(0, str(ROOT / 'tools'))
    from lua54_compile import compile_tree
    compiled = {}
    for pack in ('core', 'hud_skins', 'islands_animals'):
        compiled[pack] = compile_tree(package / 'payload' / pack / MOD)
    write_json(out / 'packaged-lua-syntax.json', compiled)
    fixture_dirs = sorted((ROOT / 'local/release/rs').glob('data-fixtures-*'))
    assert fixture_dirs, 'Private local data fixtures are required for packaged graph validation'
    env = dict(os.environ, PALCRAFT_TEST_OUTPUT=str(out), PALCRAFT_TASK_PREFIX='CM')
    result = subprocess.run([sys.executable, '-X', 'utf8', str(ROOT / 'tools/release/test_module_graph.py'), '--payload', str(package / 'payload'), '--generated-data', str(fixture_dirs[-1])], cwd=ROOT, env=env, capture_output=True, text=True, encoding='utf-8')
    (out / 'packaged-module-graph.log').write_text(result.stdout + result.stderr, encoding='utf-8')
    assert result.returncode == 0, result.stdout + result.stderr
    return finish_candidate(out, package, info, before, archive, input_sha, original, compiled, edited)

def finish_candidate(out, package, info, before, archive, input_sha, original, compiled, edited, verified_pending=None):
    pending = Path(verified_pending) if verified_pending else out / ('candidate-' + datetime.now().strftime('%Y%m%d-%H%M%S-%f') + '.zip')
    if verified_pending:
        assert pending.resolve().is_relative_to(out.resolve())
        receipt = read_json(pending.with_name(pending.name + '.verified.json'))
        assert receipt['sha256'] == sha(pending) and receipt['manifest_sha256'] == sha(package / 'manifest.json')
        assert receipt['input_sha256'] == input_sha
    else:
        rebuild_archive(original, pending, package, info['files'], before)
        verify_archive(pending, package, info)
        write_json(pending.with_name(pending.name + '.verified.json'), dict(sha256=sha(pending), manifest_sha256=sha(package / 'manifest.json'), input_sha256=input_sha))
    assert sha(archive) == input_sha, 'Candidate changed concurrently; preserve both and rebase before replacing'
    immutable = read_json(out / 'immutable-before.json')
    assert all((sha(ROOT / 'release/dist' / n) == h for n, h in immutable.items()))
    check_interrupt()
    same_volume = archive.with_name('.CM-' + pending.name)
    assert not same_volume.exists() and same_volume.parent.resolve() == archive.parent.resolve()
    shutil.copy2(pending, same_volume)
    assert sha(same_volume) == sha(pending), 'Candidate copy hash mismatch'
    os.replace(same_volume, archive)
    return record_delivery(out, package, info, before, archive, input_sha, original, compiled, edited, immutable)

def verify_archive(pending, package, info):
    with zipfile.ZipFile(pending) as z:
        import hashlib
        for row in info['files']:
            digest = hashlib.sha256()
            size = 0
            with z.open(package.name + '/' + row['path']) as stream:
                for raw in iter(lambda: stream.read(1024 * 1024), b''):
                    digest.update(raw)
                    size += len(raw)
            assert size == row['bytes'] and digest.hexdigest() == row['sha256'], row['path']

def record_delivery(out, package, info, before, archive, input_sha, original, compiled, edited, immutable):
    final_sha = sha(archive)
    archive.with_name(archive.name + '.sha256').write_text(final_sha + '  ' + archive.name + '\n', encoding='ascii')
    source_files = edited + ['release/modules.json', 'release/CREATIVE_MODE.md', 'README.md', 'PLAYER_GUIDE.md', 'release/README.md', 'tools/taskCM_offline.py', 'tools/taskCM_offline.lua', 'tools/release/build_creative_candidate.py']
    source_final = out / 'source-final'
    source_manifest = []
    for rel in sorted(set(source_files)):
        source = ROOT / rel
        dest = source_final / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, dest)
        prior = out / 'source-before' / rel
        source_manifest.append(dict(path=rel, before_sha256=sha(prior) if prior.exists() else None, sha256=sha(source)))
    patch = ROOT / 'release/dist/PalCraft-v1.1-CM.patch'
    diff = subprocess.run(['git', '-c', 'core.autocrlf=false', 'diff', '--no-index', '--binary', 'local/taskCM/source-before', 'local/taskCM/source-final'], cwd=ROOT, capture_output=True)
    assert diff.returncode in (0, 1), diff.stderr.decode('utf-8', errors='replace')
    raw = diff.stdout
    for side in (b'a/', b'b/'):
        for tree in (b'local/taskCM/source-before/', b'local/taskCM/source-final/'):
            raw = raw.replace(side + tree, side)
    patch.write_bytes(raw)
    patch.with_name(patch.name + '.sha256').write_text(sha(patch) + '  ' + patch.name + '\n', encoding='ascii')
    write_json(out / 'source-manifest.json', source_manifest)
    changes = [r['path'] for r in info['files'] if r['path'] not in before or r['sha256'] != before[r['path']]['sha256']]
    report = dict(status='PASS', archive=archive.relative_to(ROOT).as_posix(), sha256=final_sha, bytes=archive.stat().st_size, manifest_files=len(info['files']), changed_files=changes, input_sha256=input_sha, input_preserved=original.relative_to(ROOT).as_posix(), package=package.relative_to(ROOT).as_posix(), source_final=source_final.relative_to(ROOT).as_posix(), patch=patch.relative_to(ROOT).as_posix(), patch_sha256=sha(patch), binaries_unchanged=True, immutable_releases_unchanged=immutable, lua_compiled=sum((r['files'] for r in compiled.values())), packaged_six_configuration_graph='PASS', leak_scan='PASS', live_verified=False, installer_gui='Not rerun: UI unchanged; offline live-session isolation', game_launches=0)
    write_json(out / 'package-verification.json', report)
    event('CM_PACKAGE', 'PASS', f"{len(info['files'])} files; CRC/hash/leak checks; six isolated configs; SHA256 {final_sha}")
    print('CM candidate rebuilt:', report['archive'], final_sha)
    return report
if __name__ == '__main__':
    argparse.ArgumentParser(description=__doc__).parse_args()
    build()
