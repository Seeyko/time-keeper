"""Studio equirectangulaire procédural : env.exr (HDR, pour Cycles et SceneKit) et export/env.png (LDR).
Le centre de l'image est la direction « du jeton vers la caméra ». Haut de l'image = zénith."""
import os, sys
import numpy as np
import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
W, H = 2048, 1024


def srgb(hexstr):
    h = hexstr.lstrip('#')
    c = np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def norm(v):
    v = np.asarray(v, float)
    return v / np.linalg.norm(v)


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def directions():
    u = (np.arange(W) + 0.5) / W
    v = (np.arange(H) + 0.5) / H
    a = (u - 0.5) * 2 * np.pi
    lat = (v - 0.5) * np.pi
    A, L = np.meshgrid(a, lat)
    return np.stack([-np.cos(L) * np.sin(A), -np.cos(L) * np.cos(A), np.sin(L)], -1)


def softbox(D, center, wx, wy, color, power, soft=0.18, roll=0.0, grad=(0.0, 0.0), core=0.0):
    c = norm(center)
    up = np.array([0, 0, 1.0])
    if abs(c[2]) > 0.97:
        up = np.array([0, 1.0, 0])
    ex = norm(np.cross(up, c))
    ey = np.cross(c, ex)
    if roll:
        cr, sr = np.cos(roll), np.sin(roll)
        ex, ey = cr * ex + sr * ey, -sr * ex + cr * ey
    d = D @ c
    ok = d > 0.05
    dd = np.where(ok, d, 1.0)
    x = (D @ ex) / dd / wx
    y = (D @ ey) / dd / wy
    m = (1 - smooth(1 - soft, 1 + soft, np.abs(x))) * (1 - smooth(1 - soft, 1 + soft, np.abs(y))) * ok
    g = 1 + grad[0] * np.clip(x, -1.2, 1.2) + grad[1] * np.clip(y, -1.2, 1.2)
    if core:
        g = g * (1 + core * np.exp(-(x * x + y * y) * 2.5))
    return (m * np.clip(g, 0, None))[..., None] * (np.asarray(color) * power)


def build():
    D = directions()
    z = D[..., 2]
    top = srgb('#1B2742') * 0.55
    hor = srgb('#0B1530') * 1.0
    bot = srgb('#060A18') * 0.8
    t = smooth(-0.1, 1.0, z)[..., None]
    b = smooth(0.1, -1.0, z)[..., None]
    img = hor * (1 - t) * (1 - b) + top * t + bot * b
    img = img + (np.exp(-(z / 0.10) ** 2) * 0.05)[..., None] * srgb('#5870B8')

    white = np.array([1.0, 0.98, 0.95])
    cool = srgb('#DCE8FF')
    blue = srgb('#4F7CFF')
    warm = srgb('#FFC98A')
    ocre = srgb('#FFA648')

    # clé : grande boîte à lumière, haut gauche, côté caméra
    img += softbox(D, (-0.62, -0.62, 0.62), 0.40, 0.30, white, 13.0, soft=0.22, roll=0.35, grad=(0.25, 0.2), core=0.6)
    # plafond : grand panneau doux
    img += softbox(D, (0.10, -0.30, 1.0), 0.60, 0.34, cool, 4.2, soft=0.35, grad=(0.0, -0.35))
    # carte dégradée derrière la caméra : c'est elle que les faces planes regardent
    img += softbox(D, (0.0, -1.0, 0.36), 0.55, 0.28, cool, 0.55, soft=0.85, grad=(0.3, 0.6))
    # bandeau droit, froid et fin
    img += softbox(D, (0.93, -0.36, 0.12), 0.07, 0.85, cool, 16.0, soft=0.25)
    img += softbox(D, (0.80, -0.60, 0.02), 0.05, 0.6, white, 9.0, soft=0.3)
    # bandeau gauche, chaud : avec le droit, il allume les deux pans des parenthèses vues de face
    img += softbox(D, (-0.79, -0.61, -0.02), 0.06, 0.5, np.array([1.0, 0.93, 0.82]), 9.0, soft=0.3)
    # accent chaud bas droite
    img += softbox(D, (0.50, -0.70, -0.52), 0.30, 0.12, ocre, 5.0, soft=0.4, roll=-0.3)
    # accent chaud bas gauche, plus petit
    img += softbox(D, (-0.75, -0.45, -0.45), 0.10, 0.22, warm, 4.0, soft=0.4, roll=0.5)
    # contre-jour bleu, arrière gauche et arrière droit
    img += softbox(D, (-0.85, 0.48, 0.18), 0.08, 0.8, blue, 12.0, soft=0.3)
    img += softbox(D, (0.70, 0.70, 0.30), 0.22, 0.5, blue, 3.0, soft=0.5)
    # arrière : une boîte neutre et un liseré chaud, pour qu'aucune orientation ne soit morte
    img += softbox(D, (0.25, 1.0, 0.45), 0.5, 0.3, white, 5.0, soft=0.3, grad=(0.3, 0.2))
    img += softbox(D, (-0.35, 0.9, -0.40), 0.35, 0.08, ocre, 3.0, soft=0.4)
    # sol : reflet sombre et bleu nuit
    img += softbox(D, (0.0, -0.2, -1.0), 0.9, 0.9, srgb('#1F3A8A'), 0.10, soft=0.6)
    return img.astype(np.float32)


def save(img):
    rgba = np.concatenate([img, np.ones((H, W, 1), np.float32)], -1)
    im = bpy.data.images.new('env', W, H, alpha=False, float_buffer=True)
    im.pixels.foreach_set(rgba.ravel())
    im.file_format = 'OPEN_EXR'
    im.filepath_raw = os.path.join(HERE, 'env.exr')
    im.save()
    from PIL import Image
    x = img[::-1]
    # compression douce : les boîtes à lumière saturent à 1, les ombres sont relevées
    ldr = 1 - np.exp(-x * 0.55)
    ldr = np.clip(ldr, 0, 1) ** (1 / 2.2)
    os.makedirs(os.path.join(HERE, 'export'), exist_ok=True)
    Image.fromarray((ldr * 255 + 0.5).astype(np.uint8)).save(os.path.join(HERE, 'export', 'env.png'), optimize=True)
    bpy.data.images.remove(im)


if __name__ == '__main__':
    save(build())
    print('env ok')
