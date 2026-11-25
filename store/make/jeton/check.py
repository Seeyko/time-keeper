"""Contrôle de l'export : réimporte jeton.glb et jeton.usdz, liste les nœuds, rend le glb avec ses textures cuites."""
import os, sys, math, zipfile
import bpy
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build, render

for kind in ('usdz', 'glb'):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.preferences.addon_enable(module='cycles')
    p = os.path.join(HERE, 'export', 'jeton.' + kind)
    if kind == 'glb':
        bpy.ops.preferences.addon_enable(module='io_scene_gltf2')
        bpy.ops.import_scene.gltf(filepath=p)
    else:
        bpy.ops.wm.usd_import(filepath=p)
    tris = 0
    for o in bpy.data.objects:
        if o.type == 'MESH':
            o.data.calc_loop_triangles()
            tris += len(o.data.loop_triangles)
    print(kind, os.path.getsize(p) // 1024, 'Ko', tris, 'triangles')
    print('  ', sorted(o.name for o in bpy.data.objects))
    j = bpy.data.objects.get('Jeton')
    print('   Jeton monde :', [round(v, 3) for v in j.matrix_world.to_euler()], 'parent', j.parent.name if j.parent else None)
    i1 = bpy.data.objects['Index1']
    print('   Index1 monde :', [round(v, 3) for v in i1.matrix_world.translation])
    print('   matières :', sorted(m.name for m in bpy.data.materials))

sc = bpy.context.scene
build.world()
cam = bpy.data.objects.new('Camera', bpy.data.cameras.new('Camera'))
sc.collection.objects.link(cam)
cam.location = (0, -8, 0)
cam.rotation_euler = (math.pi / 2, 0, 0)
cam.data.lens = 190
sc.camera = cam
render.cycles(sc, 800, 48)
root = [o for o in bpy.data.objects if o.name == 'Jeton'][0]
root.rotation_mode = 'XYZ'
for name, rot in (('recto', (0, 0, 0)), ('verso', (0, 0, math.pi)), ('trois-quarts', (math.radians(-16), 0, math.radians(-38)))):
    root.rotation_euler = rot
    sc.render.filepath = os.path.join(HERE, 'export', '_tmp', f'apercu-{name}.png')
    bpy.ops.render.render(write_still=True)
    render.nuit(sc.render.filepath)
print('CHECK ok')
