# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright Invi
"""Copy cleared source assets, replacing validated editor import metadata.

Unreal stores import metadata as a length-prefixed FString. Replacements retain
the exact length/prefix/NUL and pad the JSON with legal trailing whitespace.
Geometry, pixels, package offsets and all non-metadata bytes stay identical.
Import-factory path names are validated complete FStrings before scrubbing.
Unrecognized metadata is excluded, never binary-patched heuristically.
"""
from __future__ import annotations
import os
import argparse
from collections import defaultdict
import struct
from common import *
IMPORT_JSON = re.compile(b'\\[\\{\\s*"RelativeFilename".{0,65536}?\\}\\]', re.S)
DRIVE = re.compile(b'(?<![A-Za-z])[A-Za-z]:[\\\\/][A-Za-z0-9_ .-]{3}')

def scrub(raw, asset_name):
    changed = []
    output = bytearray(raw)
    for match in IMPORT_JSON.finditer(raw):
        if match.start() < 4 or match.end() >= len(raw):
            continue
        length = struct.unpack_from('<i', raw, match.start() - 4)[0]
        if length != len(match[0]) + 1 or raw[match.end()] != 0:
            continue
        try:
            info = json.loads(match[0].decode('utf-8'))
        except (ValueError, UnicodeDecodeError):
            continue
        if not isinstance(info, list) or not all((isinstance(row, dict) and 'RelativeFilename' in row for row in info)):
            continue
        for index, row in enumerate(info):
            ext = Path(row['RelativeFilename'].replace('\\', '/')).suffix
            if not re.fullmatch('\\.[A-Za-z0-9]{1,8}', ext):
                ext = '.source'
            row['RelativeFilename'] = 'src' + (str(index) if index else '') + ext
            if 'SourceFileLabel' in row:
                row['SourceFileLabel'] = 'Original source'
        encoded = json.dumps(info, separators=(',', ':'), ensure_ascii=True).encode('ascii')
        if len(encoded) > len(match[0]):
            continue
        encoded += b' ' * (len(match[0]) - len(encoded))
        assert json.loads(encoded) == info
        output[match.start():match.end()] = encoded
        changed.append((match.start(), match.end()))
    current = bytes(output)
    patterns = [(DRIVE, 'utf-8'), (re.compile(b'(?<![A-Za-z])(?:[A-Za-z]\\x00):\\x00[\\\\/]\\x00'), 'utf-16-le')]
    for pattern, encoding in patterns:
        for match in list(pattern.finditer(current)):
            for at in range(max(0, match.start() - 4096), match.start() + 1):
                if at + 4 > len(current):
                    break
                n = struct.unpack_from('<i', current, at)[0]
                if encoding == 'utf-8' and 1 < n <= 4096:
                    start = at + 4
                    end = start + n - 1
                    terminator = 1
                elif encoding == 'utf-16-le' and -4096 <= n < -1:
                    start = at + 4
                    end = start + (-n - 1) * 2
                    terminator = 2
                else:
                    continue
                if not start <= match.start() < end or end + terminator > len(current) or current[end:end + terminator] != bytes(terminator):
                    continue
                try:
                    text = current[start:end].decode(encoding)
                except UnicodeDecodeError:
                    continue
                if not re.match('^(?:Factory_)?[A-Za-z]:[/\\\\]', text):
                    continue
                if any((ord(c) < 32 for c in text)):
                    continue
                prefix = 'Factory_src' if text.startswith('Factory_') else 'src'
                replacement = (prefix + '_' * (len(text) - len(prefix))).encode(encoding)
                if len(replacement) != end - start:
                    continue
                output[start:end] = replacement
                changed.append((start, end))
                break
    changed.sort()
    result = bytes(output)
    assert len(result) == len(raw)
    previous = 0
    for start, end in changed:
        assert raw[previous:start] == result[previous:start]
        previous = end
    assert raw[previous:] == result[previous:]
    return (result, changed)

def run(content_root, output_manifest=None, include_cleared_replacements=False):
    check_interrupt()
    audit = Audit()
    assert isinstance(audit.data, list)
    records = defaultdict(list)
    for row in audit.data:
        key = Audit.canonical(row['path'])
        if key.startswith('content/'):
            records[key].append(row)
    blanks_path = ROOT / 'local/taskRA/blank-result.json'
    blanks = read_json(blanks_path) if include_cleared_replacements and blanks_path.exists() else {}
    cleared_blanks = set(blanks.get('packages', ())) if blanks.get('complete') is True else set()
    cleared_blanks -= {row.get('package') for row in blanks.get('errors', []) if isinstance(row, dict)}
    destination = ROOT / 'local/release/rs' / ('source-content-' + datetime.now().strftime('%Y%m%d-%H%M%S'))
    destination.mkdir(parents=True)
    approved, excluded, changed = ([], [], [])
    stem = bytes((100, 97, 110, 105, 101))
    for p in sorted(Path(content_root).rglob('*.uasset')):
        rel = p.relative_to(content_root).as_posix()
        if not rel.startswith(('Minecraft', 'CustomPals')):
            continue
        rows = records.get('content/' + rel.lower(), [])
        package = '/Game/' + rel[:-7]
        replacement = bool(rows) and package in cleared_blanks and all((audit.effective_provenance(r) in ('ours', 'mojang') and r.get('kind') in ('texture', 'sound') for r in rows))
        if not rows or (any((audit.effective_provenance(r) != 'ours' for r in rows)) and (not replacement)):
            excluded.append(dict(path=rel, reason='Provenance exclusion or no clearance'))
            continue
        raw = p.read_bytes()
        clean, spans = scrub(raw, p.stem)
        if private_metadata(clean, binary=True):
            excluded.append(dict(path=rel, reason='Unrecognized private/source metadata'))
            continue
        target = destination / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(clean)
        approved.append(dict(path=rel, sha256=sha(target), clean=True, provenance='ours', license=audit.asset_license('Content/' + rel), replacement_method='blank-placeholder' if replacement else None, blank_receipt_sha256=sha(blanks_path) if replacement else None))
        if spans:
            changed.append(dict(path=rel, source_sha256=hashlib.sha256(raw).hexdigest(), sha256=sha(target), metadata_spans=[list(v) for v in spans], non_metadata_bytes_identical=True))
    report = dict(complete=not any((row['reason'] == 'Unrecognized private/source metadata' for row in excluded)), assets=approved, excluded=excluded, note='Original audited geometry/art/code and explicitly receipted blank placeholders only. Fonts and native-derived assets excluded. Validated import metadata scrubbed without changing geometry/pixels or other bytes.')
    receipt_path = Path(output_manifest or ROOT / 'local/release/rs/source-assets.json')
    write_json(receipt_path, report)
    write_json(destination.parent / ('source-metadata-' + datetime.now().strftime('%Y%m%d-%H%M%S') + '.json'), dict(content_root=destination.relative_to(ROOT).as_posix(), assets=len(approved), metadata_changes=changed, custom_pal_meshes=[r['path'] for r in approved if r['path'].startswith('CustomPals') and Path(r['path']).stem in ('SK_FungalHost', 'SK_IvoryRattle', 'SK_Mossback', 'SK_PatchworkBrute', 'SK_RedstoneRevenant')]))
    print(json.dumps(dict(content_root=destination.relative_to(ROOT).as_posix(), original_sources=len(approved), metadata_scrubbed=len(changed), excluded=len(excluded)), indent=2))
    return destination
if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--content-root', type=Path, required=True)
    parser.add_argument('--output-manifest', type=Path)
    parser.add_argument('--include-cleared-replacements', action='store_true')
    args = parser.parse_args()
    run(args.content_root, args.output_manifest, args.include_cleared_replacements)
