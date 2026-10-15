# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright Invi
"""Blender background script: export selected original mesh/rig objects to FBX.

blender your-model.blend --background --python blender_export.py -- --output local/model.fbx
"""
import os
import argparse
from pathlib import Path
import sys
import bpy

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in bpy.context.scene.objects:
        obj.select_set(obj.type in {'MESH', 'ARMATURE'})
    bpy.ops.export_scene.fbx(filepath=str(output), use_selection=True, object_types={'MESH', 'ARMATURE'}, add_leaf_bones=False, bake_anim=True, path_mode='RELATIVE', embed_textures=False)
if __name__ == '__main__':
    main()
