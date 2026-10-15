# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright Invi
"""Build pixel-free cooked paks and their install-time patch manifest.

Build inputs are private audit/extraction evidence; generated manifests contain
paths, sizes, hashes and authored recipes only. Never target a game directory.
"""
import os
from pathlib import Path
from datetime import datetime
import collections, hashlib, json, os, re, struct, sys
from cooked_payload import layout, blank_texture, write_pak, rename_texture
from original_icons import PACKAGES as ORIGINAL_ICONS, render as render_original_icon
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'local/taskRE'
RA = ROOT / 'local/taskRA'

def sha(data):
    return hashlib.sha256(data).hexdigest()

def event(item, status, detail):
    with (ROOT / 'coordination/CODEX_PROGRESS.txt').open('a', encoding='utf8') as f:
        f.write(f'RE {datetime.now():%H:%M} {item} {status} {detail}\n')

def check():
    text = (ROOT / 'coordination/OPUS_INTERRUPT.txt').read_text(encoding='utf-8-sig')
    prior = (ROOT / 'coordination/CODEX_PROGRESS.txt').read_text(encoding='utf-8-sig')
    for seq in re.findall('SEQ\\s*(\\d+)', text):
        if f'ACK INTERRUPT {seq}' not in prior:
            event('ACK', 'INTERRUPT', seq)
    latest = re.split('(?=SEQ\\d+)', text)[-1]
    assert not re.search('STATU${PALCRAFT_ASSET_ROOT}', latest, re.I), latest
    return latest

def dump(path, obj):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, indent=2), encoding='utf8')

def original_files():
    audit = json.loads((ROOT / 'local/release/audit.json').read_text())
    byPak = collections.defaultdict(list)
    for r in audit:
        if r.get('container', '').endswith('.pak'):
            byPak[Path(r['container']).name].append(r)
    out = {}
    allByPath = {}
    provenance = {}
    for pak in json.loads((RA / 'original-paks.json').read_text()):
        name = pak['name']
        rows = byPak[name]
        prefix = []
        for file in pak['files'][:20]:
            matches = [r for r in rows if r['path'].endswith('/' + file['path']) or r['path'] == file['path']]
            if len(matches) == 1:
                prefix.append(matches[0]['path'][:-len(file['path'])])
        assert prefix and len(set(prefix)) == 1, (name, prefix)
        lookup = {r['path']: r for r in rows}
        files = {}
        for f in pak['files']:
            full = prefix[0] + f['path']
            path = RA / 'unpacked' / Path(name).stem / f['path']
            files[full] = path
            allByPath[full] = path
            provenance[name, full] = lookup[full]
        out[name] = files
    return (out, allByPath, provenance)

def recipe_file(recipe):

    def node(r):
        if isinstance(r, str):
            r = {'op': 'source', 'path': r}
        else:
            r = r.copy()
            if 'src' in r:
                r['src'] = node(r['src'])
            if 'layers' in r:
                r['layers'] = [dict(x, src=node(x['src'])) for x in r['layers']]
            if 'faces' in r:
                r['faces'] = [node(x) for x in r['faces']]
        return sha(json.dumps(r, sort_keys=True, separators=(',', ':')).encode())[:20]
    return recipe if isinstance(recipe, str) else '_palcraft/' + node(recipe) + '.png'

def source_paths(recipe):
    if isinstance(recipe, str):
        return [recipe]
    out = []
    if 'src' in recipe:
        out += source_paths(recipe['src'])
    for x in recipe.get('layers', []):
        out += source_paths(x['src'])
    for x in recipe.get('faces', []):
        out += source_paths(x)
    return sorted(set(out))

def blank_font(size):
    if os.environ.get('PALCRAFT_PYTHON_PACKAGES'):
        sys.path.append(os.environ['PALCRAFT_PYTHON_PACKAGES'])
    from fontTools.fontBuilder import FontBuilder
    from fontTools.pens.ttGlyphPen import TTGlyphPen
    import io
    f = FontBuilder(1024, isTTF=True)
    f.setupGlyphOrder(['.notdef', 'space'])
    f.setupCharacterMap({32: 'space'})
    g = TTGlyphPen(None).glyph()
    f.setupGlyf({'.notdef': g, 'space': g})
    f.setupHorizontalMetrics({'.notdef': (768, 0), 'space': (512, 0)})
    f.setupHorizontalHeader(ascent=896, descent=-128)
    f.setupNameTable({'familyName': 'PalCraft Placeholder', 'styleName': 'Regular'})
    f.setupOS2()
    f.setupPost()
    f.setupMaxp()
    f.font['head'].created = f.font['head'].modified = 0
    f.font.recalcTimestamp = False
    b = io.BytesIO()
    f.save(b)
    buf = b.getvalue()
    assert len(buf) <= size
    return buf + bytes(size - len(buf))

def main():
    check()
    event('RE1', 'BUILD_START', 'Cooked layout manifest and blank-pixel paks; below-normal offline only')
    sources, allOriginal, provenance = original_files()
    paks = json.loads((ROOT / 'local/release/paks.json').read_text())['paks']
    recipes = json.loads((RA / 'texture-recipes.json').read_text())
    assets = {r['package']: r for r in json.loads((RA / 'texture-assets.json').read_text())}
    metadata = {r['package']: r for r in json.loads((RA / 'ue-inventory.json').read_text())['assets']}
    extraRecipes = OUT / 'additional-recipes.json'
    if extraRecipes.exists():
        recipes.update(json.loads(extraRecipes.read_text()))
    manifest = {'version': 1, 'pakVersion': 3, 'format': 'BGRA8 cooked payload ranges', 'recipeFile': 'texture-recipes.json', 'fontGenerator': 'CookedFontCache.cs', 'paks': []}
    proof = []
    cache = {}
    counts = collections.Counter()
    errors = []
    outPaks = OUT / 'blank-paks'
    outPaks.mkdir(exist_ok=True, parents=True)
    template = OUT / 'template-assets'
    template.mkdir(exist_ok=True)
    fontFiles = sources['pakchunk20002-minecraft-font_P.pak']
    fontPayload = (OUT / 'font-original.ttf').read_bytes()
    fallback = blank_font(len(fontPayload))
    assert sha((OUT / 'font-test/_palcraft/font.ttf').read_bytes()) == sha(fontPayload)
    cleared = set(json.loads((RA / 'own-metadata-result.json').read_text())) | {r['package'] for r in json.loads((RA / 'own-solid-source.json').read_text())}
    extraFiles = {}
    extras = {'T_PC_Steve': ('/Game/MinecraftSteve/Authoring/steve-wide-local', 'textures/entity/player/wide/steve.png'), 'T_PC_AlexWide': ('/Game/MinecraftNPC/Alex/T_AlexSkin', 'textures/entity/player/wide/alex.png'), 'T_PC_AlexSlim': ('/Game/MinecraftNPC/Alex/T_AlexSkin', 'textures/entity/player/slim/alex.png'), 'T_PC_Dirt': ('/Game/MinecraftIsland114_jungle/T_M_018', 'textures/block/dirt.png')}
    for name, (oldPackage, resource) in extras.items():
        package = '/Game/MinecraftRuntimeAssets/' + name
        oldFull = 'Pal/Content/' + oldPackage.removeprefix('/Game/') + '.uasset'
        src = allOriginal[oldFull]
        h = src.read_bytes()
        d = src.with_suffix('.uexp').read_bytes()
        h, d, _, _ = blank_texture(h, d)
        h, d = rename_texture(h, d, oldPackage, package)
        folder = OUT / 'extra-source' / name
        folder.mkdir(exist_ok=True, parents=True)
        (folder / (name + '.uasset')).write_bytes(h)
        (folder / (name + '.uexp')).write_bytes(d)
        for ext in ['.uasset', '.uexp']:
            extraFiles['Pal/Content/MinecraftRuntimeAssets/' + name + ext] = folder / (name + ext)
        recipes[package] = resource
        assets[package] = dict(size=[layout(d)['width'], layout(d)['height']])
        metadata[package] = dict(srgb=True)
    for pak in paks:
        name = pak['destination']
        check()
        response = RA / 'pak-responses' / (name + '.txt')
        files = {}
        for line in response.read_text().splitlines():
            m = re.fullmatch('"(.+)" "../../../(.+)"', line)
            assert m, line
            files[m[2]] = Path(m[1])
        originals = sources.get(name, {})
        for full, source in list(files.items()):
            audit = provenance.get((name, full), {})
            if audit.get('kind') == 'material' and full in originals:
                files[full] = originals[full]
                counts['originalMaterialFiles'] += 1
        if name == 'pakchunk29980-palcraft-shared-dependencies_P.pak':
            files.update(fontFiles)
            files.update(extraFiles)
            for dependency in ['M_MC_Masked', 'M_MC_Translucent', 'T_Flower82']:
                for ext in ['.uasset', '.uexp']:
                    full = 'Pal/Content/MinecraftMaterials82/' + dependency + ext
                    files[full] = allOriginal[full]
                    if dependency.startswith('M_'):
                        counts['originalMaterialFiles'] += 1
        patches = []
        for full in list(files):
            if not full.endswith('.uasset'):
                continue
            package = '/Game/' + full.removeprefix('Pal/Content/')[:-7]
            audit = provenance.get((name, full), {})
            unresolved = package not in recipes and package not in cleared and (audit.get('kind') == 'texture') and (audit.get('provenance') == 'mojang')
            if package not in recipes and (not package.startswith('/Game/MinecraftFonts/Face/')) and (not unresolved) and (package not in ORIGINAL_ICONS):
                continue
            stem = full[:-7]
            isFont = package.startswith('/Game/MinecraftFonts/Face/')
            source = originals.get(full) or allOriginal.get(full) or files[full]
            exp = source.with_suffix('.uexp')
            bulk = source.with_suffix('.ubulk')
            h = source.read_bytes()
            d = exp.read_bytes()
            ub = bulk.read_bytes() if bulk.exists() else b''
            key = sha(h + d + ub)
            if isFont:
                start = d.find(fontPayload)
                assert start >= 0 and d.count(fontPayload) == 1
                new = bytearray(d)
                new[start:start + len(fontPayload)] = fallback
                for m in re.finditer(b'[A-Za-z]:/[^\\x00]+', new):
                    new[m.start():m.end()] = b' ' * (m.end() - m.start())
                target = template / key
                target.mkdir(exist_ok=True)
                (target / 'asset.uasset').write_bytes(h)
                (target / 'asset.uexp').write_bytes(new)
                row = dict(package=package, file=stem + '.uexp', kind='font', source='_palcraft/font.ttf', sources=['font/default.json', 'font/include/*.json', 'font/*.zip', 'textures/font/*.png'], offset=start, size=len(fontPayload), expectedPayloadSha256=sha(fontPayload), originalFileSha256=sha(d), privacyScrub=True)
                patches.append(row)
                files[full] = target / 'asset.uasset'
                files[stem + '.uexp'] = target / 'asset.uexp'
                counts['fontFaces'] += 1
                proof.append(dict(pak=name, **row, originalSource=str(exp)))
                continue
            recipe = recipes.get(package)
            imageFile = recipe_file(recipe) if recipe is not None else '_palcraft/unavailable/' + package.rsplit('/', 1)[1] + '.png'
            if key not in cache:
                old = layout(d, ub)
                override = None
                if full not in originals and full not in allOriginal:
                    wanted = assets[package]['size']
                    if wanted != [old['width'], old['height']]:
                        override = wanted
                nh, nd, old, new = blank_texture(h, d, ub, override)
                target = template / key
                target.mkdir(exist_ok=True)
                (target / 'asset.uasset').write_bytes(nh)
                (target / 'asset.uexp').write_bytes(nd)
                cache[key] = (target, old, new)
            target, old, new = cache[key]
            files[full] = target / 'asset.uasset'
            files[stem + '.uexp'] = target / 'asset.uexp'
            files.pop(stem + '.ubulk', None)
            files.pop(stem + '.uptnl', None)
            if package in ORIGINAL_ICONS:
                from PIL import Image
                own = template / (key + '-original-icon')
                own.mkdir(exist_ok=True)
                data = bytearray((target / 'asset.uexp').read_bytes())
                for mip in new['mips']:
                    icon = render_original_icon(ORIGINAL_ICONS[package]).resize((mip['width'], mip['height']), Image.Resampling.NEAREST)
                    pixels = icon.tobytes('raw', 'BGRA')
                    assert len(pixels) == mip['size']
                    data[mip['offset']:mip['offset'] + mip['size']] = pixels
                (own / 'asset.uasset').write_bytes((target / 'asset.uasset').read_bytes())
                (own / 'asset.uexp').write_bytes(data)
                files[full] = own / 'asset.uasset'
                files[stem + '.uexp'] = own / 'asset.uexp'
                cleared.add(package)
                counts['originalIconInstances'] += 1
                proof.append(dict(pak=name, package=package, kind='original-icon', source='tools/release/original_icons.py', noInputPixels=True))
                continue
            srgb = metadata.get(package, {}).get('srgb', True)
            row = dict(package=package, file=stem + '.uexp', kind='texture', source=imageFile, sources=source_paths(recipe) if recipe is not None else [], supported=not unresolved, format='PF_B8G8R8A8', originalFormat=old['format'], srgb=srgb, width=new['width'], height=new['height'], mips=[{k: v for k, v in m.items() if k in ['index', 'offset', 'size', 'width', 'height']} for m in new['mips']], normalChannels=old['format'] == 'PF_BC5')
            row['forceOpaque'] = old['format'] == 'PF_DXT1'
            if unresolved:
                errors.append(dict(pak=name, package=package, reason='Original image has no jar reconstruction recipe; blank fallback retained', sourceAuthoringFile=assets.get(package, {}).get('file')))
            patches.append(row)
            counts['textureInstances'] += 1
            counts['original:' + old['format']] += 1
            proof.append(dict(pak=name, **row, originalSource=str(exp), originalHeader=str(source), originalLayout=old, originalFileSha256=sha(d), headerChanged=h != files[full].read_bytes(), recipe=recipe))
        patched = {p['package'] for p in patches}
        for (pn, full), r in provenance.items():
            if pn == name and r['kind'] == 'texture' and (r['provenance'] == 'mojang') and full.endswith('.uasset') and (full in files):
                package = '/Game/' + full.removeprefix('Pal/Content/')[:-7]
                if package not in patched and package not in cleared:
                    raise AssertionError((name, package, 'Unaccounted texture'))
        info = write_pak(outPaks / name, files)
        byFile = {e['path']: e for e in info.pop('entries')}
        for p in patches:
            e = byFile[p['file']]
            p.update({'fileSize' if k == 'size' else k: e[k] for k in ['dataOffset', 'size', 'headerHashOffset', 'indexHashOffset']})
        info.update(name=name, pack=pak['pack'], patches=patches, files=len(files))
        manifest['paks'].append(info)
        event('RE1', 'PAK_BUILT', name + ' textures/fonts=' + str(len(patches)))
    assert len(paks) == 60
    dump(OUT / 'asset-proof-plan.json', proof)
    dump(OUT / 'build-summary.json', dict(counts=counts, errors=errors, paks=len(paks), uniqueTextureTemplates=len(cache)))
    dump(ROOT / 'release/asset-runtime/cooked-patches.json', manifest)
    replacement = []
    for row in manifest['paks']:
        replacement.append(dict(source='local/taskRE/blank-paks/' + row['name'], destination=row['name'], name=row['name'], pack=row['pack'], sha256=row['sha256'], clean=True))
    dump(OUT / 'paks.json', dict(paks=replacement, complete=False, pack_split_validated=False, native_compatibility_ready=False, texturePatching=True))
    event('RE1', 'BUILD_PARTIAL' if errors else 'BUILD_PASS', json.dumps(dict(counts, paks=60, unresolved=len(errors))))
    print(json.dumps(dict(counts, paks=60, unresolved=len(errors))))
if __name__ == '__main__':
    main()
