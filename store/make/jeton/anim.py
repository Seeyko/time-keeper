"""Animation héro : python3 anim.py [--px 1080] [--spp 16] [--frames a b] [--step n] [--out dossier] [--encode]
Écrit des PNG transparents puis les compose sur le fond nuit avec ffmpeg -> ouverture.mp4"""
import os, sys, math, time, subprocess
import bpy
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build, render

FPS = 30
DUR = 7.0
NF = int(FPS * DUR)

T_OPEN = (1.35, 2.15)      # les parenthèses s'écartent
T_ANTI = (1.50, 2.10)      # recul avant l'élan
T_SPIN = (2.10, 4.35)      # le sas : rotation qui accélère
T_LAND = 4.35              # rebond amorti côté verso
T_FILL = (4.30, 5.60)      # le filet se remplit
T_SWEEP = (4.75, 6.05)     # l'éclat de lumière
TURNS_DEG = 900.0          # 2 tours et demi : on finit sur le verso
ANTI_DEG = -16.0


def smooth(t, a, b):
    x = min(1.0, max(0.0, (t - a) / (b - a)))
    return x * x * (3 - 2 * x)


def ease_out_back(x, s=1.9):
    x = min(1.0, max(0.0, x))
    return 1 + (s + 1) * (x - 1) ** 3 + s * (x - 1) ** 2


def ease_out_cubic(x):
    x = min(1.0, max(0.0, x))
    return 1 - (1 - x) ** 3


def yaw_table(dt=1 / 600.0):
    """Intègre un profil de vitesse : accélération longue, freinage court, puis ressort amorti."""
    a, b = T_SPIN
    peak = a + (b - a) * 0.74
    n = int(DUR / dt) + 2
    v = [0.0] * n
    for i in range(n):
        t = i * dt
        if a <= t < peak:
            x = (t - a) / (peak - a)
            v[i] = x ** 1.7
        elif peak <= t < b:
            x = (t - peak) / (b - peak)
            v[i] = 1 - 0.80 * (x * x * (3 - 2 * x))
    total = sum(v) * dt
    k = (TURNS_DEG - ANTI_DEG) / total
    v0 = v[int(b / dt) - 1] * k
    w, z = 10.5, 0.30
    wd = w * math.sqrt(1 - z * z)
    tab, acc = [], 0.0
    for i in range(n):
        t = i * dt
        acc += v[i] * k * dt
        ph = ANTI_DEG * smooth(t, *T_ANTI) + acc
        if t >= b:
            tau = t - b
            ph = TURNS_DEG + math.exp(-z * w * tau) * (v0 / wd) * math.sin(wd * tau)
        tab.append(ph)
    return tab, dt


def setup(sc):
    j = bpy.data.objects['Jeton']
    pl, pr = bpy.data.objects['ParenL'], bpy.data.objects['ParenR']
    cam = sc.camera
    sc.render.fps = FPS
    sc.frame_start, sc.frame_end = 1, NF
    cam.data.lens = 180
    # Index2 : sa propre matière, il s'éteint quand la parenthèse est consommée
    m2 = bpy.data.materials['Email'].copy()
    m2.name = 'Email2'
    bpy.data.objects['Index2'].data.materials[0] = m2
    em2 = m2.node_tree.nodes['emission'].outputs[0]
    hs2 = [n for n in m2.node_tree.nodes if n.bl_idname == 'ShaderNodeHueSaturation'][0].inputs['Value']
    prog = bpy.data.materials['LaitonFilet'].node_tree.nodes['progress'].outputs[0]
    glow = bpy.data.materials['LaitonFilet'].node_tree.nodes['glow'].outputs[0]
    # l'éclat : une longue boîte étroite qui traverse devant le jeton, invisible à la caméra
    ld = bpy.data.lights.new('Eclat', 'AREA')
    ld.shape = 'RECTANGLE'
    ld.size, ld.size_y = 0.10, 3.2
    ld.color = (1.0, 0.95, 0.86)
    lo = bpy.data.objects.new('Eclat', ld)
    sc.collection.objects.link(lo)
    lo.visible_camera = False
    lo.rotation_euler = (math.radians(90), math.radians(-18), 0)
    tab, dt = yaw_table()
    px0, px1 = pl.location.x, pr.location.x
    for f in range(0, NF + 2):
        t = (f - 1) / FPS
        sc.frame_set(f)
        calm = 1 - 0.75 * smooth(t, 2.0, 3.0) + 0.45 * smooth(t, 5.0, 6.2)
        yaw = tab[min(len(tab) - 1, int(max(0, t) / dt))] + 5.0 * calm * math.sin(2 * math.pi * t / 3.7)
        spin = smooth(t, 2.3, 3.4) * (1 - smooth(t, 4.2, 5.0))
        tilt = -4.0 + 3.5 * calm * math.sin(2 * math.pi * t / 4.3 + 0.7) - 9.0 * spin * math.sin(2 * math.pi * (t - 2.3) / 2.6)
        # à l'atterrissage : le jeton avance vers la caméra puis revient, en ressort
        tau = t - T_LAND
        pop = 0.0
        if tau > 0:
            pop = math.exp(-3.4 * tau) * math.sin(9.0 * tau) * 0.9
        lift = 0.05 * smooth(t, 2.0, 3.6) * (1 - smooth(t, 4.0, 4.6))
        j.rotation_euler = (math.radians(tilt), 0, math.radians(yaw))
        j.location = (0, -0.55 * pop - 0.25 * lift * 4, 0.014 * math.sin(2 * math.pi * t / 3.1) + lift)
        s = 1 + 0.02 * pop
        j.scale = (s, s, s)
        j.keyframe_insert('rotation_euler')
        j.keyframe_insert('location')
        j.keyframe_insert('scale')
        o = ease_out_back((t - T_OPEN[0]) / (T_OPEN[1] - T_OPEN[0])) if t > T_OPEN[0] else 0.0
        pl.location.x = px0 - build.PAREN_OPEN * o
        pr.location.x = px1 + build.PAREN_OPEN * o
        pl.keyframe_insert('location')
        pr.keyframe_insert('location')
        off = smooth(t, T_OPEN[0] + 0.15, T_OPEN[0] + 0.75)
        em2.default_value = build.PBR['Email']['emission'] * (1 - off)
        hs2.default_value = 1 - 0.88 * off
        em2.keyframe_insert('default_value')
        hs2.keyframe_insert('default_value')
        fill = ease_out_cubic((t - T_FILL[0]) / (T_FILL[1] - T_FILL[0])) if t > T_FILL[0] else 0.0
        prog.default_value = fill * 1.001
        glow.default_value = 0.12 + 1.3 * smooth(t, T_FILL[0], T_FILL[0] + 0.5) * (1 - smooth(t, T_FILL[1] - 0.2, T_FILL[1] + 0.9))
        prog.keyframe_insert('default_value')
        glow.keyframe_insert('default_value')
        x = (t - T_SWEEP[0]) / (T_SWEEP[1] - T_SWEEP[0])
        xe = min(1, max(0, x))
        xe = xe * xe * (3 - 2 * xe)
        lo.location = (-2.3 + 4.6 * xe, -1.6, 0.25)
        ld.energy = 26.0 * math.sin(math.pi * min(1, max(0, x))) ** 1.5
        lo.keyframe_insert('location')
        ld.keyframe_insert('energy')
        cam.location = (0, -8.0 + 0.5 * smooth(t, 0.0, DUR), 0)
        cam.keyframe_insert('location')
    for o in list(bpy.data.objects) + list(bpy.data.materials) + list(bpy.data.lights):
        ad = o.animation_data if not isinstance(o, bpy.types.Material) else o.node_tree.animation_data
        if not ad or not ad.action:
            continue
        try:
            for fc in ad.action.fcurves:
                for kp in fc.keyframe_points:
                    kp.interpolation = 'LINEAR'
        except Exception:
            pass


def background(px, path):
    from PIL import Image, ImageFilter, ImageDraw
    bg = Image.new('RGB', (px, px), render.NUIT)
    glow = Image.new('L', (px, px), 0)
    ImageDraw.Draw(glow).ellipse((px * 0.14, px * 0.14, px * 0.86, px * 0.86), fill=78)
    glow = glow.filter(ImageFilter.GaussianBlur(px * 0.12))
    bg = Image.composite(Image.new('RGB', (px, px), (0x1F, 0x3A, 0x8A)), bg, glow)
    bg.save(path)


if __name__ == '__main__':
    def arg(k, d):
        return type(d)(sys.argv[sys.argv.index(k) + 1]) if k in sys.argv else d
    px, spp, step = arg('--px', 1080), arg('--spp', 16), arg('--step', 1)
    out = arg('--out', os.path.join(HERE, 'frames'))
    fa, fb = 1, NF
    if '--frames' in sys.argv:
        i = sys.argv.index('--frames')
        fa, fb = int(sys.argv[i + 1]), int(sys.argv[i + 2])
    os.makedirs(out, exist_ok=True)
    if '--encode' not in sys.argv or '--render' in sys.argv:
        bpy.ops.wm.open_mainfile(filepath=os.path.join(HERE, 'jeton.blend'))
        sc = bpy.context.scene
        render.cycles(sc, px, spp)
        sc.cycles.adaptive_threshold = 0.05
        sc.render.use_persistent_data = True
        sc.render.use_motion_blur = '--noblur' not in sys.argv
        sc.render.motion_blur_shutter = 0.45
        sc.render.image_settings.compression = 15
        setup(sc)
        if '--save' in sys.argv:
            bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, 'ouverture.blend'))
        t0 = time.time()
        tab, dt = yaw_table()
        for f in range(fa, fb + 1, step):
            p = os.path.join(out, f'{f:04d}.png')
            if os.path.exists(p):
                continue
            # le flou de mouvement coûte cher : seulement quand le jeton tourne vite
            t = (f - 1) / FPS
            i = int(t / dt)
            speed = abs(tab[min(len(tab) - 1, i + 20)] - tab[min(len(tab) - 1, i)]) / (20 * dt) / FPS
            sc.render.use_motion_blur = speed > 8.0 and '--noblur' not in sys.argv
            if f >= 60:
                sc.cycles.samples = 8 if sc.render.use_motion_blur else 10
            sc.frame_set(f)
            sc.render.filepath = p
            bpy.ops.render.render(write_still=True)
            print(f'IMAGE {f} {time.time() - t0:.0f}s', flush=True)
    if '--encode' in sys.argv:
        bgp = os.path.join(out, 'fond.png')
        background(px, bgp)
        cmd = ['ffmpeg', '-y', '-loglevel', 'error', '-loop', '1', '-framerate', str(FPS), '-i', bgp,
               '-framerate', str(FPS), '-start_number', '1', '-i', os.path.join(out, '%04d.png'),
               '-filter_complex', '[0][1]overlay=shortest=1:format=auto,scale=1080:1080:flags=lanczos,format=yuv420p',
               '-c:v', 'libx264', '-crf', '15', '-preset', 'slow', '-movflags', '+faststart',
               os.path.join(HERE, 'ouverture.mp4')]
        subprocess.check_call(cmd)
        print('ouverture.mp4 ok')
