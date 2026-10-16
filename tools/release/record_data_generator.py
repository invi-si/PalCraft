# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright Invi
"""Record readiness only for sources matching a successful private parity run."""
import os
import argparse
from common import *

def main(evidence):
    evidence = Path(evidence)
    evidence = evidence if evidence.is_absolute() else ROOT / evidence
    report = read_json(evidence / 'report.json')
    contract = read_json(ROOT / 'release/data_contract.json')
    modules = [r['module'] for r in contract['modules']]
    assert report['status'] == 'PASS' and report['semantically_equal'] == len(modules) and (report['first_conversion_seconds'] < 2)
    assert report['all_disk_cached'] and report['jar_hash_invalidation'] and report['converter_hash_invalidation'] and report['corrupt_cache_fallback']
    source_names = ['jar_data.lua', 'data_bindings.lua', 'local_data.lua', 'json.lua']
    for name in source_names:
        assert sha(evidence / 'PalCraft' / name) == sha(ROOT / 'runtime/MinecraftBlocks' / name), 'Converter changed since parity run: ' + name
    scripts = ['release/installer/Initialize-LocalData.ps1', 'release/installer/PalCraft-Installer.ps1', 'release/installer/required_assets.json']
    scripts += ['runtime/MinecraftBlocks/' + n for n in source_names]
    write_json(ROOT / 'local/release/data-generator.json', dict(complete=True, modules=modules, minecraft_versions=['1.21.11'], runtime_first_use=True, cache='combined Lua table cache with full source identity inside; bounded Win32 filename', scripts=[dict(source=n, sha256=sha(ROOT / n)) for n in scripts], evidence=evidence.relative_to(ROOT).as_posix(), first_conversion_seconds=report['first_conversion_seconds'], disk_cache_seconds=report['disk_cache_seconds'], semantic_diff='27/27 exact, including numeric keys and array order', extracted_data_bundled=False))
    progress('RS2_G1', 'PASS', '27/27 exact tables; hash-bound generator receipt; ' + str(evidence.relative_to(ROOT)))
    print('RS PASS generator receipt: all sources match private parity evidence')
if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('evidence', type=Path)
    a = p.parse_args()
    main(a.evidence)
