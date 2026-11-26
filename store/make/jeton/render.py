"""Rendus Cycles : python3 render.py recto verso trois-quarts vide macro [--px 1600] [--spp 96]"""
import os, sys, math, time
import bpy
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build

NUIT = (0x0B, 0x15, 0x30)


def cycles(sc, px, spp):
    r = sc.render
    r.engine = 'CYCLES'
    r.resolution_x = r.resolution_y = px
    r.resolution_percentage = 100
    r.film_transparent = True
    r.image_settings.file_format = 'PNG'
    r.image_settings.color_mode = 'RGBA'
    r.threads_mode = 'AUTO'
    c = sc.cycles
    c.device = 'CPU'
    c.samples = spp
    c.use_adaptive_sampling = True
    c.adaptive_threshold = 0.02
    c.use_denoising = True
    c.denoiser = 'OPENIMAGEDENOISE'
    c.max_bounces = 10
    c.glossy_bounces = 6
    c.transparent_max_bounces = 8
    c.transmission_bounces = 4
    c.diffuse_bounces = 2
    c.caustics_reflective = False
    c.caustics_refractive = False
    c.sample_clamp_indirect = 6.0
    c.filter_width = 1.4
    try:
        sc.view_settings.view_transform = 'AgX'
        sc.view_settings.look = 'AgX - Medium High Contrast'
    except Exception as e:
        print('look', e)
    sc.view_settings.exposure = 0.0


def set_vide(on):
    for m in bpy.data.materials:
        if not m.node_tree:
            continue
        for n in m.node_tree.nodes:
            if n.bl_idname == 'ShaderNodeHueSaturation':
                n.inputs['Saturation'].default_value = 0.05 if on else 1.0
                n.inputs['Value'].default_value = 0.72 if on else 1.0
            if n.name == 'emission':
                n.outputs[0].default_value = 0.0 if on else build.PBR['Email']['emission']
    if on:
        e = bpy.data.materials['Email'].node_tree.nodes['bsdf']
        for n in bpy.data.materials['Email'].node_tree.nodes:
            if n.bl_idname == 'ShaderNodeHueSaturation':
                n.inputs['Value'].default_value = 0.10


def shot(name):
    sc = bpy.context.scene
    j = bpy.data.objects['Jeton']
    cam = sc.camera
    j.rotation_euler = (0, 0, 0)
    j.location = (0, 0, 0)
    cam.location = (0, -8, 0)
    cam.rotation_euler = (math.pi / 2, 0, 0)
    cam.data.lens = 190
    cam.data.dof.use_dof = False
    set_vide(False)
    sc.world.node_tree.nodes['rot'].inputs['Rotation'].default_value[2] = math.radians(-90)
    if name == 'verso':
        j.rotation_euler = (0, 0, math.pi)
    elif name == 'trois-quarts':
        j.rotation_euler = (math.radians(-16), 0, math.radians(-38))
        cam.data.lens = 175
    elif name == 'vide':
        set_vide(True)
    elif name == 'macro':
        j.rotation_euler = (math.radians(-56), 0, math.radians(-25))
        sc.world.node_tree.nodes['rot'].inputs['Rotation'].default_value[2] = math.radians(-90 + 95)
        cam.data.lens = 100
        cam.location = (0.03, -1.45, 0.02)
        cam.data.dof.use_dof = True
        cam.data.dof.focus_object = bpy.data.objects['ParenR']
        cam.data.dof.aperture_fstop = 1.6
        sc.render.resolution_y = int(sc.render.resolution_x * 2 / 3)
    if name != 'macro':
        sc.render.resolution_y = sc.render.resolution_x


def nuit(path):
    from PIL import Image, ImageFilter, ImageDraw
    im = Image.open(path).convert('RGBA')
    w, h = im.size
    bg = Image.new('RGB', (w, h), NUIT)
    glow = Image.new('L', (w, h), 0)
    d = ImageDraw.Draw(glow)
    d.ellipse((w * 0.12, h * 0.12, w * 0.88, h * 0.88), fill=70)
    glow = glow.filter(ImageFilter.GaussianBlur(w * 0.11))
    bg = Image.composite(Image.new('RGB', (w, h), (0x1F, 0x3A, 0x8A)), bg, glow)
    sh = im.split()[3].filter(ImageFilter.GaussianBlur(w * 0.02)).point(lambda v: int(v * 0.55))
    bg = Image.composite(Image.new('RGB', (w, h), (3, 6, 16)), bg, sh)
    bg.paste(im, (0, 0), im)
    bg.save(path.replace('.png', '-nuit.png'))


if __name__ == '__main__':
    names = ('recto', 'verso', 'trois-quarts', 'vide', 'macro')
    args = [a for a in sys.argv[1:] if a in names]
    px = int(sys.argv[sys.argv.index('--px') + 1]) if '--px' in sys.argv else 1600
    spp = int(sys.argv[sys.argv.index('--spp') + 1]) if '--spp' in sys.argv else 96
    out = sys.argv[sys.argv.index('--out') + 1] if '--out' in sys.argv else HERE
    bpy.ops.wm.open_mainfile(filepath=os.path.join(HERE, 'jeton.blend'))
    sc = bpy.context.scene
    cycles(sc, px, spp)
    for name in args:
        shot(name)
        t = time.time()
        sc.render.filepath = os.path.join(out, name + '.png')
        if name == 'macro':
            sc.cycles.samples = max(16, int(spp * 0.6))
            sc.cycles.adaptive_threshold = 0.04
        bpy.ops.render.render(write_still=True)
        if name == 'vide':
            from PIL import Image, ImageEnhance
            im = Image.open(sc.render.filepath).convert('RGBA')
            al = im.split()[3]
            g = ImageEnhance.Color(im.convert('RGB')).enhance(0.16)
            g.putalpha(al)
            g.save(sc.render.filepath)
        nuit(sc.render.filepath)
        print(f'RENDU {name} {time.time() - t:.1f}s')
