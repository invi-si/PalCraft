# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright Invi
"""Author only our block assets in the existing separate UE5.1 project."""
import os
import json
from pathlib import Path
import unreal
ROOT = '/Game/MinecraftBlocks'
SOURCE = Path(os.environ.get('PALCRAFT_ASSET_ROOT', '.') + '')
REPORT = Path(unreal.Paths.project_dir()) / 'Saved/MinecraftBlocks/editor-report.json'
REPORT.parent.mkdir(parents=True, exist_ok=True)

def import_asset(file, name, options=None):
    existing = unreal.EditorAssetLibrary.load_asset(ROOT + '/' + name)
    if existing:
        return existing
    task = unreal.AssetImportTask()
    for prop, value in [('filename', str(file)), ('destination_path', ROOT), ('destination_name', name), ('automated', True), ('replace_existing', True), ('save', True)]:
        task.set_editor_property(prop, value)
    if options:
        task.set_editor_property('options', options)
    unreal.AssetToolsHelpers.get_asset_tools().import_asset_tasks([task])
    paths = list(task.get_editor_property('imported_object_paths'))
    if not paths:
        raise RuntimeError('Import produced no objects: ' + str(file))
    current = paths[0].split('.')[0]
    target = ROOT + '/' + name
    if current != target:
        assert current.startswith(ROOT + '/'), current
        if unreal.EditorAssetLibrary.does_asset_exist(target):
            raise RuntimeError('Unexpected duplicate import destination: ' + target)
        assert unreal.EditorAssetLibrary.rename_asset(current, target)
    asset = unreal.EditorAssetLibrary.load_asset(target)
    if asset is None:
        raise RuntimeError('Import missing: ' + name)
    return asset

def main():
    texture = import_asset(SOURCE / 'dirt.png', 'T_MC_Dirt')
    texture.set_editor_property('filter', unreal.TextureFilter.TF_NEAREST)
    texture.set_editor_property('lod_group', unreal.TextureGroup.TEXTUREGROUP_PIXELS2D)
    texture.set_editor_property('mip_gen_settings', unreal.TextureMipGenSettings.TMGS_NO_MIPMAPS)
    texture.set_editor_property('srgb', True)
    tools = unreal.AssetToolsHelpers.get_asset_tools()
    material = unreal.EditorAssetLibrary.load_asset(ROOT + '/M_MC_Dirt')
    if not material:
        material = tools.create_asset('M_MC_Dirt', ROOT, unreal.Material, unreal.MaterialFactoryNew())
        sample = unreal.MaterialEditingLibrary.create_material_expression(material, unreal.MaterialExpressionTextureSample, 0, 0)
        sample.set_editor_property('texture', texture)
        unreal.MaterialEditingLibrary.connect_material_property(sample, 'RGB', unreal.MaterialProperty.MP_BASE_COLOR)
        rough = unreal.MaterialEditingLibrary.create_material_expression(material, unreal.MaterialExpressionConstant, 0, 160)
        rough.set_editor_property('r', 1.0)
        unreal.MaterialEditingLibrary.connect_material_property(rough, '', unreal.MaterialProperty.MP_ROUGHNESS)
        material.set_editor_property('used_with_instanced_static_meshes', True)
        unreal.MaterialEditingLibrary.recompile_material(material)
    options = unreal.FbxImportUI()
    options.automated_import_should_detect_type = False
    options.mesh_type_to_import = unreal.FBXImportType.FBXIT_STATIC_MESH
    options.import_as_skeletal = False
    options.import_materials = False
    options.import_textures = False
    options.static_mesh_import_data.combine_meshes = True
    options.static_mesh_import_data.auto_generate_collision = False
    mesh = import_asset(SOURCE / 'dirt-cube.fbx', 'SM_MC_Dirt', options)
    mesh.set_material(0, material)
    body = mesh.get_editor_property('body_setup')
    box = unreal.KBoxElem()
    box.set_editor_property('center', unreal.Vector(0, 0, 0))
    box.set_editor_property('rotation', unreal.Rotator(0, 0, 0))
    for axis in ('x', 'y', 'z'):
        box.set_editor_property(axis, 100.0)
    box.set_editor_property('collision_enabled', unreal.CollisionEnabled.QUERY_AND_PHYSICS)
    geometry = body.get_editor_property('agg_geom')
    geometry.set_editor_property('box_elems', [box])
    for kind in ('sphere_elems', 'sphyl_elems', 'convex_elems', 'tapered_capsule_elems'):
        geometry.set_editor_property(kind, [])
    body.set_editor_property('agg_geom', geometry)
    body.set_editor_property('collision_trace_flag', unreal.CollisionTraceFlag.CTF_USE_SIMPLE_AND_COMPLEX)
    bounds = mesh.get_bounding_box()
    dimensions = [bounds.max.x - bounds.min.x, bounds.max.y - bounds.min.y, bounds.max.z - bounds.min.z]
    assert all((abs(v - 100) < 0.01 for v in dimensions)), dimensions
    blueprint = unreal.EditorAssetLibrary.load_asset(ROOT + '/BP_MC_BlockChunk')
    if not blueprint:
        factory = unreal.BlueprintFactory()
        factory.set_editor_property('parent_class', unreal.Actor)
        blueprint = tools.create_asset('BP_MC_BlockChunk', ROOT, unreal.Blueprint, factory)
    subsystem = unreal.get_engine_subsystem(unreal.SubobjectDataSubsystem)
    lib = unreal.SubobjectDataBlueprintFunctionLibrary
    handles = subsystem.k2_gather_subobject_data_for_blueprint(blueprint)
    component = None
    for handle in handles:
        obj = lib.get_object(lib.get_data(handle))
        if isinstance(obj, unreal.HierarchicalInstancedStaticMeshComponent):
            component = obj
    if component is None:
        handle, reason = subsystem.add_new_subobject(unreal.AddNewSubobjectParams(parent_handle=handles[0], new_class=unreal.HierarchicalInstancedStaticMeshComponent, blueprint_context=blueprint))
        if str(reason):
            raise RuntimeError(str(reason))
        subsystem.rename_subobject(handle, 'BlockInstances')
        component = lib.get_object(lib.get_data(handle))
    component.set_static_mesh(mesh)
    component.set_collision_profile_name('BlockAll')
    component.set_editor_property('generate_overlap_events', False)
    component.set_editor_property('can_ever_affect_navigation', True)
    component.set_editor_property('mobility', unreal.ComponentMobility.MOVABLE)
    unreal.BlueprintEditorLibrary.compile_blueprint(blueprint)
    for asset in (texture, material, mesh, blueprint):
        assert unreal.EditorAssetLibrary.save_loaded_asset(asset, only_if_is_dirty=False)
    result = {'status': 'AUTHORED_NOT_RUNTIME_TESTED', 'dimensions_cm': dimensions, 'simple_collision_count': len(body.get_editor_property('agg_geom').get_editor_property('box_elems')), 'hism_template': component.get_path_name(), 'collision_profile': str(component.get_collision_profile_name()), 'navigation_relevant': component.get_editor_property('can_ever_affect_navigation'), 'assets': [a.get_path_name() for a in (texture, material, mesh, blueprint)]}
    assert result['simple_collision_count'] == 1, result
    REPORT.write_text(json.dumps(result, indent=2), encoding='utf-8')
    unreal.log('MC_BLOCKS_AUTHOR_PASS ' + json.dumps(result))
try:
    main()
except Exception as exc:
    REPORT.write_text(json.dumps({'status': 'FAIL', 'error': str(exc)}, indent=2), encoding='utf-8')
    raise
