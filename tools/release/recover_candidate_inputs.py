# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright Invi
"""Recover a hash-bound build baseline from a surviving candidate, offline.

This is binary-input recovery, not a claim to reproduce the deleted editor cook.
Every ZIP member is verified, and each owned v3 pak is independently parsed,
authenticated and re-emitted through cooked_payload.write_pak. No game paths
are used. Outputs stay within the project's local/ evidence tree.
"""
from __future__ import annotations
import os
import argparse
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import struct
import zipfile
from common import ROOT, check_interrupt, sha, write_json
from cooked_payload import write_pak
os.environ.setdefault('PALCRAFT_TASK_PREFIX', 'VB')

def log(item, state, detail):
    with (ROOT / 'coordination/CODEX_PROGRESS.txt').open('a', encoding='utf-8') as f:
        f.write(f'VB {datetime.now():%H:%M} {item} {state} {detail}\n')

def fstring(data, at):
    n = struct.unpack_from('<i', data, at)[0]
    assert 0 < n < 1048576 and at + 4 + n <= len(data)
    assert data[at + 3 + n] == 0
    return (data[at + 4:at + 3 + n].decode('utf-8'), at + 4 + n)

def read_pak(path):
    """Authenticate the complete uncompressed v3 format, including both hashes."""
    with Path(path).open('rb') as f:
        f.seek(-44, 2)
        footer = f.tell()
        magic, version, index_at, index_size = struct.unpack('<IIqq', f.read(24))
        digest = f.read(20)
        assert magic == 1517228769 and version == 3
        assert index_at + index_size == footer
        f.seek(index_at)
        index = f.read(index_size)
        assert hashlib.sha1(index).digest() == digest
        mount, at = fstring(index, 0)
        assert mount == '../../../'
        count = struct.unpack_from('<i', index, at)[0]
        assert 0 <= count < 1000000
        at += 4
        rows = []
        expected_offset = 0
        for _ in range(count):
            name, at = fstring(index, at)
            assert not PurePosixPath(name).is_absolute() and '..' not in PurePosixPath(name).parts
            offset, size, expanded, codec = struct.unpack_from('<qqqI', index, at)
            payload_hash = index[at + 28:at + 48]
            encrypted, block = struct.unpack_from('<BI', index, at + 48)
            assert offset == expected_offset and size == expanded and (codec == encrypted == block == 0)
            f.seek(offset)
            header = f.read(53)
            assert header == bytes(8) + index[at + 8:at + 53]
            data = f.read(size)
            assert len(data) == size and hashlib.sha1(data).digest() == payload_hash, name
            rows.append(dict(path=name, offset=offset, dataOffset=offset + 53, size=size, headerHashOffset=offset + 28, indexHashOffset=index_at + at + 28, sha256=hashlib.sha256(data).hexdigest()))
            expected_offset = offset + 53 + size
            at += 53
        assert at == len(index) and expected_offset == index_at
        assert len({r['path'] for r in rows}) == count
        return dict(entries=rows, indexOffset=index_at, indexSize=index_size, indexHashOffset=footer + 24, sha256=sha(path))

class PakSlice:

    def __init__(self, path, row):
        self.path, self.row = (path, row)

    def read_bytes(self):
        with self.path.open('rb') as f:
            f.seek(self.row['dataOffset'])
            b = f.read(self.row['size'])
        assert hashlib.sha256(b).hexdigest() == self.row['sha256']
        return b

def recover(archive, output):
    check_interrupt()
    archive, output = (Path(archive).resolve(), Path(output).resolve())
    assert output.is_relative_to((ROOT / 'local').resolve()) and output != (ROOT / 'local').resolve()
    output.mkdir(parents=True, exist_ok=True)
    archive_hash = sha(archive)
    log('VB2', 'START', 'recover and independently repack candidate ' + archive_hash)
    baseline = output / 'baseline'
    baseline.mkdir(exist_ok=True)
    with zipfile.ZipFile(archive) as z:
        names = z.namelist()
        assert len(names) == len(set(names))
        root = names[0].split('/')[0]
        assert all((n.startswith(root + '/') for n in names))
        manifest_raw = z.read(root + '/manifest.json')
        manifest = json.loads(manifest_raw)
        rows = manifest['files']
        expected = {root + '/' + r['path'] for r in rows} | {root + '/manifest.json'}
        assert set(names) == expected, 'Unexpected/unlisted ZIP members'
        for row in rows:
            relative = PurePosixPath(row['path'])
            assert not relative.is_absolute() and '..' not in relative.parts and ('\\' not in row['path'])
            target = baseline / row['path']
            assert target.resolve().is_relative_to(baseline.resolve())
            target.parent.mkdir(parents=True, exist_ok=True)
            if target.exists():
                assert sha(target) == row['sha256'], 'Existing recovery differs: ' + row['path']
                continue
            h, size = (hashlib.sha256(), 0)
            with z.open(root + '/' + row['path']) as src, target.open('xb') as dst:
                while (b := src.read(1024 * 1024)):
                    dst.write(b)
                    h.update(b)
                    size += len(b)
            assert size == row['bytes'] and h.hexdigest() == row['sha256'], row['path']
        (baseline / 'manifest.json').write_bytes(manifest_raw)
    pak_rows, proof = ([], [])
    patches = json.loads((baseline / 'asset-runtime/cooked-patches.json').read_text(encoding='utf-8-sig'))
    sounds = json.loads((baseline / 'asset-runtime/cooked-sounds.json').read_text(encoding='utf-8-sig'))
    patch_by_name = {p['name']: p for p in patches['paks']}
    sound_by_name = {p['name']: p for p in sounds['paks']}
    for row in rows:
        if not row['path'].endswith('.pak'):
            continue
        path = baseline / row['path']
        parsed = read_pak(path)
        entries = {r['path']: r for r in parsed['entries']}
        temp = output / (path.name + '.repacked')
        assert not temp.exists(), temp
        regenerated = write_pak(temp, {n: PakSlice(path, r) for n, r in entries.items()})
        equal = regenerated['sha256'] == row['sha256']
        assert equal, 'Canonical pak rebuild differs: ' + row['path']
        temp.unlink()
        patch_count = 0
        if path.name in patch_by_name:
            pm = patch_by_name[path.name]
            assert pm['sha256'] == parsed['sha256'], path.name
            for k in ('indexOffset', 'indexSize', 'indexHashOffset'):
                assert pm[k] == parsed[k], (path.name, k)
            for p in pm['patches']:
                e = entries[p['file']]
                for k in ('dataOffset', 'headerHashOffset', 'indexHashOffset'):
                    assert e[k] == p[k], (path.name, p['file'], k)
                assert e['size'] == p['fileSize']
                data = PakSlice(path, e).read_bytes()
                ranges = p['mips'] if p['kind'] == 'texture' else [dict(offset=p['offset'], size=p['size'])]
                for m in ranges:
                    assert 0 <= m['offset'] <= len(data) - m['size']
                    if p['kind'] == 'texture':
                        assert not any(data[m['offset']:m['offset'] + m['size']]), 'Template contains source pixels'
                patch_count += 1
        if path.name in sound_by_name:
            sm = sound_by_name[path.name]
            assert sm['sha256'] == parsed['sha256']
            assert sm['entries'] == parsed['entries']
        pack = row['path'].split('/')[1]
        pak_rows.append(dict(source=path.relative_to((ROOT / 'local').resolve()).as_posix(), destination=path.name, name=path.name, pack=pack, sha256=row['sha256'], clean=True, candidate_path=row['path']))
        pak_rows[-1]['source'] = 'local/' + pak_rows[-1]['source']
        proof.append(dict(path=row['path'], sha256=row['sha256'], bytes=row['bytes'], entries=len(entries), canonical_repack_identical=equal, patch_ranges=patch_count))
    assert sha(archive) == archive_hash, 'Input candidate changed during recovery'
    report = dict(status='PASS', source_archive=str(archive.relative_to(ROOT)) if archive.is_relative_to(ROOT) else str(archive), source_sha256=archive_hash, manifest_sha256=hashlib.sha256(manifest_raw).hexdigest(), files=len(rows), all_payload_hashes_identical=True, exact_differences=[], paks=proof, recovered_cooked_manifests=['asset-runtime/cooked-patches.json', 'asset-runtime/cooked-sounds.json', 'asset-runtime/texture-recipes.json'], limitations=['Deleted editor cook inputs and old historical evidence are not reconstructed. This baseline uses candidate-authenticated cooked assets.', 'Native readiness is inherited historical data; this offline recovery does not revalidate it.'], temporary_files_removed=[p['path'].rsplit('/', 1)[-1] + '.repacked' for p in proof])
    clearance = output / 'clean-pak-receipt.json'
    write_json(clearance, pak_rows)
    clearance_relative = 'local/' + clearance.relative_to((ROOT / 'local').resolve()).as_posix()
    write_json(output / 'paks.json', dict(complete=True, clearance_receipt=clearance_relative, pack_split_validated=manifest.get('pack_split_validated', False), native_compatibility_ready=manifest.get('native_compatibility_ready', False), recovered_from_candidate=archive_hash, paks=pak_rows))
    write_json(output / 'rebuild-proof.json', report)
    log('VB2', 'PASS', f'{len(rows)} payload files; {len(proof)} canonical pak rebuilds exact; {output.name}/rebuild-proof.json')
    print(f'VB recovered {len(rows)} files; {len(proof)} paks repack byte-for-byte; differences=0', flush=True)
    return report
if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--candidate', type=Path, default=ROOT / 'release/dist/PalCraft-v1.1-CANDIDATE.zip')
    parser.add_argument('--output', type=Path, default=ROOT / 'local/taskVB/rebuild')
    args = parser.parse_args()
    recover(args.candidate, args.output)
