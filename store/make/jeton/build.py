"""Reconstruit jeton.blend de zéro : python3 build.py
Repère de modélisation « disque » : x à droite, y vers midi, z vers le spectateur (recto).
Converti en Blender par (x, y, z) -> (x, -z, y) : le recto regarde -Y, midi est en +Z.
Après export glTF/USD (Y en haut) on retrouve exactement le repère disque."""
import os, math
import sys
import numpy as np
import bpy
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

HERE = os.path.dirname(os.path.abspath(__file__))
TAU = 2 * math.pi
NSEG = 240
N_GUILLOCHE = 84
GUILLOCHE_H = 0.25
SNAIL_ROT = float(os.environ.get('SNAIL_ROT', -0.125))
INDEX_ANGLE = math.radians(12)
INDEX_R = 0.4545
PAREN_GAP = 0.056
PAREN_OPEN = 0.036


def srgb(hexstr):
    h = hexstr.lstrip('#')
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return tuple(out)


BLEU = srgb('#1F3A8A')
CREME = srgb('#F7EBDB')
NUIT = srgb('#0B1530')

# valeurs PBR de référence (aussi écrites dans les matières exportées)
PBR = {
    'Laiton': dict(color=srgb('#D8A446'), metallic=1.0, roughness=0.14),
    'LaitonFilet': dict(color=srgb('#E2B45A'), metallic=1.0, roughness=0.16),
    'LaitonPoli': dict(color=srgb('#D8A446'), metallic=1.0, roughness=0.16),
    'AcierGuilloche': dict(color=srgb('#2C4A9E'), metallic=1.0, roughness=0.17),
    'AcierBrosse': dict(color=srgb('#2A479A'), metallic=1.0, roughness=0.34),
    'AcierPoli': dict(color=srgb('#2C4A9E'), metallic=1.0, roughness=0.10),
    'Email': dict(color=CREME, metallic=0.0, roughness=0.14, emission=0.55),
    'Verre': dict(color=(0.0, 0.0, 0.0), metallic=0.0, roughness=0.02, alpha=0.06),
}


# ---------------------------------------------------------------- géométrie
class MB:
    def __init__(self):
        self.v, self.f, self.uv, self.fin, self.smooth = [], [], [], [], []

    def vert(self, x, y, z):
        self.v.append((x, -z, y))
        return len(self.v) - 1

    def face(self, idx, uvs, fin=0.0, smooth=True):
        self.f.append(tuple(idx))
        self.uv.extend(uvs)
        self.fin.extend([fin] * len(idx))
        self.smooth.append(smooth)

    def object(self, name, mat, parent=None, origin=(0, 0, 0)):
        me = bpy.data.meshes.new(name)
        ox, oy, oz = origin
        o_b = (ox, -oz, oy)
        verts = [(x - o_b[0], y - o_b[1], z - o_b[2]) for x, y, z in self.v]
        me.from_pydata(verts, [], self.f)
        uvl = me.uv_layers.new(name='UVMap')
        uvl.data.foreach_set('uv', [c for uv in self.uv for c in uv])
        att = me.attributes.new('fin', 'FLOAT', 'CORNER')
        att.data.foreach_set('value', self.fin)
        me.polygons.foreach_set('use_smooth', self.smooth)
        me.materials.append(mat)
        me.update()
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        ob.location = o_b
        if parent:
            ob.parent = parent
        return ob


def revolve(mb, groups, nseg=NSEG, rect=None, planar=None, center=(0, 0), ustart=0.0):
    """groups : liste de (fin, [(r, z), ...]). Polylignes parcourues dans le sens trigo du demi-plan (r, z).
    rect = (u0, v0, u1, v1) : dépliage en bande. planar = (échelle, cu, cv, signe_x) : projection à plat."""
    cx, cy = center
    total = 0.0
    for _, pts in groups:
        for a, b in zip(pts, pts[1:]):
            total += math.hypot(b[0] - a[0], b[1] - a[1])
    acc = 0.0

    def uv_of(r, z, j, s):
        if planar:
            sc, cu, cv, sx = planar
            th = TAU * j / nseg
            return (cu + sx * r * math.cos(th) * sc, cv + r * math.sin(th) * sc)
        u0, v0, u1, v1 = rect
        return (u0 + (u1 - u0) * (j / nseg + ustart), v0 + (v1 - v0) * (s / total if total else 0))

    for fin, pts in groups:
        rings, ss = [], []
        for k, (r, z) in enumerate(pts):
            if k:
                acc += math.hypot(r - pts[k - 1][0], z - pts[k - 1][1])
            ss.append(acc)
            if r < 1e-9:
                rings.append([mb.vert(cx, cy, z)])
            else:
                rings.append([mb.vert(cx + r * math.cos(TAU * j / nseg), cy + r * math.sin(TAU * j / nseg), z)
                              for j in range(nseg)])
        for k in range(len(pts) - 1):
            A, B = rings[k], rings[k + 1]
            (ra, za), (rb, zb) = pts[k], pts[k + 1]
            for j in range(nseg):
                j1 = (j + 1) % nseg
                if len(A) == 1 and len(B) == 1:
                    continue
                if len(A) == 1:
                    mb.face((A[0], B[j1], B[j]),
                            (uv_of(ra, za, j + 0.5, ss[k]), uv_of(rb, zb, j + 1, ss[k + 1]), uv_of(rb, zb, j, ss[k + 1])), fin)
                elif len(B) == 1:
                    mb.face((A[j], A[j1], B[0]),
                            (uv_of(ra, za, j, ss[k]), uv_of(ra, za, j + 1, ss[k]), uv_of(rb, zb, j + 0.5, ss[k + 1])), fin)
                else:
                    mb.face((A[j], A[j1], B[j1], B[j]),
                            (uv_of(ra, za, j, ss[k]), uv_of(ra, za, j + 1, ss[k]),
                             uv_of(rb, zb, j + 1, ss[k + 1]), uv_of(rb, zb, j, ss[k + 1])), fin)


def arc(p0, p1, bulge, n=4):
    """Petit arrondi convexe entre deux points du profil (bulge = flèche, vers l'extérieur du parcours trigo)."""
    (r0, z0), (r1, z1) = p0, p1
    dx, dz = r1 - r0, z1 - z0
    L = math.hypot(dx, dz)
    nx, nz = dz / L, -dx / L
    out = []
    for i in range(n + 1):
        t = i / n
        b = 4 * bulge * t * (1 - t)
        out.append((r0 + dx * t + nx * b, z0 + dz * t + nz * b))
    return out


def carrure(mat, parent):
    mb = MB()
    lower = [(0, [(0.4386, -0.0440), (0.4386, -0.0508)]),
             (0, [(0.4386, -0.0508), (0.4400, -0.0520)]),
             (1, [(0.4400, -0.0520), (0.4820, -0.0520)]),
             (0, arc((0.4820, -0.0520), (0.4985, -0.0330), 0.0016, 5)),
             (0, arc((0.4985, -0.0330), (0.5000, -0.0300), 0.0003, 2))]
    upper = [(0, arc((0.5000, 0.0300), (0.4985, 0.0330), 0.0003, 2)),
             (0, arc((0.4985, 0.0330), (0.4890, 0.0450), 0.0012, 4))]
    revolve(mb, lower, rect=(0, 0.005, 1, 0.150))
    revolve(mb, upper, rect=(0, 0.155, 1, 0.220))
    # tranche cannelée : 120 cannelures, 6 segments chacune
    nfl, per = 120, 6
    n = nfl * per
    depth = 0.0052
    zs = [-0.0300, -0.0272, 0.0272, 0.0300]
    rows = []
    for zi, z in enumerate(zs):
        row = []
        for j in range(n):
            th = TAU * j / n
            if zi in (0, 3):
                r = 0.5
            else:
                c = 0.5 - 0.5 * math.cos(TAU * (j % per) / per)
                r = 0.5 - depth * (c ** 0.8)
            row.append(mb.vert(r * math.cos(th), r * math.sin(th), z))
        rows.append(row)
    v0, v1 = 0.230, 0.400
    vs = [v0, v0 + 0.02, v1 - 0.02, v1]
    for k in range(3):
        for j in range(n):
            j1 = (j + 1) % n
            mb.face((rows[k][j], rows[k][j1], rows[k + 1][j1], rows[k + 1][j]),
                    ((j / n, vs[k]), ((j + 1) / n, vs[k]), ((j + 1) / n, vs[k + 1]), (j / n, vs[k + 1])), 0)
    return mb.object('Carrure', mat, parent)


def chaton_groups(z0):
    return [(0, [(0.0238, z0 - 0.004), (0.0238, z0 + 0.0022)]),
            (0, arc((0.0238, z0 + 0.0022), (0.0192, z0 + 0.0034), 0.0007, 3)),
            (0, [(0.0192, z0 + 0.0034), (0.0184, z0 + 0.0010)])]


def index_centers():
    return [(INDEX_R * math.sin(s * INDEX_ANGLE), INDEX_R * math.cos(s * INDEX_ANGLE)) for s in (-1, 1)]


def lunette(mat, parent):
    mb = MB()
    groups = [(0, arc((0.4890, 0.0450), (0.4822, 0.0522), 0.0012, 4)),
              (0, [(0.4822, 0.0522), (0.4806, 0.0508)]),
              (0, [(0.4806, 0.0508), (0.4790, 0.0524)]),
              (1, arc((0.4790, 0.0524), (0.4290, 0.0540), 0.0016, 6)),
              (0, arc((0.4290, 0.0540), (0.4140, 0.0497), 0.0006, 3)),
              (0, [(0.4140, 0.0497), (0.4112, 0.0478)]),
              (0, [(0.4112, 0.0478), (0.4112, 0.0170)])]
    revolve(mb, groups, rect=(0, 0.410, 1, 0.660))
    for i, c in enumerate(index_centers()):
        revolve(mb, chaton_groups(0.0548), nseg=40, rect=(0.5 * i, 0.765, 0.5 * i + 0.5, 0.800), center=c)
    return mb.object('Lunette', mat, parent)


def index(name, i, mat, parent):
    mb = MB()
    c = index_centers()[i]
    R, z0, hgt = 0.0186, 0.0556, 0.0100
    pts = []
    for k in range(7):
        a = (math.pi / 2) * k / 6
        pts.append((R * math.cos(a), z0 + hgt * math.sin(a)))
    pts[-1] = (0.0, z0 + hgt)
    revolve(mb, [(0, pts)], nseg=28, planar=(18.0, 0.5, 0.5, 1), center=c)
    return mb.object(name, mat, parent, origin=(c[0], c[1], z0))


def cuvette(mat, parent):
    """Guillochage en rosace entrelacée : deux familles de spirales logarithmiques à 45°,
    chaque maille est un clou de Paris (pyramide à 4 facettes) dont la taille croît avec le rayon."""
    mb = MB()
    N = N_GUILLOCHE
    z0 = 0.0200
    r_in, r_out = 0.1675, 0.4118
    sc = 1 / 0.86
    step = math.pi / N

    def pt(s_, d_):
        r = math.exp(step * d_)
        return (r * math.cos(step * s_), r * math.sin(step * s_), z0)

    def uvp(p):
        return (0.5 + p[0] * sc, 0.5 + p[1] * sc)

    dmin = int(math.floor(math.log(r_in) / step)) - 2
    dmax = int(math.ceil(math.log(r_out) / step)) + 2
    for d in range(dmin, dmax + 1):
        rc = math.exp(step * d)
        if rc * math.exp(step) < r_in or rc * math.exp(-step) > r_out:
            continue
        edge = rc * step * math.sqrt(2)
        for s_ in range(2 * N):
            if (s_ + d) % 2 == 0:
                continue
            cs = [pt(s_ - 1, d), pt(s_, d + 1), pt(s_ + 1, d), pt(s_, d - 1)]
            apex = (rc * math.cos(step * s_), rc * math.sin(step * s_), z0 + GUILLOCHE_H * edge)
            area = sum(cs[i][0] * cs[(i + 1) % 4][1] - cs[(i + 1) % 4][0] * cs[i][1] for i in range(4))
            if area < 0:
                cs = cs[::-1]
            for i in range(4):
                a, b = cs[i], cs[(i + 1) % 4]
                ia, ib, ic = mb.vert(*a), mb.vert(*b), mb.vert(*apex)
                mb.face((ia, ib, ic), (uvp(a), uvp(b), uvp(apex)), 1.0, smooth=False)
    return mb.object('Cuvette', mat, parent)


def medaillon(mat_laiton, mat_acier, parent):
    mb = MB()
    groups = [(0, [(0.1690, 0.0185), (0.1690, 0.0338)]),
              (0, [(0.1690, 0.0338), (0.1668, 0.0360)]),
              (1, arc((0.1668, 0.0360), (0.1552, 0.0360), 0.0005, 3)),
              (0, [(0.1552, 0.0360), (0.1530, 0.0340)]),
              (0, [(0.1530, 0.0340), (0.1530, 0.0300)])]
    revolve(mb, groups, nseg=160, rect=(0, 0.670, 1, 0.750))
    anneau = mb.object('Medaillon', mat_laiton, parent)
    mb = MB()
    R = 0.1532
    pts = [(R * (1 - k / 8), 0.0300 + 0.0040 * (1 - (1 - k / 8) ** 2)) for k in range(9)]
    pts[-1] = (0.0, 0.0340)
    revolve(mb, [(0, pts)], nseg=96, planar=(1 / 0.86, 0.5, 0.5, 1))
    fond = mb.object('MedaillonFond', mat_acier, parent)
    return anneau, fond


def paren(name, side, mat, parent):
    """Parenthèse en relief, bombée, effilée aux pointes. side = -1 (gauche) ou +1 (droite)."""
    mb = MB()
    Hh, alpha = 0.176, math.radians(31)
    Rp = Hh / (2 * math.sin(alpha))
    wmax, hmax = 0.0330, 0.0074
    zb = 0.0322
    K, M2 = 34, 3
    xm = side * PAREN_GAP
    cx = xm - side * Rp
    rows = []
    u0 = 0.02 if side < 0 else 0.52
    for k in range(K + 1):
        ph = -math.pi / 2 + math.pi * k / K
        t = math.sin(ph)
        a = alpha * t
        tip = max(0.0, 1 - abs(t) ** 14) ** 0.5
        w = wmax * (0.62 + 0.38 * (1 - t * t) ** 0.9) * tip
        h = hmax * (0.55 + 0.45 * (1 - t * t)) * tip ** 0.8
        px = cx + side * Rp * math.cos(a)
        py = Rp * math.sin(a)
        nx, ny = side * math.cos(a), math.sin(a)
        groups = []
        for fin, pts in ((0.0, ((-1.0, None), (-0.985, 0.16), (-0.70, 0.90))),
                         (1.0, ((-0.70, 0.90), (-0.35, 0.972), (0.0, 1.0), (0.35, 0.972), (0.70, 0.90))),
                         (0.0, ((0.70, 0.90), (0.985, 0.16), (1.0, None)))):
            row, ruv = [], []
            for s, zr in pts:
                zz = zb - 0.0015 if zr is None else zb + h * zr
                row.append(mb.vert(px + nx * s * w / 2, py + ny * s * w / 2, zz))
                ruv.append((u0 + 0.46 * (py + Hh / 2 + 0.01) / (Hh + 0.02), 0.870 + 0.12 * (0.5 + 0.47 * s * (w / wmax))))
            groups.append((fin, row, ruv))
        rows.append(groups)
    for k in range(K):
        for gi in range(3):
            fin, ra, ua = rows[k][gi]
            _, rb, ub = rows[k + 1][gi]
            for i in range(len(ra) - 1):
                q = (ra[i], ra[i + 1], rb[i + 1], rb[i])
                u = (ua[i], ua[i + 1], ub[i + 1], ub[i])
                if side < 0:
                    q, u = q[::-1], u[::-1]
                mb.face(q, u, fin)
    return mb.object(name, mat, parent, origin=(xm, 0, zb))


def verre(mat, parent):
    mb = MB()
    R = 0.4110
    pts = [(R, 0.0468), (R, 0.0490)]
    top = [(R * (1 - k / 14), 0.0496 + 0.0098 * (1 - (1 - k / 14) ** 2)) for k in range(15)]
    top[0] = (R - 0.0016, 0.0500)
    top[-1] = (0.0, 0.0594)
    revolve(mb, [(0, pts), (0, [(R, 0.0490), top[0]]), (0, top)], nseg=128, planar=(1 / 0.86, 0.5, 0.5, 1))
    return mb.object('Verre', mat, parent)


def fond(mat, parent):
    mb = MB()
    groups = [(1, [(0.0, -0.0432), (0.030, -0.0432), (0.120, -0.0432), (0.220, -0.0432), (0.3120, -0.0432)]),
              (0, [(0.3120, -0.0432), (0.3165, -0.0470)]),
              (1, [(0.3165, -0.0470), (0.3800, -0.0470), (0.4388, -0.0470)])]
    revolve(mb, groups, nseg=NSEG, planar=(1 / 0.90, 0.5, 0.5, -1))
    return mb.object('Fond', mat, parent)


def minuterie(mat, parent):
    mb = MB()
    zb, zt = -0.0468, -0.0508
    for i in range(60):
        big = (i % 5 == 0)
        r0, r1 = (0.3830, 0.4270) if big else (0.3950, 0.4230)
        w = 0.0100 if big else 0.0052
        ch = 0.0013
        th = TAU * i / 60 + math.pi / 2
        c, s = math.cos(th), math.sin(th)

        def P(r, tt, z):
            return mb.vert(r * c - tt * s, r * s + tt * c, z)
        zt = zb - 0.26 * w
        b = [P(r0, -w / 2, zb), P(r1, -w / 2, zb), P(r1, w / 2, zb), P(r0, w / 2, zb)]
        e = [P(r0 + w * 0.5, 0, zt), P(r1 - w * 0.5, 0, zt)]
        z3, z4 = ((0, 0),) * 3, ((0, 0),) * 4
        mb.face((b[0], e[0], e[1], b[1]), z4, 0, smooth=False)
        mb.face((b[2], e[1], e[0], b[3]), z4, 0, smooth=False)
        mb.face((b[1], e[1], b[2]), z3, 0, smooth=False)
        mb.face((b[3], e[0], b[0]), z3, 0, smooth=False)
    return mb.object('Minuterie', mat, parent)


def filet(mat, parent):
    """Jauge des 5 minutes. u = fraction de tour, sens horaire depuis midi quand on regarde le verso."""
    mb = MB()
    n = 240
    rc, hw, zb, hh = 0.3520, 0.0062, -0.0468, 0.0046
    prof = []
    for k in range(7):
        a = math.pi * k / 6
        prof.append((rc - hw * math.cos(a), zb - hh * math.sin(a) ** 0.8))
    rows = []
    for (r, z) in prof:
        rows.append([mb.vert(r * math.cos(math.pi / 2 + TAU * j / n), r * math.sin(math.pi / 2 + TAU * j / n), z)
                     for j in range(n)])
    for k in range(len(prof) - 1):
        for j in range(n):
            j1 = (j + 1) % n
            mb.face((rows[k][j], rows[k][j1], rows[k + 1][j1], rows[k + 1][j]),
                    ((j / n, k / 6), ((j + 1) / n, k / 6), ((j + 1) / n, (k + 1) / 6), (j / n, (k + 1) / 6)), 0)
    return mb.object('Filet', mat, parent)


def pivot(mat_laiton, mat_acier, parent):
    mb = MB()
    z = -0.0432
    groups = [(0, [(0.0150, z - 0.0030), (0.0200, z - 0.0042)]),
              (0, arc((0.0200, z - 0.0042), (0.0285, z - 0.0030), 0.0006, 3)),
              (0, [(0.0285, z - 0.0030), (0.0300, z + 0.0005)])]
    revolve(mb, groups, nseg=48, rect=(0, 0.810, 0.5, 0.850))
    a = mb.object('Pivot', mat_laiton, parent)
    mb = MB()
    pts = [(0.0, z - 0.0062)] + [(0.0152 * math.sin(math.pi / 2 * k / 5), z - 0.0028 - 0.0034 * math.cos(math.pi / 2 * k / 5))
                                 for k in range(1, 6)]
    revolve(mb, [(0, pts)], nseg=32, planar=(1.0, 0.5, 0.5, -1))
    b = mb.object('PivotCoeur', mat_acier, parent)
    return a, b


# ---------------------------------------------------------------- matières
def new_mat(name):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    out.name = 'out'
    return m, nt, out


def N(nt, kind, name=None, **props):
    n = nt.nodes.new(kind)
    if name:
        n.name = name
        n.label = name
    for k, v in props.items():
        setattr(n, k, v)
    return n


def sock(node, ident, out=False):
    coll = node.outputs if out else node.inputs
    for s in coll:
        if s.identifier == ident:
            return s
    for s in coll:
        if s.name == ident:
            return s
    raise KeyError(ident + ' / ' + node.bl_idname + ' : ' + ', '.join(s.identifier for s in coll))


def L(nt, a, b):
    nt.links.new(a, b)


def val(nt, v, name=None):
    n = N(nt, 'ShaderNodeValue', name)
    n.outputs[0].default_value = v
    return n.outputs[0]


def math_(nt, op, a, b=None, c=None, clamp=False):
    n = N(nt, 'ShaderNodeMath', operation=op, use_clamp=clamp)
    for i, x in enumerate((a, b, c)):
        if x is None:
            continue
        if isinstance(x, (int, float)):
            n.inputs[i].default_value = x
        else:
            L(nt, x, n.inputs[i])
    return n.outputs[0]


def mixc(nt, fac, a, b, blend='MIX'):
    n = N(nt, 'ShaderNodeMix', data_type='RGBA', blend_type=blend)
    for ident, x in (('Factor_Float', fac), ('A_Color', a), ('B_Color', b)):
        s = sock(n, ident)
        if isinstance(x, (int, float)):
            s.default_value = x
        elif isinstance(x, tuple):
            s.default_value = (*x[:3], 1)
        else:
            L(nt, x, s)
    return sock(n, 'Result_Color', True)


def radius_obj(nt):
    """Rayon autour de l'axe du jeton (Y objet Blender) et coordonnées objet."""
    tc = N(nt, 'ShaderNodeTexCoord')
    sep = N(nt, 'ShaderNodeSeparateXYZ')
    L(nt, tc.outputs['Object'], sep.inputs[0])
    r = math_(nt, 'SQRT', math_(nt, 'ADD', math_(nt, 'MULTIPLY', sep.outputs[0], sep.outputs[0]),
                                math_(nt, 'MULTIPLY', sep.outputs[2], sep.outputs[2])))
    return tc, sep, r


def noise(nt, vec=None, scale=5.0, detail=2.0, rough=0.5, dim='3D', w=None):
    n = N(nt, 'ShaderNodeTexNoise', noise_dimensions=dim)
    n.inputs['Scale'].default_value = scale
    n.inputs['Detail'].default_value = detail
    n.inputs['Roughness'].default_value = rough
    if vec is not None:
        L(nt, vec, n.inputs['Vector'])
    if w is not None:
        L(nt, w, n.inputs['W'])
    return n.outputs[0]


def scratches(nt, tc):
    """Micro-rayures : trois bruits très étirés dans trois directions."""
    acc = None
    for i, (rot, sc) in enumerate((((0.3, 0.2, 0.9), 55), ((1.1, 0.5, 2.3), 70), ((0.2, 1.4, 4.0), 90))):
        mp = N(nt, 'ShaderNodeMapping')
        mp.inputs['Rotation'].default_value = rot
        mp.inputs['Scale'].default_value = (sc, sc * 0.012, sc)
        mp.inputs['Location'].default_value = (i * 3.1, i * 1.7, 0)
        L(nt, tc.outputs['Object'], mp.inputs[0])
        nz = noise(nt, mp.outputs[0], 6.0, 3.0, 0.6)
        acc = nz if acc is None else math_(nt, 'ADD', acc, nz)
    return math_(nt, 'MULTIPLY', math_(nt, 'SUBTRACT', acc, 1.5), 0.666)


def desat(nt, color):
    n = N(nt, 'ShaderNodeHueSaturation', 'desat')
    L(nt, color, n.inputs['Color'])
    return n.outputs[0]


def metal(name, base, fin_values, brushed_scale, edge_tint, irise=None, brush_gain=1.0, snail=None):
    """fin_values = (rugosité poli, rugosité brossé, anisotropie brossé)."""
    m, nt, out = new_mat(name)
    p = N(nt, 'ShaderNodeBsdfPrincipled', 'bsdf')
    p.inputs['Metallic'].default_value = 1.0
    tc, sep, r = radius_obj(nt)
    fin = N(nt, 'ShaderNodeAttribute', attribute_name='fin').outputs['Fac']
    # couleur
    big = noise(nt, tc.outputs['Object'], 3.0, 2.0, 0.5)
    col = N(nt, 'ShaderNodeRGB')
    col.outputs[0].default_value = (*base, 1)
    col2 = mixc(nt, math_(nt, 'MULTIPLY', math_(nt, 'SUBTRACT', big, 0.40), 0.9, clamp=True), col.outputs[0], tuple(c * 0.80 for c in base))
    if irise:
        var = noise(nt, tc.outputs['Object'], 1.6, 1.0, 0.5)
        col2 = mixc(nt, math_(nt, 'MULTIPLY', math_(nt, 'SUBTRACT', var, 0.35), 0.5, clamp=True), col2, irise[0])
    bc = desat(nt, col2)
    bake_bc = N(nt, 'NodeReroute', 'bake_bc')
    L(nt, bc, bake_bc.inputs[0])
    shade = bake_bc.outputs[0]
    if irise:
        lw = N(nt, 'ShaderNodeLayerWeight')
        lw.inputs['Blend'].default_value = 0.35
        iri = desat2 = N(nt, 'ShaderNodeHueSaturation', 'desat_b')
        iri.inputs['Color'].default_value = (*irise[1], 1)
        shade = mixc(nt, math_(nt, 'MULTIPLY', lw.outputs['Facing'], 0.85), shade, iri.outputs[0])
    L(nt, shade, p.inputs['Base Color'])
    tint = N(nt, 'ShaderNodeHueSaturation', 'desat_t')
    tint.inputs['Color'].default_value = (*edge_tint, 1)
    L(nt, tint.outputs[0], p.inputs['Specular Tint'])
    # rugosité
    sc = scratches(nt, tc)
    lines = noise(nt, None, brushed_scale, 4.0, 0.75, '1D', w=r)
    lines2 = noise(nt, None, brushed_scale * 0.13, 2.0, 0.6, '1D', w=r)
    tg = N(nt, 'ShaderNodeTangent', direction_type='RADIAL', axis='Y')
    tangent = tg.outputs[0]
    if snail:
        # colimaçon : stries le long de spirales logarithmiques au centre, cercles au bord
        rlim, kk = snail
        th = N(nt, 'ShaderNodeMath', operation='ARCTAN2')
        L(nt, sep.outputs[2], th.inputs[0])
        L(nt, sep.outputs[0], th.inputs[1])
        lnr = math_(nt, 'LOGARITHM', math_(nt, 'MAXIMUM', r, 0.002), math.e)
        q = math_(nt, 'SUBTRACT', th.outputs[0], math_(nt, 'MULTIPLY', lnr, kk))
        acc = None
        for n_, a_, ph in ((144, 0.30, 0.0), (233, 0.30, 1.3), (377, 0.25, 2.1), (521, 0.15, 4.0)):
            t_ = math_(nt, 'MULTIPLY', math_(nt, 'SINE', math_(nt, 'ADD', math_(nt, 'MULTIPLY', q, n_), ph)), a_)
            acc = t_ if acc is None else math_(nt, 'ADD', acc, t_)
        sp = math_(nt, 'ADD', math_(nt, 'MULTIPLY', acc, 0.5), 0.5)
        inside = math_(nt, 'LESS_THAN', r, rlim)
        lines = math_(nt, 'ADD', math_(nt, 'MULTIPLY', sp, inside), math_(nt, 'MULTIPLY', lines, math_(nt, 'SUBTRACT', 1.0, inside)))
        lines2 = math_(nt, 'MULTIPLY', lines2, math_(nt, 'SUBTRACT', 1.0, inside))
        L(nt, math_(nt, 'MULTIPLY', inside, SNAIL_ROT), p.inputs['Anisotropic Rotation'])
    ro_poli = math_(nt, 'ADD', fin_values[0], math_(nt, 'MULTIPLY', math_(nt, 'ABSOLUTE', sc), 0.10))
    ro_bro = math_(nt, 'ADD', fin_values[1], math_(nt, 'MULTIPLY', math_(nt, 'SUBTRACT', lines, 0.5), 0.12))
    ro = math_(nt, 'ADD', math_(nt, 'MULTIPLY', ro_poli, math_(nt, 'SUBTRACT', 1.0, fin)), math_(nt, 'MULTIPLY', ro_bro, fin))
    bake_r = N(nt, 'NodeReroute', 'bake_rough')
    L(nt, ro, bake_r.inputs[0])
    L(nt, bake_r.outputs[0], p.inputs['Roughness'])
    L(nt, math_(nt, 'MULTIPLY', fin, fin_values[2]), p.inputs['Anisotropic'])
    L(nt, tangent, p.inputs['Tangent'])
    # relief fin
    hgt_b = math_(nt, 'ADD', math_(nt, 'MULTIPLY', lines, 1.0), math_(nt, 'MULTIPLY', lines2, 0.6))
    hgt = math_(nt, 'ADD', math_(nt, 'MULTIPLY', math_(nt, 'MULTIPLY', hgt_b, fin), brush_gain),
                math_(nt, 'MULTIPLY', math_(nt, 'MULTIPLY', sc, math_(nt, 'SUBTRACT', 1.0, fin)), 0.35))
    bump = N(nt, 'ShaderNodeBump', 'bump')
    bump.inputs['Strength'].default_value = 0.30
    bump.inputs['Distance'].default_value = 0.0005
    L(nt, hgt, bump.inputs['Height'])
    L(nt, bump.outputs[0], p.inputs['Normal'])
    L(nt, p.outputs[0], out.inputs['Surface'])
    return m


def simple(name, emission=0.0, coat=0.0):
    d = PBR[name]
    m, nt, out = new_mat(name)
    p = N(nt, 'ShaderNodeBsdfPrincipled', 'bsdf')
    col = N(nt, 'ShaderNodeRGB')
    col.outputs[0].default_value = (*d['color'], 1)
    c = desat(nt, col.outputs[0])
    L(nt, c, p.inputs['Base Color'])
    p.inputs['Metallic'].default_value = d['metallic']
    p.inputs['Roughness'].default_value = d['roughness']
    if emission:
        L(nt, c, p.inputs['Emission Color'])
        v = N(nt, 'ShaderNodeValue', 'emission')
        v.outputs[0].default_value = emission
        L(nt, v.outputs[0], p.inputs['Emission Strength'])
    if coat:
        p.inputs['Coat Weight'].default_value = coat
        p.inputs['Coat Roughness'].default_value = 0.03
    L(nt, p.outputs[0], out.inputs['Surface'])
    return m


def mat_filet():
    d = PBR['LaitonFilet']
    m, nt, out = new_mat('LaitonFilet')
    p = N(nt, 'ShaderNodeBsdfPrincipled', 'bsdf')
    p.inputs['Metallic'].default_value = 1.0
    uv = N(nt, 'ShaderNodeUVMap')
    sep = N(nt, 'ShaderNodeSeparateXYZ')
    L(nt, uv.outputs[0], sep.inputs[0])
    prog = N(nt, 'ShaderNodeValue', 'progress')
    prog.outputs[0].default_value = 1.0
    on = math_(nt, 'LESS_THAN', sep.outputs[0], prog.outputs[0])
    col = N(nt, 'ShaderNodeRGB')
    col.outputs[0].default_value = (*d['color'], 1)
    off = N(nt, 'ShaderNodeRGB')
    off.outputs[0].default_value = (*srgb('#16296B'), 1)
    c = desat(nt, mixc(nt, on, off.outputs[0], col.outputs[0]))
    L(nt, c, p.inputs['Base Color'])
    L(nt, math_(nt, 'ADD', 0.30, math_(nt, 'MULTIPLY', on, d['roughness'] - 0.30)), p.inputs['Roughness'])
    L(nt, c, p.inputs['Emission Color'])
    glow = N(nt, 'ShaderNodeValue', 'glow')
    glow.outputs[0].default_value = 0.12
    L(nt, math_(nt, 'MULTIPLY', on, glow.outputs[0]), p.inputs['Emission Strength'])
    L(nt, p.outputs[0], out.inputs['Surface'])
    return m


def mat_verre():
    m, nt, out = new_mat('Verre')
    tr = N(nt, 'ShaderNodeBsdfTransparent')
    gl = N(nt, 'ShaderNodeBsdfGlossy')
    gl.inputs['Roughness'].default_value = 0.0
    gl.inputs['Color'].default_value = (0.78, 0.86, 1.0, 1)
    fr = N(nt, 'ShaderNodeFresnel')
    fr.inputs['IOR'].default_value = 1.77
    k = N(nt, 'ShaderNodeValue', 'reflet')
    k.outputs[0].default_value = 0.30
    mix = N(nt, 'ShaderNodeMixShader')
    L(nt, math_(nt, 'MULTIPLY', fr.outputs[0], k.outputs[0]), mix.inputs[0])
    L(nt, tr.outputs[0], mix.inputs[1])
    L(nt, gl.outputs[0], mix.inputs[2])
    L(nt, mix.outputs[0], out.inputs['Surface'])
    return m


def materials():
    violet = srgb('#4A2FB0')
    mats = {
        'Laiton': metal('Laiton', PBR['Laiton']['color'], (0.085, 0.30, 0.78), 900.0, srgb('#FFF3C9')),
        'AcierGuilloche': metal('AcierGuilloche', PBR['AcierGuilloche']['color'], (0.11, 0.17, 0.0), 700.0,
                                srgb('#B9C8FF'), irise=(srgb('#2A2F9C'), violet), brush_gain=0.2),
        'AcierBrosse': metal('AcierBrosse', PBR['AcierBrosse']['color'], (0.09, 0.34, 0.94), 650.0,
                             srgb('#B9C8FF'), irise=(srgb('#2A2F9C'), violet), brush_gain=1.3, snail=(0.3135, 1.0)),
        'AcierPoli': simple('AcierPoli'),
        'LaitonPoli': simple('LaitonPoli'),
        'Email': simple('Email', emission=PBR['Email']['emission'], coat=1.0),
        'LaitonFilet': mat_filet(),
        'Verre': mat_verre(),
    }
    return mats


# ---------------------------------------------------------------- scène
def world(strength=1.0):
    if not os.path.exists(os.path.join(HERE, 'env.exr')):
        import env as envmod
        envmod.save(envmod.build())
    w = bpy.data.worlds.new('Studio')
    bpy.context.scene.world = w
    w.use_nodes = True
    nt = w.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = N(nt, 'ShaderNodeOutputWorld')
    bg = N(nt, 'ShaderNodeBackground', 'bg')
    bg.inputs['Strength'].default_value = strength
    env = N(nt, 'ShaderNodeTexEnvironment', 'env')
    env.image = bpy.data.images.load(os.path.join(HERE, 'env.exr'))
    tc = N(nt, 'ShaderNodeTexCoord')
    mp = N(nt, 'ShaderNodeMapping', 'rot')
    mp.inputs['Rotation'].default_value = (0, 0, math.radians(-90))
    L(nt, tc.outputs['Generated'], mp.inputs[0])
    L(nt, mp.outputs[0], env.inputs[0])
    L(nt, env.outputs[0], bg.inputs['Color'])
    L(nt, bg.outputs[0], out.inputs['Surface'])
    return w


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    try:
        bpy.ops.preferences.addon_enable(module='cycles')
    except Exception:
        pass
    sc = bpy.context.scene
    sc.unit_settings.system = 'NONE'
    mats = materials()
    jeton = bpy.data.objects.new('Jeton', None)
    jeton.empty_display_size = 0.6
    sc.collection.objects.link(jeton)
    carrure(mats['Laiton'], jeton)
    lunette(mats['Laiton'], jeton)
    cuvette(mats['AcierGuilloche'], jeton)
    medaillon(mats['Laiton'], mats['AcierGuilloche'], jeton)
    paren('ParenL', -1, mats['Laiton'], jeton)
    paren('ParenR', 1, mats['Laiton'], jeton)
    index('Index1', 0, mats['Email'], jeton)
    index('Index2', 1, mats['Email'], jeton)
    verre(mats['Verre'], jeton)
    fond(mats['AcierBrosse'], jeton)
    minuterie(mats['LaitonPoli'], jeton)
    filet(mats['LaitonFilet'], jeton)
    pivot(mats['Laiton'], mats['AcierPoli'], jeton)
    world()
    cam = bpy.data.objects.new('Camera', bpy.data.cameras.new('Camera'))
    sc.collection.objects.link(cam)
    cam.location = (0, -8, 0)
    cam.rotation_euler = (math.pi / 2, 0, 0)
    cam.data.lens = 190
    cam.data.clip_start = 0.1
    sc.camera = cam
    sc.render.engine = 'CYCLES'
    return jeton


def stats():
    tris = 0
    for o in bpy.data.objects:
        if o.type == 'MESH':
            t = sum(len(p.vertices) - 2 for p in o.data.polygons)
            tris += t
            print(f'  {o.name:14s} {t:6d} tris  {o.data.materials[0].name}')
    print('  total', tris)


if __name__ == '__main__':
    build()
    stats()
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, 'jeton.blend'))
    print('jeton.blend ok')
