# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright Invi
"""Run with UE 5.1's Python commandlet to prepare our local authoring assets.

This imports original unrigged FBXs only to check the authoring pipeline. It
does not bind a native skeleton, replace gameplay assets, cook or install a mod.
The input JSON lives in the development project's Saved/SteveDev/plan.json.
"""
import os
import json
from pathlib import Path
import unreal
ROOT = '/Game/MinecraftSteve/Authoring'

def import_file(source, destination, name, options=None):
    task = unreal.AssetImportTask()
    task.filename = str(source)
    task.destination_path = destination
    task.destination_name = name
    task.automated = True
    task.replace_existing = False
    task.save = True
    if options is not None:
        task.options = options
    if unreal.EditorAssetLibrary.does_asset_exist(destination + '/' + name):
        raise RuntimeError('Refusing to overwrite an existing authoring asset')
    unreal.AssetToolsHelpers.get_asset_tools().import_asset_tasks([task])
    paths = list(task.imported_object_paths)
    if not paths:
        raise RuntimeError('Import produced no assets: ' + str(source))
    return paths

def make_material(name, texture, overlay):
    tools = unreal.AssetToolsHelpers.get_asset_tools()
    material = tools.create_asset(name, ROOT, unreal.Material, unreal.MaterialFactoryNew())
    if material is None:
        raise RuntimeError('Material creation failed: ' + name)
    material.set_editor_property('two_sided', False)
    material.set_editor_property('used_with_skeletal_mesh', True)
    if overlay:
        material.set_editor_property('blend_mode', unreal.BlendMode.BLEND_MASKED)
        material.set_editor_property('opacity_mask_clip_value', 0.01)
    node = unreal.MaterialEditingLibrary.create_material_expression(material, unreal.MaterialExpressionTextureSample, -400, 0)
    node.set_editor_property('texture', texture)
    unreal.MaterialEditingLibrary.connect_material_property(node, 'RGB', unreal.MaterialProperty.MP_BASE_COLOR)
    if overlay:
        unreal.MaterialEditingLibrary.connect_material_property(node, 'A', unreal.MaterialProperty.MP_OPACITY_MASK)
    roughness = unreal.MaterialEditingLibrary.create_material_expression(material, unreal.MaterialExpressionConstant, -200, 200)
    roughness.set_editor_property('r', 1.0)
    unreal.MaterialEditingLibrary.connect_material_property(roughness, '', unreal.MaterialProperty.MP_ROUGHNESS)
    unreal.MaterialEditingLibrary.recompile_material(material)
    unreal.EditorAssetLibrary.save_loaded_asset(material)
    return material

def main():
    dev = Path(unreal.Paths.project_dir()) / 'Saved' / 'SteveDev'
    plan = json.loads((dev / 'plan.json').read_text(encoding='utf-8'))
    report = {'status': 'AUTHORING_ONLY', 'gameplay': 'NOT_RUN', 'assets': []}
    for variant in plan['variants']:
        arm_format = variant['arm_format']
        suffix = arm_format.title()
        texture_paths = import_file(variant['skin_png'], ROOT, 'T_Steve_' + suffix)
        texture = unreal.EditorAssetLibrary.load_asset(texture_paths[0])
        if not isinstance(texture, unreal.Texture2D):
            raise RuntimeError('Expected Texture2D')
        texture.set_editor_property('filter', unreal.TextureFilter.TF_NEAREST)
        texture.set_editor_property('lod_group', unreal.TextureGroup.TEXTUREGROUP_PIXELS2D)
        texture.set_editor_property('mip_gen_settings', unreal.TextureMipGenSettings.TMGS_NO_MIPMAPS)
        texture.set_editor_property('srgb', True)
        unreal.EditorAssetLibrary.save_loaded_asset(texture)
        base = make_material('M_Steve_' + suffix + '_Base', texture, False)
        outer = make_material('M_Steve_' + suffix + '_Overlay', texture, True)
        options = unreal.FbxImportUI()
        options.automated_import_should_detect_type = False
        options.mesh_type_to_import = unreal.FBXImportType.FBXIT_STATIC_MESH
        options.import_as_skeletal = False
        options.import_mesh = True
        options.import_animations = False
        options.import_materials = False
        options.import_textures = False
        options.static_mesh_import_data.combine_meshes = True
        options.static_mesh_import_data.auto_generate_collision = False
        mesh_paths = import_file(variant['fbx'], ROOT, 'SM_UnriggedSteve_' + suffix, options)
        mesh = unreal.EditorAssetLibrary.load_asset(mesh_paths[0])
        if not isinstance(mesh, unreal.StaticMesh):
            raise RuntimeError('Unrigged authoring check must produce StaticMesh')
        slots = list(mesh.get_editor_property('static_materials'))
        slot_names = []
        for index, slot in enumerate(slots):
            slot_name = str(slot.get_editor_property('material_slot_name'))
            slot_names.append(slot_name)
            mesh.set_material(index, outer if 'overlay' in slot_name.lower() else base)
        unreal.EditorAssetLibrary.save_loaded_asset(mesh)
        bounds = mesh.get_bounding_box()
        height = bounds.max.z - bounds.min.z
        if not 179 <= height <= 190:
            raise RuntimeError('Unexpected FBX height in centimetres: ' + str(height))
        report['assets'].append({'arm_format': arm_format, 'texture': texture_paths, 'mesh': mesh_paths, 'material_slots': slot_names, 'height_cm_including_overlay': height, 'native_rig': 'NOT_BOUND'})
    (dev / 'authoring-import-report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    unreal.log('STEVE_AUTHORING_IMPORT_PASS ' + json.dumps(report))
main()
