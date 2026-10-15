# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright Invi
"""Offline private-table equivalence, cold cost, cache and invalidation tests."""
import os
import argparse, subprocess, sys, time, shutil
from common import *
sys.path.insert(0, str(ROOT / 'tools'))
from lua54_compile import runtime

def python_value(value):
    if hasattr(value, 'items'):
        return {k: python_value(v) for k, v in value.items()}
    return value

def unwrap(v):
    return {e['key']: unwrap(e['value']) for e in v['entries']} if isinstance(v, dict) and 'entries' in v else v

def differences(a, b, path='', out=None):
    if out is None:
        out = []
    if isinstance(a, dict) and isinstance(b, dict):
        for k in a.keys() | b.keys():
            if k not in a or k not in b:
                out.append((path + '/' + str(k), 'missing expected' if k not in a else 'missing generated'))
            else:
                differences(a[k], b[k], path + '/' + str(k), out)
    elif a != b or isinstance(a, bool) != isinstance(b, bool):
        out.append((path, a, b))
    return out

def run(jar, index, assets, reference=None, runtime_root=None):
    check_interrupt()
    progress('RS2_G1', 'TEST', 'offline real jar conversion, semantic parity and fresh-process disk cache')
    out = evidence_root() / ('jar-data-' + datetime.now().strftime('%Y%m%d-%H%M%S'))
    out.mkdir(parents=True)
    base = Path(runtime_root) if runtime_root else ROOT / 'runtime/MinecraftBlocks'
    mod = out / 'PalCraft'
    mod.mkdir()
    for name in ('jar_data.lua', 'data_bindings.lua', 'local_data.lua', 'json.lua'):
        shutil.copyfile(base / name, mod / name)
    modules = [r['module'] for r in read_json(ROOT / 'release/data_contract.json')['modules']]
    shutil.copytree(assets, mod / 'assets')
    result = subprocess.run(['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(ROOT / 'release/installer/Initialize-LocalData.ps1'), '-ModRoot', str(mod), '-JarPath', str(jar), '-MinecraftVersion', '1.21.11', '-IndexPath', str(index)], capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    reference = reference or ROOT / read_json(ROOT / 'local/release/rs/data-plan-review.json')['reference']
    expected = {n: unwrap(read_json(reference / (n + '.json'))['value']) for n in modules}

    def convert(names=modules):
        L = runtime()
        g = L.execute((mod / 'jar_data.lua').read_text())
        values = {}
        modes = {}
        start = time.perf_counter()
        for n in names:
            value, mode = g['load'](mod.as_posix(), n)
            values[n] = value
            modes[n] = mode
        elapsed = time.perf_counter() - start
        return ({k: python_value(v) for k, v in values.items()}, modes, elapsed)
    actual, modes, cold = convert()
    diff = {n: differences(expected[n], actual[n]) for n in modules}
    diff = {n: v for n, v in diff.items() if v}
    cached, cache_modes, warm = convert()
    assert cached == actual
    source_path = mod / 'assets/minecraft/_palcraft/source.json'
    source = read_json(source_path)
    for field in ('jar_sha256', 'converter_sha256'):
        modified = dict(source)
        modified[field] = '0' * 64
        write_json(source_path, modified)
        value, new_modes, _ = convert(['registry'])
        assert new_modes['registry'] == 'generated' and value['registry'] == actual['registry']
    write_json(source_path, source)
    cache_file = next((p for p in (mod / 'cache').glob('*-tables.lua') if source['jar_sha256'][:16] in p.name and source['converter_sha256'][:16] in p.name))
    cache_file.write_text('return {')
    repaired, repaired_modes, _ = convert(['recipes'])
    assert repaired_modes['recipes'] == 'generated' and repaired['recipes'] == actual['recipes']
    repaired_again, repaired_again_modes, _ = convert(['recipes'])
    assert repaired_again_modes['recipes'] == 'disk-cache' and repaired_again['recipes'] == actual['recipes']
    J = runtime().execute((mod / 'json.lua').read_text())
    for text in ('{"k":"a\\nb\\\\c\\"d","v":false}', '{"ko":"한글","emoji":"\\ud83d\\ude00"}', '[1,-2.5,4e3,true]'):
        value = python_value(J['decode'](text))
        wanted = json.loads(text)
        if isinstance(wanted, list):
            wanted = dict(enumerate(wanted, 1))
        assert value == wanted, (value, wanted)
    for text in ('"\\ud800"', '"\\udc00"', '"bad\nstring"'):
        try:
            J['decode'](text)
        except Exception:
            pass
        else:
            raise AssertionError('Invalid JSON string accepted')
    write_json(out / 'diff.json', diff)
    report = dict(status='PASS' if not diff and cold < 2 else 'FAIL', minecraft_version='1.21.11', jar_sha256=sha(jar), modules=len(modules), semantically_equal=len(modules) - len(diff), differences={k: len(v) for k, v in diff.items()}, first_conversion_seconds=cold, disk_cache_seconds=warm, timing_excludes_python_result_marshalling=True, all_generated=all((v == 'generated' for v in modes.values())), all_disk_cached=all((v == 'disk-cache' for v in cache_modes.values())), jar_hash_invalidation=True, converter_hash_invalidation=True, corrupt_cache_fallback=True, json_unicode_escapes=True, private_reference=str(reference.relative_to(ROOT)), packaged_converter=bool(runtime_root), generated_data_private=True, game_launched=False)
    write_json(out / 'report.json', report)
    print(json.dumps(report, indent=2))
    print('RS evidence:', out.relative_to(ROOT))
    return (out, report)
if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--jar', type=Path, required=True)
    p.add_argument('--index', type=Path, required=True)
    p.add_argument('--assets', type=Path, required=True)
    p.add_argument('--reference', type=Path)
    p.add_argument('--runtime-root', type=Path)
    a = p.parse_args()
    try:
        out, report = run(a.jar, a.index, a.assets, a.reference, a.runtime_root)
        if report['status'] != 'PASS':
            check_interrupt()
            progress('RS2_G1', 'FAIL', str(report['differences']))
            sys.exit(1)
    except Exception as error:
        check_interrupt()
        progress('RS2_G1', 'FAIL', str(error).splitlines()[0] if str(error) else repr(error))
        raise
