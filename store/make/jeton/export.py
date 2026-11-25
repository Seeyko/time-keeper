"""Cuisson des textures et export temps réel : python3 export.py
-> export/textures/*.jpg|png, export/jeton.glb, export/jeton.usdz"""
import os, sys, math, shutil, time
import bpy
from mathutils import Matrix
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build, render

OUT = os.path.join(HERE, 'export')
TEX = os.path.join(OUT, 'textures')
BAKED = ('Laiton', 'AcierGuilloche', 'AcierBrosse')
SIZE = 2048
BUMP_BAKE = (1.0, 0.0016)
FINAL = {'baseColor': 1024, 'normal': 2048, 'roughness': 1024}


def objs_of(mat):
    return [o for o in bpy.data.objects if o.type == 'MESH' and o.data.materials and o.data.materials[0] == mat]


def new_image(name, color, data):
    im = bpy.data.images.new(name, SIZE, SIZE, alpha=False, float_buffer=False, is_data=data)
    im.generated_color = (*color, 1)
    px = [0.0] * (SIZE * SIZE * 4)
    px[0::4] = [color[0]] * (SIZE * SIZE)
    px[1::4] = [color[1]] * (SIZE * SIZE)
    px[2::4] = [color[2]] * (SIZE * SIZE)
    px[3::4] = [1.0] * (SIZE * SIZE)
    im.pixels.foreach_set(px)
    return im


def bake_material(name):
    sc = bpy.context.scene
    mat = bpy.data.materials[name]
    nt = mat.node_tree
    out, bsdf = nt.nodes['out'], nt.nodes['bsdf']
    tex = nt.nodes.new('ShaderNodeTexImage')
    for n in nt.nodes:
        n.select = False
    tex.select = True
    nt.nodes.active = tex
    bpy.ops.object.select_all(action='DESELECT')
    obs = objs_of(mat)
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    d = build.PBR[name]
    res = {}
    em = nt.nodes.new('ShaderNodeEmission')
    enc = tuple(c * 12.92 if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055 for c in d['color'])
    for key, src, data, fill in (('baseColor', 'bake_bc', False, enc),
                                 ('roughness', 'bake_rough', True, (d['roughness'],) * 3)):
        im = new_image(f'{name}_{key}', fill, data)
        tex.image = im
        for l in list(em.inputs['Color'].links):
            nt.links.remove(l)
        nt.links.new(nt.nodes[src].outputs[0], em.inputs['Color'])
        nt.links.new(em.outputs[0], out.inputs['Surface'])
        sc.cycles.samples = 4
        bpy.ops.object.bake(type='EMIT', margin=12, use_clear=False)
        res[key] = im
    nt.links.new(bsdf.outputs[0], out.inputs['Surface'])
    nt.nodes.remove(em)
    im = new_image(f'{name}_normal', (0.5, 0.5, 1.0), True)
    tex.image = im
    sc.cycles.samples = 12
    # sans anisotropie en temps réel, le brossage doit vivre dans la normal map : relief renforcé à la cuisson
    bump = nt.nodes['bump']
    keep = (bump.inputs['Strength'].default_value, bump.inputs['Distance'].default_value)
    bump.inputs['Strength'].default_value, bump.inputs['Distance'].default_value = BUMP_BAKE
    bpy.ops.object.bake(type='NORMAL', normal_space='TANGENT', margin=12, use_clear=False)
    bump.inputs['Strength'].default_value, bump.inputs['Distance'].default_value = keep
    res['normal'] = im
    nt.nodes.remove(tex)
    return res


def save_textures(name, res):
    from PIL import Image
    import numpy as np
    paths = {}
    for key, im in res.items():
        a = np.empty(SIZE * SIZE * 4, dtype=np.float32)
        im.pixels.foreach_get(a)
        a = a.reshape(SIZE, SIZE, 4)[::-1, :, :3]
        img = Image.fromarray((np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8))
        s = FINAL[key]
        if s != SIZE:
            img = img.resize((s, s), Image.LANCZOS)
        p = os.path.join(TEX, f'{name}_{key}.jpg')
        if key == 'roughness':
            img.convert('L').save(p, quality=90)
            rough = img.convert('L')
        elif key == 'normal':
            img.save(p, quality=91, subsampling=0)
        else:
            img.save(p, quality=92, subsampling=0)
        paths[key] = p
    pm = os.path.join(TEX, f'{name}_metallic.png')
    Image.new('L', (64, 64), 255).save(pm)
    paths['metallic'] = pm
    # variante glTF : occlusion (blanc), rugosité (V), métal (B) dans une seule image
    orm = Image.merge('RGB', (Image.new('L', rough.size, 255), rough, Image.new('L', rough.size, 255)))
    po = os.path.join(OUT, '_tmp', f'{name}_orm.jpg')
    os.makedirs(os.path.dirname(po), exist_ok=True)
    orm.save(po, quality=90, subsampling=0)
    paths['orm'] = po
    return paths


def export_material(name, paths=None, orm=False):
    d = build.PBR[name]
    old = bpy.data.materials.get(name)
    m, nt, out = build.new_mat(name + '_tmp')
    p = build.N(nt, 'ShaderNodeBsdfPrincipled', 'bsdf')
    p.inputs['Base Color'].default_value = (*d['color'], 1)
    p.inputs['Metallic'].default_value = d['metallic']
    p.inputs['Roughness'].default_value = d['roughness']
    if 'emission' in d:
        p.inputs['Emission Color'].default_value = (*d['color'], 1)
        p.inputs['Emission Strength'].default_value = 1.0
    if 'alpha' in d:
        p.inputs['Alpha'].default_value = d['alpha']
        p.inputs['IOR'].default_value = 1.77
        try:
            m.surface_render_method = 'BLENDED'
        except Exception:
            m.blend_method = 'BLEND'
    if paths:
        def tex(key, cs):
            t = build.N(nt, 'ShaderNodeTexImage', key)
            t.image = bpy.data.images.load(paths[key], check_existing=True)
            t.image.colorspace_settings.name = cs
            return t
        nt.links.new(tex('baseColor', 'sRGB').outputs['Color'], p.inputs['Base Color'])
        nm = build.N(nt, 'ShaderNodeNormalMap')
        nt.links.new(tex('normal', 'Non-Color').outputs['Color'], nm.inputs['Color'])
        nt.links.new(nm.outputs[0], p.inputs['Normal'])
        if orm:
            sep = build.N(nt, 'ShaderNodeSeparateColor')
            nt.links.new(tex('orm', 'Non-Color').outputs['Color'], sep.inputs[0])
            nt.links.new(sep.outputs[1], p.inputs['Roughness'])
            nt.links.new(sep.outputs[2], p.inputs['Metallic'])
        else:
            nt.links.new(tex('roughness', 'Non-Color').outputs['Color'], p.inputs['Roughness'])
            nt.links.new(tex('metallic', 'Non-Color').outputs['Color'], p.inputs['Metallic'])
    nt.links.new(p.outputs[0], out.inputs['Surface'])
    for o in bpy.data.objects:
        if o.type == 'MESH' and o.data.materials and o.data.materials[0] == old:
            o.data.materials[0] = m
    bpy.data.materials.remove(old)
    m.name = name
    return m


def set_materials(all_paths, orm):
    for name in build.PBR:
        export_material(name, all_paths.get(name), orm)


if __name__ == '__main__':
    os.makedirs(TEX, exist_ok=True)
    bpy.ops.wm.open_mainfile(filepath=os.path.join(HERE, 'jeton.blend'))
    bpy.ops.preferences.addon_enable(module='io_scene_gltf2')
    sc = bpy.context.scene
    render.cycles(sc, 256, 8)
    sc.cycles.use_denoising = False
    sc.render.bake.use_selected_to_active = False
    t0 = time.time()
    all_paths = {}
    for name in BAKED:
        res = bake_material(name)
        all_paths[name] = save_textures(name, res)
        print(f'CUISSON {name} {time.time() - t0:.0f}s', flush=True)
    for o in list(bpy.data.objects):
        if o.type == 'CAMERA':
            bpy.data.objects.remove(o)
        elif o.type == 'MESH':
            a = o.data.attributes.get('fin')
            if a:
                o.data.attributes.remove(a)
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.data.objects if o.type == 'MESH')
    print('TRIANGLES', tris)
    # ---- glTF binaire : Blender convertit lui-même vers Y en haut, le nœud Jeton reste à l'identité
    set_materials(all_paths, orm=True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, 'jeton.glb'), export_format='GLB', export_yup=True,
                              export_image_format='AUTO', export_tangents=False, export_cameras=False,
                              export_lights=False, export_apply=False, export_animations=False)
    # ---- USDZ : on met les données dans le repère final (Y en haut, recto vers +Z) sous un nœud Axes
    set_materials(all_paths, orm=False)
    R = Matrix.Rotation(math.radians(-90), 4, 'X')
    jeton = bpy.data.objects['Jeton']
    for o in bpy.data.objects:
        if o.type == 'MESH':
            o.data.transform(R)
            o.location = R @ o.location
    axes = bpy.data.objects.new('Axes', None)
    sc.collection.objects.link(axes)
    axes.rotation_euler = (math.radians(90), 0, 0)
    jeton.parent = axes
    bpy.context.view_layer.update()
    kw = dict(filepath=os.path.join(OUT, 'jeton.usdz'), export_animation=False, export_materials=True,
              generate_preview_surface=True, export_textures_mode='NEW', overwrite_textures=True,
              convert_orientation=True, export_global_forward_selection='NEGATIVE_Z', export_global_up_selection='Y',
              export_lights=False, export_cameras=False, convert_world_material=False, export_normals=True,
              export_uvmaps=True, rename_uvmaps=True, export_mesh_colors=False, root_prim_path='/root',
              triangulate_meshes=True, export_custom_properties=False)
    bpy.ops.wm.usd_export(**kw)
    kw['filepath'] = os.path.join(OUT, '_tmp', 'jeton.usda')
    bpy.ops.wm.usd_export(**kw)
    print('EXPORT ok')
