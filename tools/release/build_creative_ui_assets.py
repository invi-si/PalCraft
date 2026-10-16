# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright Invi
"""Clone owned blank Texture2D identities; user jar supplies all UI pixels."""
import os
import argparse
import copy
import hashlib
import os
from pathlib import Path
import shutil
from common import ROOT, check_interrupt, read_json, write_json, sha
from cooked_payload import rename_texture, blank_texture, layout, write_pak
from recover_candidate_inputs import read_pak, PakSlice, log
os.environ.setdefault('PALCRAFT_TASK_PREFIX', 'VB')

def build(baseline, output):
    check_interrupt()
    baseline, output = (Path(baseline), Path(output))
    assert baseline.resolve().is_relative_to((ROOT / 'local').resolve())
    assert output.resolve().is_relative_to((ROOT / 'local').resolve())
    output.mkdir(parents=True, exist_ok=True)
    patch = read_json(baseline / 'asset-runtime/cooked-patches.json')
    recipes = read_json(baseline / 'asset-runtime/texture-recipes.json')
    source_pak = next((p for p in baseline.rglob('pakchunk19993-minecraft-blocks_P.pak')))
    info = read_pak(source_pak)
    entries = {r['path']: r for r in info['entries']}
    originals = next((p for p in patch['paks'] if p['name'] == source_pak.name))
    files, rows = ({}, [])
    for name, old, source, crop in [('T_MC_UI_creative_items', 'T_MC_UI_creative_crop', 'textures/gui/container/creative_inventory/tab_items.png', [0, 0, 195, 136]), ('T_MC_UI_creative_search', 'T_MC_UI_creative_crop', 'textures/gui/container/creative_inventory/tab_item_search.png', [0, 0, 195, 136]), ('T_MC_UI_creative_delete', 'T_MC_UI_slot', 'textures/gui/container/creative_inventory/tab_inventory.png', [173, 111, 191, 129]), ('T_MC_UI_creative_search_icon', 'T_MC_UI_creative_crop', 'textures/item/compass_16.png', [0, 0, 16, 16]), ('T_MC_UI_creative_ingredients_icon', 'T_MC_UI_creative_crop', 'textures/item/iron_ingot.png', [0, 0, 16, 16])]:
        before, after = ('/Game/MinecraftBlocks/' + old, '/Game/MinecraftBlocks/' + name)
        stem = 'Pal/Content/MinecraftBlocks/'
        h = PakSlice(source_pak, entries[stem + old + '.uasset']).read_bytes()
        d = PakSlice(source_pak, entries[stem + old + '.uexp']).read_bytes()
        size = [crop[2] - crop[0], crop[3] - crop[1]]
        old_layout = layout(d)
        if [old_layout['width'], old_layout['height']] != size:
            h, d, _, _ = blank_texture(h, d, size_override=size)
        nh, nd = rename_texture(h, d, before, after)
        decoded = layout(nd)
        assert decoded['format'] == 'PF_B8G8R8A8'
        assert [decoded['width'], decoded['height']] == [crop[2] - crop[0], crop[3] - crop[1]]
        for mip in decoded['mips']:
            assert not any(nd[mip['offset']:mip['offset'] + mip['size']])
        for ext, data in [('.uasset', nh), ('.uexp', nd)]:
            target = output / 'templates' / (name + ext)
            target.parent.mkdir(exist_ok=True)
            target.write_bytes(data)
            files[stem + name + ext] = target
        source_path = source
        source_id = hashlib.sha256(('source:' + source_path).encode()).hexdigest()[:20]
        crop_id = hashlib.sha256((source_id + str(crop)).encode()).hexdigest()[:20]
        recipe_output = '_palcraft/' + crop_id + '.png'
        recipes['nodes'][source_id] = dict(op='source', path=source_path)
        recipes['nodes'][crop_id] = dict(op='crop', src=source_id, args=crop)
        recipes['outputs'][recipe_output] = crop_id
        row = copy.deepcopy(next((r for r in originals['patches'] if r['package'] == before)))
        row.update(package=after, file=stem + name + '.uexp', source=recipe_output, sources=[source_path], width=decoded['width'], height=decoded['height'], mips=[{k: m[k] for k in ('index', 'offset', 'size', 'width', 'height')} for m in decoded['mips']], fileSize=len(nd), normalChannels=False, forceOpaque=False)
        rows.append(row)
    pak = output / 'pakchunk29990-palcraft-creative-ui_P.pak'
    written = write_pak(pak, files)
    by_file = {r['path']: r for r in written.pop('entries')}
    for row in rows:
        e = by_file[row['file']]
        for k in ('dataOffset', 'headerHashOffset', 'indexHashOffset'):
            row[k] = e[k]
    written.update(name=pak.name, pack='hud_skins', patches=rows, files=len(files))
    patch['paks'].append(written)
    for rel in ('release/asset-runtime/cooked-patches.json', 'release/asset-runtime/texture-recipes.json'):
        source = ROOT / rel
        backup = ROOT / 'local/taskVB/source-before' / rel
        if not backup.exists():
            backup.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, backup)
    write_json(ROOT / 'release/asset-runtime/cooked-patches.json', patch)
    write_json(ROOT / 'release/asset-runtime/texture-recipes.json', recipes)
    recipe_path = ROOT / 'release/asset-runtime/texture-recipes.json'
    recipe_path.write_bytes(recipe_path.read_bytes().replace(b'\r\n', b'\n'))
    pak_relative = 'local/' + pak.resolve().relative_to((ROOT / 'local').resolve()).as_posix()
    report = dict(status='PASS', pak=pak_relative, sha256=sha(pak), bytes=pak.stat().st_size, patches=rows, user_pixels_bundled=False, native_cook=False, original_paks_modified=False)
    write_json(output / 'asset-build.json', report)
    log('VB1_ASSETS', 'PASS', 'five blank Texture2D clones; original paks unchanged; jar recipes only')
    print('VB creative assets built:', pak.name, sha(pak))
    return report
if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--baseline', type=Path, default=ROOT / 'local/taskVB/rebuild/baseline')
    p.add_argument('--output', type=Path, default=ROOT / 'local/taskVB/creative-assets')
    a = p.parse_args()
    build(a.baseline, a.output)
