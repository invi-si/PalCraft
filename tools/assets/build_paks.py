# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright Invi
"""Cook an editable UE project and pack explicit, disjoint package lists."""
from __future__ import annotations
import os
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
ROOT = Path(__file__).resolve().parents[2]

def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ue-root', type=Path, default=os.environ.get('PALCRAFT_UE_ROOT'))
    parser.add_argument('--project', type=Path, default=ROOT / 'project/Pal.uproject')
    parser.add_argument('--output', type=Path, default=ROOT / 'local/build')
    parser.add_argument('--pack-map', type=Path, required=True, help='JSON mapping pack names to cooked Content-relative package paths')
    parser.add_argument('--cook', action='store_true')
    args = parser.parse_args()
    if not args.ue_root:
        parser.error('Set PALCRAFT_UE_ROOT or --ue-root')
    output = args.output.resolve()
    if not output.is_relative_to(ROOT.resolve()) or output == ROOT.resolve():
        raise ValueError('Use a dedicated output directory inside this source checkout')
    output.mkdir(parents=True, exist_ok=True)
    binaries = args.ue_root / 'Engine/Binaries/Win64'
    cooked = output / 'Cooked/Windows/Pal/Content'
    if args.cook:
        command = [str(binaries / 'UnrealEditor-Cmd.exe'), str(args.project.resolve()), '-run=Cook', '-TargetPlatform=Windows', '-unattended', '-nop4', '-NullRHI', '-UTF8Output', '-NoLiveCoding', '-OutputDir=' + str(output / 'Cooked'), '-abslog=' + str(output / 'cook.log')]
        with (output / 'cook-console.log').open('w', encoding='utf-8') as log:
            subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True)
    mapping = json.loads(args.pack_map.read_text(encoding='utf-8'))
    used = set()
    receipts = []
    for pack, packages in mapping.items():
        if pack not in ('core', 'hud_skins', 'islands_animals', 'map_art'):
            raise ValueError('Unknown pack: ' + pack)
        lines = []
        members = []
        for package in sorted(packages):
            relative = package.removeprefix('/Game/').removesuffix('.uasset')
            if Path(relative).is_absolute() or '..' in Path(relative).parts or relative.startswith('Pal/'):
                raise ValueError('Only original Content-relative packages may be packed')
            if relative in used:
                raise ValueError('Shared package must live in Core once: ' + relative)
            used.add(relative)
            found = False
            for suffix in ('.uasset', '.uexp', '.ubulk', '.uptnl'):
                source = (cooked / (relative + suffix)).resolve()
                if not source.is_relative_to(cooked.resolve()):
                    raise ValueError('Cooked input escaped Content directory')
                if source.is_file():
                    found = True
                    mount = '../../../Pal/Content/' + relative + suffix
                    lines.append('"' + str(source) + '" "' + mount + '"')
                    members.append(dict(path=relative + suffix, sha256=sha(source)))
            if not found:
                raise FileNotFoundError('Cooked package missing: ' + relative)
        response = output / (pack + '-response.txt')
        response.write_text('\n'.join(lines) + '\n', encoding='utf-8')
        pak = output / ('PalCraft-' + pack + '_P.pak')
        with (output / (pack + '-pak.log')).open('w', encoding='utf-8') as log:
            subprocess.run([str(binaries / 'UnrealPak.exe'), str(pak), '-Create=' + str(response), '-compress'], stdout=log, stderr=subprocess.STDOUT, check=True)
        receipts.append(dict(source=pak.relative_to(ROOT).as_posix(), pack=pack, sha256=sha(pak), clean=False, members=members))
    (output / 'paks.json').write_text(json.dumps(dict(complete=False, paks=receipts), indent=2) + '\n')
    print('Built', len(receipts), 'paks. Review provenance before marking clean/complete.')
if __name__ == '__main__':
    main()
