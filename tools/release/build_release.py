# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright Invi
"""Build a hash-verified PalCraft payload, refusing excluded or uncleared assets."""
from __future__ import annotations
import os
import argparse
import shutil
import sys
import uuid
import zipfile
from common import *
from classify_modules import classify_pak

def cleared_original_paks(modules, audit):
    """Reuse only archives whose EVERY audited entry is our original content."""
    groups = {}
    if isinstance(audit.data, list):
        for row in audit.data:
            name = str(row.get('container', '')).replace('\\', '/').rsplit('/', 1)[-1]
            if name.endswith('.pak'):
                groups.setdefault(name, []).append(row)
    result = []
    for row in modules['paks']:
        entries = groups.get(row['name'], [])
        source = ROOT / row['source']
        if entries and len(entries) == row.get('entry_count') and all((audit.effective_provenance(v) == 'ours' and (v.get('action') == 'ship' or audit.effective_provenance(v) != v.get('provenance')) for v in entries)) and source.is_file():
            expected = row.get('sha256')
            if not expected or sha(source) != expected:
                raise ValueError('Original clean pak changed since inventory: ' + row['name'])
            result.append(dict(source=row['source'], destination=row['name'], pack=row['pack'], sha256=expected, clean=True, clearance='all original audited entries ours/ship'))
    return result

def source_path(value):
    path = Path(value)
    path = path if path.is_absolute() else ROOT / path
    resolved = path.resolve(strict=True)
    if not any((resolved.is_relative_to(root.resolve()) for root in (ROOT, ROOT / 'local'))):
        raise ValueError('Build inputs must be staged inside the project/evidence tree')
    return resolved

def build(candidate=False, audit_path=None, paks_path=None):
    check_interrupt()
    progress('RS4_BUILD', 'START', 'candidate' if candidate else 'release')
    modules = read_json(ROOT / 'release/modules.json')
    audit = Audit(audit_path)
    inputs = []
    issues = []
    excluded = []
    seen = set()
    approved_binaries = {}
    excluded_runtime = []
    generated_loaders = []
    tests = [r['module'] for r in modules['lua'] if r['pack'] == 'test']
    runtime_root = Path(modules.get('runtime_source_root', 'runtime/MinecraftBlocks'))
    dist = ROOT / 'release/dist'
    stage = dist / ('.staging-' + uuid.uuid4().hex)
    package = stage / 'PalCraft-v1.0.1'
    package.mkdir(parents=True)
    for pack in PACKS:
        (package / 'payload' / pack).mkdir(parents=True)

    def emit(data, relative, source=None):
        if relative in seen:
            raise ValueError('Duplicate payload destination: ' + relative)
        seen.add(relative)
        target = package / relative
        if not target.resolve().is_relative_to(package.resolve()):
            raise ValueError('Output escaped staging tree')
        target.parent.mkdir(parents=True, exist_ok=True)
        if isinstance(data, bytes):
            target.write_bytes(data)
        else:
            target.write_text(data, encoding='utf-8', newline='\n')
        if source:
            inputs.append(dict(source=str(source), destination=relative, sha256=sha(target)))
    for row in modules['lua']:
        source = ROOT / row['path']
        reasons = audit.reasons(row['path'])
        if row['pack'] == 'test' or reasons:
            excluded.append(dict(path=row['path'], reasons=reasons or ['test']))
            if row['pack'] != 'test' and reasons == ['mojang']:
                relative = Path(row['path']).relative_to(runtime_root).as_posix()
                emit(data_adapter(row['module']), f"payload/{row['pack']}/{MOD}/{relative}")
                generated_loaders.append(row['module'])
            elif row['pack'] != 'test':
                excluded_runtime.append(row['module'])
            continue
        relative = Path(row['path']).relative_to(runtime_root).as_posix()
        text = release_lua(source, source.read_text(encoding='utf-8-sig'), tests)
        if row.get('local_data_adapter'):
            generated_loaders.append(row['module'])
        emit(text, f"payload/{row['pack']}/{MOD}/{relative}", row['path'])
    emit((ROOT / runtime_root / 'config.ini').read_text(), f'payload/core/{MOD}/config.ini')
    emit('', f'payload/core/{MOD}/enabled.txt')
    emit('User skins go here. Vanilla defaults are extracted from your own Minecraft.\n', f'payload/core/{MOD}/skins/README.txt')
    art_path = ROOT / 'release/art.json'
    if art_path.exists():
        for row in read_json(art_path)['assets']:
            if not row.get('payload_relative'):
                continue
            source = source_path(row['source'])
            if row.get('clean') is not True or row.get('provenance') != 'ours' or sha(source) != row['sha256'] or audit.reasons(row['source']):
                raise ValueError('Original-art clearance/hash mismatch')
            relative = f"payload/{row['pack']}/{MOD}/{row['payload_relative']}"
            emit(source.read_bytes(), relative, row['source'])
            approved_binaries[relative] = row['sha256']
            emit(f"SPDX-FileCopyrightText: Invi\nSPDX-License-Identifier: {row['license']}\n", relative + '.license')
    for row in modules['schema']:
        for source in sorted((ROOT / row['path']).rglob('*.json')):
            rel = source.relative_to(ROOT).as_posix()
            reasons = audit.reasons(rel)
            if reasons:
                excluded.append(dict(path=rel, reasons=reasons))
                continue
            relative = source.relative_to(ROOT / row['path']).as_posix()
            relative = re.sub('(^|/)task([\\w]+)\\.json$', '\\1items_\\2.json', relative)
            emit(source.read_bytes(), f"payload/{row['pack']}/{SCHEMA}/{row['destination']}/{relative}", rel)
    paks_manifest = Path(paks_path or ROOT / modules['pak_replacements_manifest'])
    pak_metadata = read_json(paks_manifest) if paks_manifest.exists() else {}
    replacement_receipt = ROOT / (pak_metadata.get('clearance_receipt', 'local/taskRE/blank-paks-receipt.json') if isinstance(pak_metadata, dict) else 'local/taskRE/blank-paks-receipt.json')
    if not replacement_receipt.exists():
        replacement_receipt = ROOT / 'local/taskRA/rebuilt-paks.json'
    replacements = {r['name']: r for r in read_json(replacement_receipt)} if replacement_receipt.exists() else {}
    pak_rows = cleared_original_paks(modules, audit)
    if not paks_manifest.exists():
        issues.append('Clean pack manifest pending; legacy archives deliberately excluded')
    else:
        data = read_json(paks_manifest)
        rows = data.get('paks', []) if isinstance(data, dict) else data
        replacement_names = {r.get('destination', Path(r['source']).name) for r in rows}
        pak_rows = [r for r in pak_rows if r['destination'] not in replacement_names] + rows
    for row in pak_rows:
        source = source_path(row['source'])
        pack = row['pack']
        if source.name.startswith('pakchunk19992-') or 'motion-taskT' in source.name:
            pack = classify_pak(source.name)
        expected = row.get('sha256')
        if pack not in PACKS or pack == 'map_art':
            excluded.append(dict(path=source.name, reasons=['Palworld-derived map art or invalid pack']))
            continue
        reasons = audit.reasons(row['source'])
        replacement = replacements.get(source.name, {})
        original = next((r for r in modules['paks'] if r['name'] == source.name), {})
        if reasons and replacement.get('clean') is True and (replacement.get('sha256') == expected) and (original.get('sha256') != expected):
            reasons = []
        if reasons:
            excluded.append(dict(path=source.name, reasons=reasons))
            continue
        if row.get('clean') is not True or not expected or sha(source) != expected:
            raise ValueError('Pak lacks matching clean-content SHA256 receipt: ' + source.name)
        destination = row.get('destination', source.name)
        if Path(destination).name != destination or not destination.lower().endswith('.pak'):
            raise ValueError('Pak destination must be a plain .pak filename')
        relative = f'payload/{pack}/{PAKS}/{destination}'
        emit(source.read_bytes(), relative, row['source'])
        approved_binaries[relative] = expected
    if not any(('/' + PAKS + '/' in r for r in seen)):
        issues.append('No cleared gameplay pak was supplied')
    if audit.data is None:
        issues.append('Provenance audit pending')
    if excluded_runtime:
        issues.append(f'{len(excluded_runtime)} required runtime data/modules excluded by provenance audit; local replacement generation pending')
    generator_manifest = ROOT / 'local/release/data-generator.json'
    generator = read_json(generator_manifest) if generator_manifest.exists() else {}
    generator_ready = generator.get('complete') is True and set(generated_loaders) <= set(generator.get('modules', ()))
    if generator_ready:
        scripts = generator.get('scripts', [])
        generator_ready = bool(scripts) and all((sha(source_path(r['source'])) == r['sha256'] for r in scripts))
    if generated_loaders and (not generator_ready):
        issues.append(f'Installer generation for {len(generated_loaders)} user-owned data modules pending; shipping code-only adapters')
    cutover_manifest = ROOT / 'local/release/legacy-cutover.json'
    cutover = read_json(cutover_manifest) if cutover_manifest.exists() else {}
    cutover_ready = cutover.get('complete') is True and bool(cutover.get('scripts'))
    if cutover_ready:
        cutover_ready = all((sha(source_path(r['source'])) == r['sha256'] for r in cutover['scripts']))
    if not cutover_ready:
        issues.append('Legacy pak/schema quarantine and restore require a matching offline validation receipt')
    if paks_manifest.exists() and (not isinstance(data, dict) or data.get('complete') is not True):
        issues.append('Asset worker has not marked clean pack set complete')
    if paks_manifest.exists() and (not isinstance(data, dict) or data.get('pack_split_validated') is not True):
        issues.append('Cooked asset dependencies across install choices still need validation')
    if paks_manifest.exists() and (not isinstance(data, dict) or data.get('native_compatibility_ready') is not True):
        issues.append('Native-derived player/NPC rig dependency needs a distributable replacement or local patch')
    for name in ('README.md', 'INSTALL.md', 'RELEASE_NOTES.md', 'BUILD.md', 'CONTRIBUTING.md', 'ARCHITECTURE.md', 'LICENSE', 'LICENSE-ART.md', 'ART_PROMPTS.md', 'THIRD_PARTY.md'):
        source = ROOT / 'release' / name
        if not source.exists():
            source = ROOT / name
        if source.exists():
            emit(source.read_bytes(), name)
    contract = ROOT / 'release/data_contract.json'
    if contract.exists():
        emit(contract.read_bytes(), 'data_contract.json')
    installer = ROOT / 'release/installer'
    for source in sorted(installer.glob('*')):
        if source.is_file() and source.suffix.lower() in ('.ps1', '.bat', '.json', '.md') and (not source.name.startswith('test')):
            emit(source.read_bytes(), 'installer/' + source.name)
    for source in sorted((ROOT / 'release/asset-runtime').glob('*')):
        if source.is_file() and source.suffix.lower() in ('.ps1', '.cs', '.json', '.md'):
            emit(source.read_bytes(), 'asset-runtime/' + source.name)
    emit('Review candidate only; installation is blocked until its manifest is READY.\n' if issues else 'Run installer/Install-PalCraft.bat. The installer uses ../payload in this release.\n', 'START-HERE.txt')
    if issues and (not candidate):
        write_json(package / 'BUILD_BLOCKED.json', dict(status='BLOCKED', reasons=issues))
        progress('RS4_BUILD', 'BLOCKED', '; '.join(issues))
        raise RuntimeError('Release assets/audit incomplete: ' + '; '.join(issues))
    leak_scan(package, approved_binaries=approved_binaries)
    files = [dict(path=p.relative_to(package).as_posix(), bytes=p.stat().st_size, sha256=sha(p)) for p in sorted(package.rglob('*')) if p.is_file()]
    manifest = dict(product='PalCraft', version='1.0.1', status='CANDIDATE' if issues else 'READY', incomplete_reasons=issues, files=files, excluded=excluded, audit_sha256=sha(audit.path) if audit.data else None, modules_sha256=sha(ROOT / 'release/modules.json'), missing_runtime_modules=excluded_runtime, generated_data_modules=generated_loaders, data_generation_ready=generator_ready, legacy_cutover_ready=cutover_ready, dependencies_bundled=False, extracted_assets_bundled=False)
    write_json(package / 'manifest.json', manifest)
    leak_scan(package, approved_binaries=approved_binaries)
    target = dist / 'PalCraft-v1.0.1'
    if target.exists():
        evidence = dist / 'evidence'
        evidence.mkdir(exist_ok=True)
        backup = evidence / ('PalCraft-v1.0.1-' + datetime.now().strftime('%Y%m%d-%H%M%S') + '-' + uuid.uuid4().hex[:6])
        assert target.resolve().is_relative_to(dist.resolve()) and backup.resolve().is_relative_to(evidence.resolve())
        shutil.move(str(target), str(backup))
    shutil.move(str(package), str(target))
    name = 'PalCraft-v1.0.1-CANDIDATE.zip' if issues else 'PalCraft-v1.0.1.zip'
    archive = dist / name
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        for p in sorted(target.rglob('*')):
            if p.is_file() or (p.is_dir() and (not any(p.iterdir()))):
                z.write(p, 'PalCraft-v1.0.1/' + p.relative_to(target).as_posix())
    with zipfile.ZipFile(archive) as z:
        if z.testzip() is not None:
            raise ValueError('Zip CRC verification failed')
    receipt = dict(status=manifest['status'], archive=archive.relative_to(ROOT).as_posix(), sha256=sha(archive), files=len(files), reasons=issues)
    write_json(ROOT / 'local/release/rs' / ('build-' + datetime.now().strftime('%Y%m%d-%H%M%S') + '.json'), receipt)
    progress('RS4_BUILD', 'PASS', f"{receipt['status']} {receipt['archive']} files={len(files)}")
    print(json.dumps(receipt, indent=2))
    return receipt
if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--candidate', action='store_true', help='Produce a clearly marked code-only review archive while assets/audit are pending')
    parser.add_argument('--audit', type=Path)
    parser.add_argument('--paks', type=Path)
    args = parser.parse_args()
    try:
        build(args.candidate, args.audit, args.paks)
    except Exception as error:
        check_interrupt()
        progress('RS4_BUILD', 'FAIL', str(error))
        raise
