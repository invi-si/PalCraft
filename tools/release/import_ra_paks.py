# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright Invi
"""Stage the asset worker's hash-bound partial pak handoff without clearing gaps."""
import os
from common import *
from classify_modules import classify_pak

def main():
    path = ROOT / 'local/taskRA/rebuilt-paks.json'
    source = read_json(path)
    rows = []
    for original in source:
        name = original['name']
        file = ROOT / 'local/taskRA/rebuilt-paks' / name
        assert original.get('clean') is True and sha(file) == original['sha256'], name
        pack = classify_pak(name)
        if name.startswith('pakchunk19992-'):
            pack = 'core'
        if 'motion-taskT' in name:
            pack = 'islands_animals'
        rows.append(dict(source=file.relative_to(ROOT).as_posix(), destination=name, pack=pack, sha256=original['sha256'], clean=True, dependency_notes='Partial legacy-archive grouping; asset dependency split and native rig acceptance remain gated.'))
    write_json(ROOT / 'local/release/paks.json', dict(complete=False, pack_split_validated=False, native_compatibility_ready=False, paks=rows, source_receipt_sha256=sha(path)))
    print('Imported', len(rows), 'cleared partial paks; incomplete/native/split gates retained')
if __name__ == '__main__':
    main()
