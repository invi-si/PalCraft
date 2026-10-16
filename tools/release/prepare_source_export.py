# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright Invi
"""Bind the asset worker's cleared source hashes to its blanking receipt."""
import os
from common import *
from scrub_source_metadata import scrub

def main():
    source_manifest = ROOT / 'local/release/source-assets.json'
    blanks_path = ROOT / 'local/taskRA/blank-result.json'
    source = read_json(source_manifest)
    blanks = read_json(blanks_path)
    audit = Audit()
    assert source.get('complete') is True and blanks.get('complete') is True
    packages = set(blanks.get('packages', ()))
    packages -= {v.get('package') for v in blanks.get('errors', ()) if isinstance(v, dict)}
    rows = []
    denied = []
    metadata_changes = []
    override_root = ROOT / 'local/release/rs' / ('source-overrides-' + datetime.now().strftime('%Y%m%d-%H%M%S'))
    for original in source['assets']:
        row = dict(original)
        path = row['path']
        reasons = audit.reasons('Content/' + path)
        if reasons:
            package = '/Game/' + path.removesuffix('.uasset')
            if reasons == ['mojang'] and package in packages:
                row.update(replacement_method='blank-placeholder', blank_receipt_sha256=sha(blanks_path))
            else:
                denied.append(dict(path=path, reasons=reasons))
                continue
        row['license'] = audit.asset_license('Content/' + path)
        if path in ('MinecraftMobs/T_arrow.uasset', 'MinecraftMobs/T_poof.uasset'):
            original_path = Path(source['contentRoot']) / path
            raw = original_path.read_bytes()
            assert hashlib.sha256(raw).hexdigest() == row['sha256']
            if private_metadata(raw, binary=True):
                clean, spans = scrub(raw, Path(path).stem)
                if not spans or private_metadata(clean, binary=True):
                    denied.append(dict(path=path, reasons=['Unrecognized private import metadata after procedural source restoration']))
                    continue
                target = override_root / path
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(clean)
                row.update(original_sha256=row['sha256'], sha256=sha(target), source_override=target.relative_to(ROOT).as_posix(), metadata_only_spans=[list(v) for v in spans], non_metadata_bytes_identical=True)
                metadata_changes.append(dict(path=path, original_sha256=row['original_sha256'], sha256=row['sha256'], spans=row['metadata_only_spans']))
        rows.append(row)
    result = dict(complete=True, contentRoot=source['contentRoot'], assets=rows, excluded=denied, source_manifest_sha256=sha(source_manifest), blank_receipt_sha256=sha(blanks_path), metadata_only_changes=metadata_changes)
    path = ROOT / 'local/release/rs/source-assets-merged.json'
    write_json(path, result)
    print('Cleared source handoff:', len(rows), 'packages;', len(denied), 'excluded by provenance')
if __name__ == '__main__':
    main()
