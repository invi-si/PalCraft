# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright Invi
"""Share shaders across the generated atlas textures; touch owned assets only."""
import os
import json
from pathlib import Path
import unreal
ROOT = Path(os.environ.get('PALCRAFT_ASSET_ROOT', '.') + '')
DEST = '/Game/MinecraftBlocks'
tools = unreal.AssetToolsHelpers.get_asset_tools()
plans = json.loads((ROOT / 'local/task13/generated/plan.json').read_text())
masters = {}
instances = []
for p in plans:
    key = p['render_mode'] + ('_light' if p.get('emissive') else '')
    name = 'M_MC_Master_' + key
    if key not in masters:
        master = unreal.EditorAssetLibrary.load_asset(DEST + '/' + name) if unreal.EditorAssetLibrary.does_asset_exist(DEST + '/' + name) else tools.create_asset(name, DEST, unreal.Material, unreal.MaterialFactoryNew())
        unreal.MaterialEditingLibrary.delete_all_material_expressions(master)
        master.set_editor_property('used_with_instanced_static_meshes', True)
        master.set_editor_property('blend_mode', {'opaque': unreal.BlendMode.BLEND_OPAQUE, 'masked': unreal.BlendMode.BLEND_MASKED, 'translucent': unreal.BlendMode.BLEND_TRANSLUCENT}[p['render_mode']])
        sample = unreal.MaterialEditingLibrary.create_material_expression(master, unreal.MaterialExpressionTextureSampleParameter2D, 0, 0)
        sample.set_editor_property('parameter_name', 'Atlas')
        sample.texture = unreal.EditorAssetLibrary.load_asset(DEST + '/T_MC_Atlas_Dirt')
        unreal.MaterialEditingLibrary.connect_material_property(sample, 'RGB', unreal.MaterialProperty.MP_BASE_COLOR)
        if p.get('emissive'):
            unreal.MaterialEditingLibrary.connect_material_property(sample, 'RGB', unreal.MaterialProperty.MP_EMISSIVE_COLOR)
        if p['render_mode'] != 'opaque':
            unreal.MaterialEditingLibrary.connect_material_property(sample, 'A', unreal.MaterialProperty.MP_OPACITY if p['render_mode'] == 'translucent' else unreal.MaterialProperty.MP_OPACITY_MASK)
        rough = unreal.MaterialEditingLibrary.create_material_expression(master, unreal.MaterialExpressionConstant, 0, 160)
        rough.r = 1
        unreal.MaterialEditingLibrary.connect_material_property(rough, '', unreal.MaterialProperty.MP_ROUGHNESS)
        unreal.MaterialEditingLibrary.recompile_material(master)
        unreal.EditorAssetLibrary.save_loaded_asset(master, only_if_is_dirty=False)
        masters[key] = master
    name = 'M_MC_I_' + p['identifier']
    path = DEST + '/' + name
    instance = unreal.EditorAssetLibrary.load_asset(path) if unreal.EditorAssetLibrary.does_asset_exist(path) else tools.create_asset(name, DEST, unreal.MaterialInstanceConstant, unreal.MaterialInstanceConstantFactoryNew())
    unreal.MaterialEditingLibrary.set_material_instance_parent(instance, masters[key])
    texture = unreal.EditorAssetLibrary.load_asset(DEST + '/T_MC_Atlas_' + p['identifier'])
    unreal.MaterialEditingLibrary.set_material_instance_texture_parameter_value(instance, 'Atlas', texture)
    unreal.EditorAssetLibrary.save_loaded_asset(instance, only_if_is_dirty=False)
    mesh = unreal.EditorAssetLibrary.load_asset(DEST + '/SM_MC_' + p['identifier'])
    mesh.set_material(0, instance)
    assert unreal.EditorAssetLibrary.save_loaded_asset(mesh, only_if_is_dirty=False)
    instances.append(name)
    if len(instances) % 200 == 0:
        print('MC_SHARED_MESHES', len(instances), flush=True)
old_assets = []
for p in plans:
    old = DEST + '/M_MC_' + p['identifier']
    if unreal.EditorAssetLibrary.does_asset_exist(old):
        old_assets.append(unreal.EditorAssetLibrary.load_asset(old))
if old_assets:
    assert unreal.EditorAssetLibrary.delete_loaded_assets(old_assets)
(ROOT / 'local/task13/shared-materials.json').write_text(json.dumps({'masters': list(masters), 'instances': instances}) + '\n')
print('MC_SHARED_MATERIALS_PASS', len(masters), len(instances))
