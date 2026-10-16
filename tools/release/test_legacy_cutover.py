# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright Invi
"""Test quarantine and restore only against a scratch COPY of the real layout."""
import os
import shutil, subprocess
from common import *

def files(root):
    return {p.relative_to(root).as_posix(): sha(p) for p in root.rglob('*') if p.is_file()}

def run(game):
    check_interrupt()
    progress('RS2_G4', 'TEST', 'read-only owner layout copied to scratch; zero game writes')
    out = evidence_root() / ('cutover-' + datetime.now().strftime('%Y%m%d-%H%M%S'))
    scratch = out / 'game'
    scratch.mkdir(parents=True)
    real = Path(game).resolve()
    assert not scratch.resolve().is_relative_to(real)
    inventory = read_json(ROOT / 'release/installer/legacy_inventory.json')
    mods_rel = Path('Mods/NativeMods/UE4SS/Mods')
    paks = Path('Pal/Content/Paks')
    copied = []
    for p in (real / paks).rglob('*.pak'):
        if p.name in inventory['paks'] and 'PalCraft' not in p.relative_to(real / paks).parts:
            dst = scratch / p.relative_to(real)
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(p, dst)
            copied.append(p.relative_to(real).as_posix())
    for name in inventory['schema']:
        src = real / mods_rel / 'PalSchema/mods' / name
        if src.is_dir():
            shutil.copytree(src, scratch / mods_rel / 'PalSchema/mods' / name)
            copied.append((mods_rel / 'PalSchema/mods' / name).as_posix())
    old = scratch / mods_rel / 'MinecraftBlocks'
    old.mkdir(parents=True, exist_ok=True)
    owner_old = real / mods_rel / 'MinecraftBlocks'
    for p in owner_old.glob('*'):
        if p.is_file() and (p.name == 'enabled.txt' or re.fullmatch('[\\w-]+-[a-fA-F0-9]{32}\\.(?:json|txt)(?:\\.(?:tmp|bak|previous))?', p.name)):
            shutil.copyfile(p, old / p.name)
            copied.append((mods_rel / 'MinecraftBlocks' / p.name).as_posix())
    (old / 'enabled.txt').write_text('')
    world = 'B' * 32
    (old / f'blocks-{world}.json').write_text('{"sequence":1}')
    new = scratch / mods_rel / 'PalCraft'
    new.mkdir()
    (new / 'keep-current.txt').write_text('current PalCraft files stay')
    unrelated = scratch / paks / '~mods/Unrelated_P.pak'
    unrelated.parent.mkdir(parents=True, exist_ok=True)
    unrelated.write_bytes(b'unrelated mod')
    newpak = scratch / paks / '~mods/PalCraft' / inventory['paks'][0]
    newpak.parent.mkdir()
    newpak.write_bytes(b'current replacement, same basename')
    missing = []
    for row in read_json(ROOT / 'release/modules.json')['paks']:
        if row.get('legacy') and (not any((p.name == row['name'] for p in (scratch / paks).rglob('*.pak') if 'PalCraft' not in p.relative_to(scratch / paks).parts))):
            src = ROOT / row['source']
            dst = scratch / paks / '~mods' / row['name']
            shutil.copyfile(src, dst)
            missing.append(row['name'])
    script = ROOT / 'release/installer/migrate-legacy.ps1'

    def migrate(dry=False):
        args = ['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', '& {param($script,$old,$new,$game,$dry) @(& $script -LegacyDir $old -TargetDir $new -GameRoot $game -WhatIf:([bool]$dry)) | ConvertTo-Json -Depth 10} ' + ' '.join(("'" + str(x).replace("'", "''") + "'" for x in (script, old, new, scratch))) + (' 1' if dry else ' 0')]
        result = subprocess.run(args, capture_output=True, text=True, encoding='utf-8')
        assert result.returncode == 0, result.stderr
        return json.loads(result.stdout) if result.stdout.strip() else []
    before = files(scratch)
    dry = migrate(True)
    assert files(scratch) == before
    conflict = new / f'blocks-{world}.json'
    conflict.write_text('{"sequence":99}')
    blocked = migrate()
    assert any((r['Status'] == 'conflict' for r in blocked))
    assert not (scratch / 'PalCraft-legacy-backup').exists()
    shutil.move(str(conflict), str(out / 'new-sidecar-conflict.json'))
    result = migrate()
    quarantined = [r for r in result if r['Status'] == 'quarantined']
    assert quarantined
    backups = list((scratch / 'PalCraft-legacy-backup').iterdir())
    assert len(backups) == 1
    backup = backups[0]
    manifest = read_json(backup / 'manifest.json')
    assert manifest['complete']
    for row in manifest['moves']:
        assert not (scratch / row['relative']).exists()
        for f in row['files']:
            assert sha(backup / f['relative']) == f['sha256'].lower()
    assert newpak.read_bytes() == b'current replacement, same basename' and unrelated.read_bytes() == b'unrelated mod'
    again = migrate()
    assert all((r['Status'] == 'identical' for r in again))
    before_restore = files(scratch)
    restore = ['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(backup / 'Restore-Legacy.ps1')]

    def restore_run(extra=()):
        r = subprocess.run(restore + list(extra), capture_output=True, text=True)
        return r
    r = restore_run(['-WhatIf'])
    assert r.returncode == 0, r.stderr
    assert files(scratch) == before_restore
    first = manifest['moves'][0]
    collision = scratch / first['relative']
    collision.parent.mkdir(parents=True, exist_ok=True)
    collision.write_text('do not overwrite')
    r = restore_run()
    assert r.returncode != 0 and 'conflict' in r.stderr.lower()
    shutil.move(str(collision), str(out / 'restore-conflict.txt'))
    r = restore_run()
    assert r.returncode == 0, r.stderr
    for rel, h in before.items():
        assert sha(scratch / rel) == h, rel
    r = restore_run()
    assert r.returncode == 0, r.stderr
    report = dict(status='PASS', real_layout_read_only=True, real_layout_entries_copied=copied, archive_copies_from_original_evidence=missing, dry_run_zero_writes=True, sidecar_conflict_blocks_cutover=True, quarantine_moves=len(quarantined), quarantine_files=sum((len(r['files']) for r in manifest['moves'])), restore_hash_equal=True, restore_conflict_zero_moves=True, restore_dry_run_zero_writes=True, repeat_idempotent=True, current_and_unrelated_paks_unchanged=True, game_launched=False)
    write_json(out / 'report.json', report)
    print('RS PASS legacy cutover:', len(quarantined), 'moves;', out.relative_to(ROOT))
    return report
if __name__ == '__main__':
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument('--game', type=Path, required=True)
    a = p.parse_args()
    try:
        run(a.game)
    except Exception as error:
        check_interrupt()
        progress('RS2_G4', 'FAIL', str(error).splitlines()[0] if str(error) else repr(error))
        raise
