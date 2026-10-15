# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright Invi
"""Negative leak/provenance tests: excluded bytes must stop a build/export."""
import os
from common import *
import struct
from scrub_source_metadata import scrub

def run():
    root = evidence_root() / ('policy-' + datetime.now().strftime('%Y%m%d-%H%M%S'))
    root.mkdir(parents=True)
    bad = [bytes((100, 97, 110, 105, 101)), bytes((100, 97, 110, 105, 101, 108)), bytes((100, 97, 110, 105, 101, 108, 54, 55, 57, 48, 49, 52)), b'C:' + bytes((92,)) + b'Users' + bytes((92,)) + b'private', b'private.person' + bytes((64,)) + b'example.net']
    cases = []
    for i, data in enumerate(bad):
        folder = root / str(i)
        folder.mkdir()
        (folder / 'example.txt').write_bytes(data)
        try:
            leak_scan(folder)
        except ValueError:
            cases.append(i)
        else:
            raise AssertionError('Leak was accepted: ' + str(i))
    for i, name in enumerate(('Assets/alex.png', 'assets/minecraft/textures/dirt.png', 'project/Content/Pal/base.uasset')):
        folder = root / ('binary' + str(i))
        (folder / name).parent.mkdir(parents=True)
        (folder / name).write_bytes(b'uncleared asset')
        try:
            leak_scan(folder)
        except ValueError:
            pass
        else:
            raise AssertionError('Uncleared binary accepted')
    path = root / 'audit.json'
    write_json(path, {'categories': {'mojang': ['**/copied.png'], 'palworld': [{'path': 'Content/Pal/*'}]}, 'files': [{'path': 'runtime/private.lua', 'classification': 'owner_personal'}, {'path': 'runtime/probe.lua', 'category': 'test'}, {'path': 'Content/copy.uasset', 'category': 'mojang-derived'}]})
    audit = Audit(path)
    assert audit.reasons('Content/copied.png') == ['mojang']
    assert audit.reasons('project/Content/Pal/base.uasset') == ['palworld']
    assert audit.reasons('runtime/private.lua') == ['owner-personal']
    assert audit.reasons('runtime/probe.lua') == ['test']
    assert audit.reasons('Content/copy.uasset') == ['mojang']
    metadata = json.dumps([dict(RelativeFilename='E:' + chr(47) + 'private/imports/source.fbx', Timestamp='0')]).encode()
    raw = b'HEADER' + struct.pack('<i', len(metadata) + 1) + metadata + bytes((0,)) + b'GEOMETRY_UNCHANGED'
    clean, spans = scrub(raw, 'OriginalModel')
    assert spans and len(clean) == len(raw) and clean.endswith(b'GEOMETRY_UNCHANGED')
    assert b'private/imports' not in clean
    malformed = raw[:6] + struct.pack('<i', 1) + raw[10:]
    assert scrub(malformed, 'OriginalModel') == (malformed, [])
    source_path = 'E:' + chr(47) + 'private/project/model.fbx'
    ascii_path = source_path.encode()
    unicode_path = source_path.encode('utf-16-le')
    assert private_metadata(struct.pack('<i', len(ascii_path) + 1) + ascii_path + bytes((0,)), binary=True)
    assert private_metadata(struct.pack('<i', -(len(source_path) + 1)) + unicode_path + bytes((0, 0)), binary=True)
    assert not private_metadata(b'not-a-string' + ascii_path + b'BINARY', binary=True)
    report = dict(status='PASS', denied_identity_cases=len(cases), denied_binary_cases=3, audit_category_cases=5, metadata_only_scrub=True, malformed_metadata_unchanged=True)
    write_json(root / 'report.json', report)
    print('PASS release policy: identities, local paths, emails, uncleared binaries, audit exclusions')
if __name__ == '__main__':
    run()
