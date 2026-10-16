# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright Invi
"""Hash-register the original Bram/Rina NPC artwork for release/export."""
import os
from common import *

def main():
    rows = []
    base = 'runtime/PalCraft' if (ROOT / 'runtime/PalCraft').exists() else 'runtime/MinecraftBlocks'
    for name in ('bram', 'rina'):
        for source, payload, public in ((f'{base}/Assets/{name}.png', f'Assets/{name}.png', f'runtime/PalCraft/Assets/{name}.png'), (f'release/art/source/{name}-generated.png', None, f'art/source/{name}-generated.png')):
            p = ROOT / source
            rows.append(dict(source=source, sha256=sha(p), clean=True, provenance='ours', license='CC-BY-4.0', pack='islands_animals', payload_relative=payload, public_path=public))
    write_json(ROOT / 'release/art.json', dict(format_version=1, author='Invi', assets=rows))
    print('Registered four original-art files; two game-ready NPC skins')
if __name__ == '__main__':
    main()
