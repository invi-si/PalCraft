# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright Invi
"""Conservative cooked name-table dependency closure for every install choice."""
import os
from taskRA_prepare import *
from inspect_native_rig import read_name_table, read_string
import struct

def imports(path, names):
    data = path.read_bytes()
    _, legacy, ue3, ue4, ue5, licensee, custom = struct.unpack_from('<I6i', data)
    assert ue4 >= 500 and ue5 == 1008 or (ue4 == 0 and ue5 == 0), (ue4, ue5)
    _, offset = read_string(data, 32 + 20 * custom)
    flags, ncount, noffset, softcount, softoffset, textcount, textoffset, ecount, eoffset, icount, ioffset = struct.unpack_from('<I10i', data, offset)
    assert flags & 2147483648 and ncount == len(names) and (0 <= icount < 100000)
    assert ioffset + icount * 32 <= len(data)
    deps = set()
    for i in range(icount):
        a, an, b, bn, outer, c, cn, optional = struct.unpack_from('<8i', data, ioffset + 32 * i)
        assert all((0 <= x < len(names) for x in [a, b, c])) and all((0 <= x < 100000 for x in [an, bn, cn])) and (optional in [0, 1])
        object_name = names[c] + ('_' + str(cn - 1) if cn else '')
        if names[b] == 'Package' and object_name.startswith('/Game/'):
            deps.add(object_name)
    offset = softoffset
    for i in range(softcount):
        a, an, b, bn = struct.unpack_from('<4i', data, offset)
        offset += 16
        assert all((0 <= x < len(names) for x in [a, b])) and all((0 <= x < 100000 for x in [an, bn]))
        length = struct.unpack_from('<i', data, offset)[0]
        offset += 4
        assert -65536 <= length <= 65536
        offset += length if length > 0 else -length * 2
        assert offset <= len(data)
        package = names[a] + ('_' + str(an - 1) if an else '')
        if package.startswith('/Game/'):
            deps.add(package)
    return deps

def scan():
    check()
    errors = []
    seen = set()
    graph = {}
    sources = {}
    providers = {}
    modules = json.loads((ROOT / 'release/modules.json').read_text())
    assign = {r['name']: r['pack'] for r in modules['paks']}
    for row in json.loads((OUT / 'rebuilt-paks.json').read_text()):
        response = OUT / 'pak-responses' / (row['name'] + '.txt')
        for line in response.read_text().splitlines():
            m = re.match('^"(.+)" "../../../Pal/Content/(.+)"', line)
            if not m:
                errors.append(dict(line=line, reason='unrecognized response'))
                continue
            path = Path(m[1])
            rel = m[2]
            package = '/Game/' + Path(rel).with_suffix('').as_posix()
            providers.setdefault(package, set()).add(assign.get(row['name'], 'core'))
            if path.suffix not in ['.uasset', '.umap'] or str(path) in seen:
                continue
            seen.add(str(path))
            try:
                names, header = read_name_table(path)
                deps = imports(path, names)
                graph.setdefault(package, set()).update(deps)
                sources.setdefault(package, []).append(str(path))
            except Exception as exc:
                errors.append(dict(source=str(path), reason=str(exc)))
    result = dict(graph={k: sorted(v) for k, v in graph.items()}, providers={k: sorted(v) for k, v in providers.items()}, sources=sources, errors=errors)
    (OUT / 'cooked-dependency-scan.json').write_text(json.dumps(result, indent=2))
    missing = {d for ds in graph.values() for d in ds if d.startswith(('/Game/Minecraft', '/Game/CustomPals')) and d not in graph}
    (OUT / 'missing-cooked-dependencies.json').write_text(json.dumps(sorted(missing), indent=2))
    print('PACKAGES', len(graph), 'ERRORS', len(errors), 'MISSING', len(missing), sorted(missing)[:20], flush=True)
    if errors:
        print(errors[:10])
    return result
if __name__ == '__main__':
    scan()
