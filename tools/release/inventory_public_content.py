# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright Invi
"""Find original audited modding-kit source packages for a clean-source export.

This never changes source assets. Uncertain, copied and private-metadata packages
are recorded for review rather than given provenance clearance.
"""
import os
from collections import defaultdict
import argparse
from common import *

def inventory(content_root):
    audit = Audit()
    assert isinstance(audit.data, list), 'An asset-level audit is required'
    records = defaultdict(list)
    for row in audit.data:
        path = Audit.canonical(row['path'])
        if path.startswith('content/'):
            records[path].append(row)
    approved, excluded, private = ([], [], [])
    drive = re.compile(b'(?<![A-Za-z])[A-Za-z]:[\\\\/][A-Za-z0-9_ .-]{3}')
    private_name = bytes((100, 97, 110, 105, 101))
    for p in sorted(Path(content_root).glob('**/*.uasset')):
        rel = p.relative_to(content_root).as_posix()
        if not rel.startswith(('Minecraft', 'CustomPals')):
            continue
        rows = records.get('content/' + rel.lower(), [])
        if not rows or any((audit.effective_provenance(r) != 'ours' for r in rows)):
            excluded.append(dict(path=rel, reason='Provenance exclusion or no clearance'))
            continue
        raw = p.read_bytes()
        if private_metadata(raw, binary=True):
            private.append(dict(path=rel, reason='Import/source metadata requires scrubbing'))
            continue
        approved.append(dict(path=rel, source=p.relative_to(ROOT).as_posix() if p.is_relative_to(ROOT) else rel, sha256=sha(p), clean=True, provenance='ours', license='CC-BY-4.0'))
    output = dict(complete=False, assets=approved, excluded=excluded, private_metadata=private, note='Only original audited packages with no absolute source metadata. Excluded geometry is unchanged while its owner decision is pending.')
    write_json(ROOT / 'local/release/source-assets.json', output)
    print(json.dumps(dict(original_clean=len(approved), provenance_excluded=len(excluded), private_metadata=len(private), custom_pal_packages=sum((r['path'].startswith('CustomPals') for r in approved))), indent=2))
if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--content-root', type=Path, required=True)
    inventory(p.parse_args().content_root)
