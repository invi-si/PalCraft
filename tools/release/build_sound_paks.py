# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright Invi
"""Rebuild authored silent audio paks from a cooked UE5.1 template.

Use the shipped audio manifest only as the original package/source/pack binding
list. All ranges and hashes are regenerated from the supplied silent template.
The input SoundWave must be /Game/MinecraftSA/S_Template, PLATFORM_SPECIFIC,
FORCE_INLINE. Cook its authored 0.1-second mono silence with UE5.1 Windows.
No Minecraft source audio is read by this builder.
"""
import os
import argparse, hashlib, json, tempfile
from pathlib import Path
from cooked_payload import write_pak
from cooked_sound import rename

def build(template, manifest, output):
    old = json.loads(manifest.read_text(encoding='utf8'))
    h = template.with_suffix('.uasset').read_bytes()
    d = template.with_suffix('.uexp').read_bytes()
    output.mkdir(parents=True, exist_ok=True)
    result = {'version': 1, 'format': 'UE5.1 ForceInline OGG Vorbis', 'paks': []}
    temp = Path(tempfile.mkdtemp(prefix='sound-build-', dir=output))
    for pak in old['paks']:
        files = {}
        sounds = []
        for sound in pak['sounds']:
            nh, nd, layout = rename(h, d, sound['package'])
            stem = 'Pal/Content/' + sound['package'].removeprefix('/Game/')
            for ext, data in [('.uasset', nh), ('.uexp', nd)]:
                p = temp / (stem + ext)
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_bytes(data)
                files[stem + ext] = p
            sounds.append(dict(package=sound['package'], file=stem, source=sound['source'], sourceSha1=sound['sourceSha1'], layout=layout))
        info = write_pak(output / pak['name'], files)
        for entry in info['entries']:
            entry['sha256'] = hashlib.sha256(files[entry['path']].read_bytes()).hexdigest()
        info.update(name=pak['name'], pack=pak['pack'], sounds=sounds)
        result['paks'].append(info)
    manifest.write_text(json.dumps(result, indent=2), encoding='utf8')
    return result
if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--template', type=Path, required=True, help='Cooked S_Template path without extension')
    p.add_argument('--manifest', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args()
    r = build(a.template, a.manifest, a.output)
    print(sum((len(x['sounds']) for x in r['paks'])), 'silent SoundWaves')
