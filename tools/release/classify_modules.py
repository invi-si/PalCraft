# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright Invi
"""Generate a complete, reviewable module/PalSchema/pak pack manifest."""
import os
from common import *
BASE = ROOT / 'runtime/PalCraft'
if not BASE.exists():
    BASE = ROOT / 'runtime/MinecraftBlocks'
ISLAND = 'alex alex67 alex_pose alex_prices alex_trade bossD bossD_data bossFA boss_barF boss_motionD boss_mountI boss_perchE boss_poseE boss_rideP capture105 costume108 costume_camera108c costume_events108b costume_fidelity_x4 costume_runtimeJ creeper103 custom_fxI custom_motionAc custom_palsA custom_palsA_data custom_sizeB custom_sizeB_data farm_capture96 farm_ground96 farm_ground96_data fieldFA_data follow86 golemAc hostiles107 island islands88 islands88_data islands89_data island_actorB island_data island_offsets89 island_streamB island_x5_data island_x5_manifest island_x6_data island_x6_desert island_x6_jungle island_x6_mushroom island_x6_plains loot88 map111 map_historyN mobs mob_models mob_models_x4 mob_motion mob_navigation model_dimensionsJ model_registryJ native_pack native_trade owned_travel pal_combat pal_projectiles91 passive_flee101 poseK slice_alpha_x8 slice_journal_x8 slice_native_x8 slice_npcs_x8 slice_trade_core_x8 slice_trade_x8 slice_world_x8 slice_x8_data variantsJ variantsK vanilla_pose_compiled_x4 vanilla_pose_program_x4 vanilla_pose_x4 wardenC water86 waystones83 zombie77'.split()
CORE = 'feature_flags pack_services config timers gc_budget frame_budget json world_scope world_identityQ3 legacy_paths local_data jar_data data_bindings outparmK pawn_readiness hitch109 startup_gate possession cell_state resource_state state_writer restore109 language native_items registry phase_c owned_travel marker_history npc_legacy'.split()

def classify_pak(name):
    low = name.lower()
    if low.startswith('pakchunk19992-'):
        return 'core'
    if 'motion-taskt' in low:
        return 'islands_animals'
    if 'map' in low:
        return 'map_art'
    if any((v in low for v in ['probe', 'verification'])):
        return 'test'
    if any((v in low for v in ['steve', 'armor', 'hurt', '-ui', 'selection', 'elytra', 'riding', 'motion-taskt', 'font'])):
        return 'hud_skins'
    if any((v in low for v in ['island', 'plains', 'desert', 'jungle', 'mushroom', 'zombie', '-mob', 'spider', 'creeper', 'animals', 'host', 'creatures', 'custom-pal', 'warden', 'boss', 'costume', 'fidelity', 'coast'])):
        return 'islands_animals'
    return 'core'

def main():
    audit = Audit()
    files = {p.stem: p for p in BASE.rglob('*.lua')}
    tests = {n for n, p in files.items() if stripped(p)}
    texts = {n: p.read_text(encoding='utf-8-sig') for n, p in files.items()}
    dependencies = {n: deps(text) - tests for n, text in texts.items()}

    def closure(seeds):
        seen = set(seeds)
        todo = list(seen)
        while todo:
            for n in dependencies.get(todo.pop(), ()):
                if n in files and n not in seen:
                    seen.add(n)
                    todo.append(n)
        return seen
    hud_seeds = set(files) - set(ISLAND) - set(CORE) - tests - {'main'}
    islands = closure(ISLAND)
    hud = closure(hud_seeds)
    core = closure(CORE) | islands & hud
    rows = []
    for n, p in sorted(files.items()):
        pack = 'test' if n in tests else 'core' if n in core or n == 'main' else 'islands_animals' if n in ISLAND else 'hud_skins'
        raw_deps = deps(texts[n])
        rows.append(dict(path=p.relative_to(ROOT).as_posix(), module=n, pack=pack, audit_exclusions=audit.reasons(p.relative_to(ROOT).as_posix()), dependencies=sorted(raw_deps - tests), stripped_dependencies=sorted(raw_deps & tests), dependency_notes='Entry dispatch: HUD factories only when hud_skins; native_pack only for islands-only. Optional world factories gated before load.' if n == 'main' else 'Shared pure library or native/audio support; declaring it does not start a HUD or world service.' if pack == 'core' else 'Excluded development-only file.' if pack == 'test' else 'Requires core; optional factories start only with this pack.'))
    schemas = []
    for p in sorted((ROOT / 'schema').iterdir()):
        if not p.is_dir():
            continue
        pack = 'core' if p.name in ('MinecraftBlocks', 'PalCraft_Blocks') else 'islands_animals'
        name = p.name if p.name.startswith('PalCraft_') else 'PalCraft_' + p.name.removeprefix('Minecraft')
        schemas.append(dict(path=p.relative_to(ROOT).as_posix(), destination=name, pack=pack, dependency_notes='Shared item definitions support native island drops/trades and HUD building; asset references stay stable.' if pack == 'core' else 'Native Pal/NPC/loot schema; does not depend on replacement HUD or controls.'))
    pak_inventory = ROOT / 'local/taskRA/original-paks.json'
    paks = []
    if pak_inventory.exists():
        for row in read_json(pak_inventory):
            name = row['name']
            content = sorted(set((f['path'].split('/')[2] for f in row['files'] if len(f['path'].split('/')) > 2)))
            paks.append(dict(name=name, source='local/taskRA/original-paks/' + name, pack=classify_pak(name), sha256=row['sha256'], bytes=row['bytes'], entry_count=len(row['files']), legacy=True, distributable=False, dependency_notes='Legacy archive classified for replacement; never cleared by filename. Mixed packages require clean per-pack RA split; stable internal /Game paths.', content_roots=content))
    if isinstance(audit.data, list):
        known = {r['name'] for r in paks}
        for record in audit.data:
            container = str(record.get('container', ''))
            name = container.replace('\\', '/').rsplit('/', 1)[-1]
            if name.lower().endswith('.pak') and name not in known:
                known.add(name)
                paks.append(dict(name=name, source='schema/MinecraftAlex/paks/' + name, pack='islands_animals', legacy=True, distributable=False, dependency_notes='Legacy PalSchema NPC archive. Replace or independently audit; no implicit release clearance.'))
    result = dict(format_version=1, product='PalCraft', version='1.0', runtime_source_root=BASE.relative_to(ROOT).as_posix(), pack_dependencies={'core': [], 'hud_skins': ['core'], 'islands_animals': ['core'], 'map_art': ['core', 'islands_animals']}, strip_patterns=STRIP_FILES, lua=rows, schema=schemas, paks=paks, sanitizers={'map_historyN': 'Empty production marker history; owner GUID fixture excluded.'}, asset_rule='No Mojang/Palworld pixels, sounds or owner skins. Audit exclusions apply before copying. RA clean pak manifest must be hash-bound.', pak_replacements_manifest='local/release/paks.json')
    write_json(ROOT / 'release/modules.json', result)
    print(f'Classified {len(rows)} Lua files, {len(schemas)} schema packs, {len(paks)} legacy paks')
if __name__ == '__main__':
    main()
