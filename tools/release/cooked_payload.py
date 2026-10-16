# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright Invi
"""Bounded UE5.1 cooked Texture2D layout reader and lossless BGRA8 converter.

Only split, tagged-property Texture2D exports with one platform are supported.
Unknown flags/layouts fail closed. No editor or proprietary codec is distributed.
"""
import os
import hashlib, re, struct, zlib

def string(data, at):
    n = struct.unpack_from('<i', data, at)[0]
    assert 0 < n < 65536
    assert data[at + 3 + n] == 0
    return (data[at + 4:at + 3 + n].decode('utf8'), at + 4 + n)

def layout(data, bulk=b''):
    hits = list(re.finditer(b'PF_[A-Za-z0-9_]+\\x00', data))
    assert len(hits) == 1, 'Ambiguous texture platform'
    hit = hits[0]
    fmt = hit[0][:-1].decode()
    at = hit.end()
    first, count = struct.unpack_from('<ii', data, at)
    at += 8
    w, h, depth = struct.unpack_from('<iii', data, hit.start() - 16)
    assert 0 < count < 32 and depth == 1
    mips = []
    for i in range(count):
        start = at
        flags, n, size, offset = struct.unpack_from('<Iiiq', data, at)
        at += 20
        assert n == size and size >= 0
        if flags & 64:
            ext = '.uexp'
            payload = at
            at += size
            buf = data
        else:
            assert flags == 66817, ('Unsupported external bulk', hex(flags))
            ext = '.ubulk'
            payload = offset
            buf = bulk
        mw, mh, md = struct.unpack_from('<iii', data, at)
        at += 12
        assert md == 1 and 0 < mw <= 8192 and (0 < mh <= 8192)
        expected = mw * mh * 4 if fmt == 'PF_B8G8R8A8' else max(1, (mw + 3) // 4) * max(1, (mh + 3) // 4) * (8 if fmt == 'PF_DXT1' else 16)
        assert expected == size and 0 <= payload <= len(buf) - size, (fmt, i, mw, mh, size, len(buf), payload)
        mips.append(dict(index=i, bulkHeader=start, file=ext, offset=payload, size=size, width=mw, height=mh, flags=flags, serializedOffset=offset, sha256=hashlib.sha256(buf[payload:payload + size]).hexdigest()))
    return dict(format=fmt, width=w, height=h, firstMip=first, mips=mips, pixelFormatOffset=hit.start(), end=at)

def header_info(data):
    custom = struct.unpack_from('<i', data, 24)[0]
    assert 0 <= custom < 1000
    totalAt = 28 + 20 * custom
    assert struct.unpack_from('<i', data, totalAt)[0] == len(data)
    _, s = string(data, totalAt + 4)
    values = struct.unpack_from('<I10i', data, s)
    count, nameAt, ecount, exportAt = (values[1], values[2], values[7], values[8])
    assert ecount == 1
    at = nameAt
    names = []
    for _ in range(count):
        name, end = string(data, at)
        names.append((name, at, end + 4))
        at = end + 4
    return dict(totalAt=totalAt, summary=s, nameAt=nameAt, nameEnd=at, names=names, exportAt=exportAt)

def name_hash(name):
    table = []
    for i in range(256):
        c = i << 24
        for _ in range(8):
            c = (c << 1 ^ 79764919 if c & 2147483648 else c << 1) & 4294967295
        table.append(c)
    h = 0
    for c in name.upper().encode('ascii'):
        h = h >> 8 ^ table[(h ^ c) & 255]
    return struct.pack('<HH', h & 65535, zlib.crc32(b''.join((struct.pack('<I', ord(c)) for c in name))) & 65535)

def blank_texture(header, data, bulk=b'', size_override=None, output_format='PF_B8G8R8A8'):
    old = layout(data, bulk)
    hi = header_info(header)
    assert output_format in ('PF_B8G8R8A8', 'PF_DXT1', 'PF_DXT5')
    if old['format'] == output_format and (not size_override) and all((m['file'] == '.uexp' for m in old['mips'])):
        result = bytearray(data)
        for m in old['mips']:
            assert m['file'] == '.uexp'
            result[m['offset']:m['offset'] + m['size']] = bytes(m['size'])
        return (header, bytes(result), old, old)
    assert old['format'] in ('PF_DXT1', 'PF_DXT5', 'PF_BC5', 'PF_B8G8R8A8')
    pf = old['pixelFormatOffset']
    name = output_format
    newHeader = bytearray(header)
    if old['format'] != name:
        table = bytearray()
        for n, a, b in hi['names']:
            if n == old['format']:
                table += struct.pack('<i', len(name) + 1) + name.encode() + b'\x00' + name_hash(name)
            else:
                table += header[a:b]
        struct.pack_into('<i', newHeader, hi['summary'] + 8, len(header))
        newHeader += table
        struct.pack_into('<i', newHeader, hi['totalAt'], len(newHeader))
    end = pf + len(old['format']) + 1
    result = bytearray(data[:pf - 4]) + struct.pack('<i', len(name) + 1) + name.encode() + b'\x00' + data[end:end + 8]
    mips = old['mips']
    if size_override:
        assert len(mips) == 1
        w, h = size_override
        struct.pack_into('<ii', result, pf - 16, w, h)
        mips = [dict(mips[0], width=w, height=h)]
    for m in mips:
        size = m['width'] * m['height'] * 4 if name == 'PF_B8G8R8A8' else max(1, (m['width'] + 3) // 4) * max(1, (m['height'] + 3) // 4) * (8 if name == 'PF_DXT1' else 16)
        offset = len(newHeader) + len(result) + 20
        result += struct.pack('<Iiiq', 72, size, size, offset) + bytes(size) + struct.pack('<iii', m['width'], m['height'], 1)
    result += data[old['end']:]
    skip = pf - 40
    oldSkip = struct.unpack_from('<q', data, skip)[0]
    assert oldSkip + skip == len(data) - 12, (oldSkip, skip, len(data))
    struct.pack_into('<q', result, skip, len(result) - 12 - skip)
    struct.pack_into('<q', newHeader, hi['exportAt'] + 28, len(result) - 4)
    struct.pack_into('<q', newHeader, hi['exportAt'] + 36, len(newHeader))
    oldTotal = len(header) + len(data) - 4
    needle = struct.pack('<q', oldTotal)
    places = [m.start() for m in re.finditer(re.escape(needle), header[:hi['nameAt']])]
    assert len(places) == 1, ('BulkDataStartOffset not unique', places)
    struct.pack_into('<q', newHeader, places[0], len(newHeader) + len(result) - 4)
    new = layout(result)
    header_info(newHeader)
    return (bytes(newHeader), bytes(result), old, new)

def pak_string(s):
    b = s.encode('utf8') + b'\x00'
    return struct.pack('<i', len(b)) + b

def rename_texture(header, data, old_package, new_package):
    """Clone an owned texture identity without editing any import/geometry data."""
    hi = header_info(header)
    old = layout(data)
    table = bytearray()
    changed = 0
    names = {old_package: new_package, old_package.rsplit('/', 1)[1]: new_package.rsplit('/', 1)[1]}
    for n, a, b in hi['names']:
        if n in names:
            name = names[n]
            table += struct.pack('<i', len(name) + 1) + name.encode() + b'\x00' + name_hash(name)
            changed += 1
        else:
            table += header[a:b]
    assert changed == 2, (old_package, changed)
    out = bytearray(header)
    struct.pack_into('<i', out, hi['summary'] + 8, len(out))
    out += table
    struct.pack_into('<i', out, hi['totalAt'], len(out))
    struct.pack_into('<q', out, hi['exportAt'] + 36, len(out))
    needle = struct.pack('<q', len(header) + len(data) - 4)
    places = [m.start() for m in re.finditer(re.escape(needle), header[:hi['nameAt']])]
    assert len(places) == 1
    struct.pack_into('<q', out, places[0], len(out) + len(data) - 4)
    exp = bytearray(data)
    for m in old['mips']:
        struct.pack_into('<q', exp, m['bulkHeader'] + 12, len(out) + m['offset'])
    return (bytes(out), bytes(exp))

def write_pak(path, files):
    """Write deterministic, unencrypted/uncompressed v3 paks with full SHA-1s.

 Every header/index field is emitted directly; no third-party packer is needed
 on the end user's machine. Return patch/hash locations for a bounded updater.
 """
    entries = []
    with path.open('wb') as out:
        for name, source in sorted(files.items()):
            b = source.read_bytes()
            offset = out.tell()
            digest = hashlib.sha1(b).digest()
            entry = struct.pack('<qqqI', offset, len(b), len(b), 0) + digest + struct.pack('<BI', 0, 0)
            out.write(bytes(8) + entry[8:])
            out.write(b)
            entries.append(dict(path=name, offset=offset, dataOffset=offset + len(entry), size=len(b), headerHashOffset=offset + 28, hash=digest, entry=entry))
        indexAt = out.tell()
        index = bytearray(pak_string('../../../')) + struct.pack('<i', len(entries))
        for row in entries:
            index += pak_string(row['path'])
            row['indexHashOffset'] = indexAt + len(index) + 28
            index += row.pop('entry')
            row.pop('hash')
        out.write(index)
        footer = out.tell()
        out.write(struct.pack('<IIqq', 1517228769, 3, indexAt, len(index)) + hashlib.sha1(index).digest())
    return dict(entries=entries, indexOffset=indexAt, indexSize=len(index), indexHashOffset=footer + 24, sha256=hashlib.sha256(path.read_bytes()).hexdigest())
