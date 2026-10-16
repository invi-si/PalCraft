# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright Invi
"""Bounded UE5.1 ForceInline Vorbis SoundWave templates and Ogg metadata.

The installer replaces entire payloads and rebuilds the pak; source lengths and
sample rates need not match the authored silent template.
"""
import os
import re, struct, hashlib
from cooked_payload import header_info, name_hash
PALWORLD_OGG_FORMAT = 'OGG_1000_StreamCache_Ver5027_MEM_65536MaxChnkSize_00483224128'

def properties(header, data):
    names = [x[0] for x in header_info(header)['names']]
    at = 0
    out = {}
    while True:
        start = at
        n, num = struct.unpack_from('<ii', data, at)
        at += 8
        name = names[n]
        if name == 'None':
            break
        ti, tn, size, index = struct.unpack_from('<4i', data, at)
        at += 16
        typ = names[ti]
        if typ in ('ByteProperty', 'EnumProperty'):
            at += 8
        elif typ == 'StructProperty':
            at += 24
        elif typ == 'BoolProperty':
            at += 1
        elif typ in ('ArrayProperty', 'SetProperty'):
            at += 8
        elif typ == 'MapProperty':
            at += 16
        guid = data[at]
        at += 1
        if guid:
            at += 16
        assert 0 <= size <= len(data) - at
        out[name] = dict(type=typ, offset=at, size=size, start=start)
        at += size
    return (out, at)

def layout(h, d):
    hi = header_info(h)
    p, end = properties(h, d)
    at = end
    assert struct.unpack_from('<3i', d, at) == (0, 1, 1), 'Expected no object GUID, cooked, one format'
    name, num = struct.unpack_from('<ii', d, at + 12)
    assert hi['names'][name][0].startswith('OGG') and num == 0
    bulk = at + 20
    flags, n, size, off = struct.unpack_from('<Iiiq', d, bulk)
    assert flags == 72 and n == size and (off == len(h) + bulk + 20)
    start = bulk + 20
    assert d[start:start + 4] == b'OggS' and start + size == len(d) - 20
    total = len(h) + len(d) - 4
    places = [m.start() for m in re.finditer(re.escape(struct.pack('<q', total)), h[:hi['nameAt']])]
    assert len(places) == 1
    for key in ('Duration', 'TotalSamples', 'NumChannels', 'SampleRate'):
        assert p[key]['size'] == 4
    return dict(payloadOffset=start, payloadSize=size, bulkHeaderOffset=bulk, exportSizeOffset=hi['exportAt'] + 28, exportOffsetOffset=hi['exportAt'] + 36, bulkStartOffset=places[0], properties={k: v['offset'] for k, v in p.items() if k in ('Duration', 'TotalSamples', 'NumChannels', 'SampleRate')})

def rename(h, d, package):
    hi = header_info(h)
    table = bytearray()
    changes = 0
    for name, a, b in hi['names']:
        new = package if name == '/Game/MinecraftSA/S_Template' else package.rsplit('/', 1)[1] if name == 'S_Template' else PALWORLD_OGG_FORMAT if name.startswith('OGG_') else name
        if name != new:
            table += struct.pack('<i', len(new) + 1) + new.encode() + b'\x00' + name_hash(new)
            changes += 1
        else:
            table += h[a:b]
    assert changes == 3
    old = layout(h, d)
    nh = bytearray(h)
    struct.pack_into('<i', nh, hi['summary'] + 8, len(h))
    nh += table
    struct.pack_into('<i', nh, hi['totalAt'], len(nh))
    struct.pack_into('<q', nh, old['exportOffsetOffset'], len(nh))
    struct.pack_into('<q', nh, old['bulkStartOffset'], len(nh) + len(d) - 4)
    nd = bytearray(d)
    struct.pack_into('<q', nd, old['bulkHeaderOffset'] + 12, len(nh) + old['payloadOffset'])
    return (bytes(nh), bytes(nd), layout(nh, nd))

def ogg_info(b):
    assert 0 < len(b) <= 32 * 1024 * 1024 and b.startswith(b'OggS\x00\x02')
    at = 0
    seq = 0
    serial = None
    frames = None
    first = None
    while at < len(b):
        assert b[at:at + 5] == b'OggS\x00' and len(b) - at >= 27
        flags = b[at + 5]
        granule, s, q = struct.unpack_from('<qII', b, at + 6)
        n = b[at + 26]
        head = 27 + n
        size = sum(b[at + 27:at + head])
        assert at + head + size <= len(b)
        if serial is None:
            serial = s
            first = b[at + head:at + head + size]
        assert s == serial and q == seq
        seq += 1
        if flags & 4:
            assert at + head + size == len(b)
            frames = granule
        at += head + size
    assert first[:7] == b'\x01vorbis' and struct.unpack_from('<I', first, 7)[0] == 0
    channels = first[11]
    rate = struct.unpack_from('<I', first, 12)[0]
    assert channels in (1, 2) and 8000 <= rate <= 192000 and frames and (0 < frames / rate <= 600)
    return dict(channels=channels, sampleRate=rate, frames=frames, duration=frames / rate, pages=seq)

def patch(h, d, b):
    m = layout(h, d)
    info = ogg_info(b)
    nh = bytearray(h)
    nd = bytearray(d[:m['payloadOffset']]) + b + d[m['payloadOffset'] + m['payloadSize']:]
    struct.pack_into('<ii', nd, m['bulkHeaderOffset'] + 4, len(b), len(b))
    for key, val, fmt in [('Duration', info['duration'], 'f'), ('TotalSamples', info['frames'] * info['channels'], 'f'), ('NumChannels', info['channels'], 'i'), ('SampleRate', info['sampleRate'], 'i')]:
        struct.pack_into('<' + fmt, nd, m['properties'][key], val)
    struct.pack_into('<q', nh, m['exportSizeOffset'], len(nd) - 4)
    struct.pack_into('<q', nh, m['bulkStartOffset'], len(nh) + len(nd) - 4)
    layout(nh, nd)
    return (bytes(nh), bytes(nd), info)
