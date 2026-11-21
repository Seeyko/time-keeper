#!/usr/bin/env python3
import argparse
import json
import math
import os
import random
import sys
from functools import lru_cache

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ICI = os.path.dirname(os.path.abspath(__file__))
DEPOT = os.path.dirname(ICI)
RACINES = {
    "hibou": os.path.join(DEPOT, "store", "make", "owl"),
    "ecran": os.path.join(DEPOT, "screenshots"),
    "brut": os.path.join(DEPOT, "store", "make", "raw"),
    "icone": os.path.join(DEPOT, "ios", "TimeKeeper", "Assets.xcassets", "AppIcon.appiconset"),
}

NUIT = (11, 21, 48)
ACIER = (31, 58, 138)
CLAIR = (185, 204, 255)
BLANC = (255, 255, 255)
ENCRE = (17, 19, 24)

FORMATS = {
    "tiktok": {"taille": (1080, 1920), "sur": (70, 232, 910, 1490)},
    "insta": {"taille": (1080, 1350), "sur": (84, 96, 996, 1262)},
}

INTERDITS = ["—", "–", "découvre", "révolutionn", "guéri", "garanti", "prouvé", "addiction guérie",
             "bravo", "débloquer maintenant"]
A_SURVEILLER = ["addiction", "facile", "il suffit", "jamais plus"]


def chemin(ref):
    if ":" in ref and not ref.startswith("/"):
        cle, nom = ref.split(":", 1)
        if cle in RACINES:
            return os.path.join(RACINES[cle], nom)
    return ref if os.path.isabs(ref) else os.path.join(DEPOT, ref)


@lru_cache(maxsize=64)
def image(ref):
    return Image.open(chemin(ref)).convert("RGBA")


@lru_cache(maxsize=64)
def police(nom, taille):
    fichiers = {
        "serif": "InstrumentSerif-Regular.ttf",
        "serif-italique": "InstrumentSerif-Italic.ttf",
        "natif": "TikTokSans-Bold.ttf",
        "natif-fin": "TikTokSans-SemiBold.ttf",
    }
    return ImageFont.truetype(os.path.join(ICI, "fonts", fichiers[nom]), taille)



def degrade(L, H, haut, bas):
    g = Image.new("RGB", (1, 256))
    for i in range(256):
        t = i / 255
        g.putpixel((0, i), tuple(round(haut[k] + (bas[k] - haut[k]) * t) for k in range(3)))
    return g.resize((L, H), Image.BICUBIC).convert("RGBA")


def cadran(toile, cx, cy, r):
    calque = Image.new("RGBA", toile.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(calque)
    d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=CLAIR + (56,), width=5)
    d.ellipse((cx - r * 0.86, cy - r * 0.86, cx + r * 0.86, cy + r * 0.86), outline=CLAIR + (26,), width=2)
    for i in range(120):
        a = i / 120 * 2 * math.pi
        long = i % 10 == 0
        r1, r2 = r - (110 if long else 46), r - 18
        d.line((cx + math.cos(a) * r1, cy + math.sin(a) * r1, cx + math.cos(a) * r2, cy + math.sin(a) * r2),
               fill=CLAIR + (40,), width=6 if long else 3)
    rw = r * 0.62
    d.pieslice((cx - rw, cy - rw, cx + rw, cy + rw), -90, 30, fill=CLAIR + (22,))
    toile.alpha_composite(calque)


def grain(toile, force=10, graine=7):
    rnd = random.Random(graine)
    petit = Image.new("L", (toile.width // 3, toile.height // 3))
    petit.putdata([rnd.randint(0, 255) for _ in range(petit.width * petit.height)])
    bruit = petit.resize(toile.size).point(lambda v: force if v > 200 else 0)
    toile.paste(Image.new("RGBA", toile.size, BLANC + (255,)), (0, 0), bruit)


def fond(spec, fmt, i=0):
    L, H = FORMATS[fmt]["taille"]
    if spec in ("nuit", "cadran"):
        t = degrade(L, H, (7, 14, 36), (22, 48, 122))
        lueur = Image.new("L", (L, H), 0)
        ImageDraw.Draw(lueur).ellipse((-L * 0.4, H * 0.25, L * 1.4, H * 1.3), fill=95)
        t.paste(Image.new("RGBA", (L, H), (91, 127, 255, 255)), (0, 0), lueur.filter(ImageFilter.GaussianBlur(220)))
        if spec == "cadran":
            cadran(t, L if i % 2 == 0 else 0, round(H * 0.82), round(L * 0.95))
        grain(t)
        return t
    if spec == "noir":
        return Image.new("RGBA", (L, H), (12, 12, 14, 255))
    if spec == "blanc":
        return Image.new("RGBA", (L, H), (246, 246, 248, 255))
    if spec.startswith("flou:"):
        img = image(spec[5:])
        ech = max(L / img.width, H / img.height)
        img = img.resize((round(img.width * ech), round(img.height * ech)), Image.LANCZOS)
        x, y = (img.width - L) // 2, (img.height - H) // 2
        img = img.crop((x, y, x + L, y + H)).filter(ImageFilter.GaussianBlur(38))
        voile = Image.new("RGBA", (L, H), NUIT + (150,))
        img.alpha_composite(voile)
        return img
    raise SystemExit(f"fond inconnu : {spec}")



def mots(texte):
    lignes, accent = [], False
    for brut in texte.replace("'", "’").split("\n"):
        ligne = []
        for bout in brut.split(" "):
            if not bout:
                continue
            debut = True if bout.startswith("*") else accent
            bout = bout.lstrip("*")
            fin = debut
            if "*" in bout:
                bout, fin = bout.replace("*", ""), False
            accent = fin
            if bout and bout[0] in "?!:;»" and ligne:
                m, a = ligne.pop()
                ligne.append((m + " " + bout, a))
            elif ligne and ligne[-1][0] == "«":
                ligne.pop()
                ligne.append(("« " + bout, debut))
            elif bout:
                ligne.append((bout, debut))
        lignes.append(ligne)
    return lignes


def couper(lignes, mesure, esp, largeur):
    def glouton(ligne, larg):
        out, cour, w = [], [], 0
        for m, a in ligne:
            lm = mesure(m, a)
            if cour and w + esp + lm > larg:
                out.append(cour)
                cour, w = [], 0
            w += (esp if cour else 0) + lm
            cour.append((m, a))
        out.append(cour)
        return out

    sortie = []
    for ligne in lignes:
        base = glouton(ligne, largeur)
        bas, haut = largeur * 0.4, largeur
        for _ in range(12):
            mil = (bas + haut) / 2
            if len(glouton(ligne, mil)) <= len(base):
                haut = mil
            else:
                bas = mil
        sortie += glouton(ligne, haut)
    return sortie


def bloc_serif(texte, taille, largeur, couleur=BLANC, accent=CLAIR, interligne=1.04):
    fr, fi = police("serif", taille), police("serif-italique", taille)

    def mesure(m, a):
        return (fi if a else fr).getlength(m)

    lignes = couper(mots(texte), mesure, fr.getlength(" "), largeur)
    pas = round(taille * interligne)
    asc, desc = fr.getmetrics()
    H = pas * (len(lignes) - 1) + asc + desc
    out = Image.new("RGBA", (largeur, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(out)
    esp = fr.getlength(" ")
    for i, ligne in enumerate(lignes):
        w = sum(mesure(m, a) for m, a in ligne) + esp * (len(ligne) - 1)
        x = (largeur - w) / 2
        for m, a in ligne:
            d.text((x, i * pas), m, font=fi if a else fr, fill=accent if a else couleur)
            x += mesure(m, a) + esp
    return out


def bloc_natif(texte, taille, largeur, variante="contour", nom="natif"):
    f = police(nom, taille)
    lignes = couper(mots(texte), lambda m, a: f.getlength(m), f.getlength(" "), largeur - round(taille * 0.9))
    pas = round(taille * (1.42 if variante.startswith("bandeau") else 1.24))
    asc, desc = f.getmetrics()
    M = round(taille * 0.5)
    out = Image.new("RGBA", (largeur, pas * (len(lignes) - 1) + asc + desc + 2 * M), (0, 0, 0, 0))
    d = ImageDraw.Draw(out)
    esp = f.getlength(" ")
    for i, ligne in enumerate(lignes):
        w = sum(f.getlength(m) for m, _ in ligne) + esp * (len(ligne) - 1)
        x, y = (largeur - w) / 2, M + i * pas
        if variante.startswith("bandeau"):
            px, py = taille * 0.34, taille * 0.13
            d.rounded_rectangle((x - px, y + asc * 0.12 - py, x + w + px, y + asc + desc * 0.55 + py), radius=taille * 0.3,
                                fill=BLANC + (255,) if variante == "bandeau" else (17, 17, 17, 220))
        for m, a in ligne:
            if variante == "contour":
                d.text((x, y), m, font=f, fill=CLAIR if a else BLANC, stroke_width=max(3, round(taille * 0.075)), stroke_fill=ENCRE)
            elif variante == "bandeau":
                d.text((x, y), m, font=f, fill=ACIER if a else ENCRE)
            else:
                d.text((x, y), m, font=f, fill=CLAIR if a else BLANC)
            x += f.getlength(m) + esp
    return out.crop(out.getbbox() or (0, 0, 1, 1)) if variante == "contour" else out



def arrondi(img, rayon):
    m = Image.new("L", (img.width * 2, img.height * 2), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, img.width * 2 - 1, img.height * 2 - 1), radius=rayon * 2, fill=255)
    out = img.copy()
    out.putalpha(m.resize(img.size, Image.LANCZOS))
    return out


def ombre(toile, boite, rayon, force=110, flou=30, dy=18):
    x0, y0, x1, y1 = boite
    m = Image.new("L", toile.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((x0, y0 + dy, x1, y1 + dy), radius=rayon, fill=force)
    toile.paste(Image.new("RGBA", toile.size, (0, 0, 0, 255)), (0, 0), m.filter(ImageFilter.GaussianBlur(flou)))


def capture(ref, hauteur, largeur_max, rogne=None):
    img = image(ref)
    if rogne:
        img = img.crop((0, round(img.height * rogne[0]), img.width, round(img.height * rogne[1])))
    ech = min(hauteur / img.height, largeur_max / img.width)
    img = img.resize((round(img.width * ech), round(img.height * ech)), Image.LANCZOS)
    return arrondi(img, round(img.width * 0.09))


def hourglass(d, cx, cy, s, couleur):
    d.line((cx - s, cy - s * 1.3, cx + s, cy - s * 1.3), fill=couleur, width=round(s * 0.22))
    d.line((cx - s, cy + s * 1.3, cx + s, cy + s * 1.3), fill=couleur, width=round(s * 0.22))
    d.polygon([(cx - s * 0.8, cy - s * 1.2), (cx + s * 0.8, cy - s * 1.2), (cx, cy)], fill=couleur)
    d.polygon([(cx - s * 0.8, cy + s * 1.2), (cx + s * 0.8, cy + s * 1.2), (cx, cy)], fill=couleur)


def alerte(spec, largeur):
    ft, fm, fb = police("natif", 54), police("natif-fin", 38), police("natif-fin", 42)
    l = largeur
    message = spec.get("message", "Tu as atteint ta limite pour TikTok.")
    lignes = couper(mots(message), lambda m, a: fm.getlength(m), fm.getlength(" "), l - 140)
    boutons = spec.get("boutons", ["OK", "Ignorer la limite"])
    h = 120 + 150 + 80 + len(lignes) * 52 + 70 + len(boutons) * 128 + 40
    carte = Image.new("RGBA", (l, h), (28, 28, 32, 255))
    d = ImageDraw.Draw(carte)
    hourglass(d, l / 2, 190, 46, (255, 159, 10))
    y = 300
    t = spec.get("titre", "Limite de temps")
    d.text(((l - ft.getlength(t)) / 2, y), t, font=ft, fill=BLANC)
    y += 90
    for ligne in lignes:
        s = " ".join(m for m, _ in ligne)
        d.text(((l - fm.getlength(s)) / 2, y), s, font=fm, fill=(170, 170, 178))
        y += 52
    y += 60
    entoure = spec.get("entoure")
    for i, b in enumerate(boutons):
        bx0, bx1 = 60, l - 60
        plein = i == 0
        d.rounded_rectangle((bx0, y, bx1, y + 104), radius=30, fill=(10, 132, 255) if plein else (44, 44, 50))
        couleur = BLANC if plein else (10, 132, 255)
        d.text(((l - fb.getlength(b)) / 2, y + 26), b, font=fb, fill=couleur)
        if entoure == b:
            d.rounded_rectangle((bx0 - 18, y - 18, bx1 + 18, y + 122), radius=44, outline=(255, 69, 58), width=9)
        if spec.get("barre") == b:
            d.line((bx0 + 60, y + 52, bx1 - 60, y + 52), fill=(255, 69, 58), width=10)
        y += 128
    return arrondi(carte, 56)


def pilule(texte, taille=50):
    f = police("natif", taille)
    w = int(f.getlength(texte))
    asc, desc = f.getmetrics()
    p = Image.new("RGBA", (w + 120, taille + 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(p)
    d.rounded_rectangle((0, 0, p.width - 1, p.height - 1), radius=p.height // 2, fill=BLANC + (255,))
    d.text((60, 32 + (taille - asc - desc) / 2 + taille * 0.04), texte, font=f, fill=NUIT)
    return p


def poser_hibou(toile, spec, sur):
    x0, y0, x1, y1 = sur
    img = image("hibou:" + spec["pose"] + ".png")
    h = round(spec.get("h", 0.3) * 1080)
    img = img.resize((max(1, round(img.width * h / img.height)), h), Image.LANCZOS)
    if spec.get("miroir"):
        img = img.transpose(Image.FLIP_LEFT_RIGHT)
    cx = x0 + (x1 - x0) * spec.get("x", 0.5)
    cy = y0 + (y1 - y0) * spec.get("y", 0.8)
    toile.alpha_composite(img, (round(cx - img.width / 2), round(cy - img.height / 2)))



def rendre_slide(s, fmt, post, i):
    L, H = FORMATS[fmt]["taille"]
    x0, y0, x1, y1 = FORMATS[fmt]["sur"]
    larg = x1 - x0
    genre = s.get("type", "titre")
    style = s.get("style", post.get("style", "cadran"))
    natif = style.startswith("natif")
    variante = style.split(":")[1] if ":" in style else "contour"
    defaut = {"contour": "noir", "bandeau": "nuit", "bandeau-noir": "noir"}.get(variante, "cadran") if natif else "cadran"
    toile = fond(s.get("fond", post.get("fond", defaut)), fmt, i)
    reglage = {**s, **s.get(fmt, {})}

    hibou = reglage.get("hibou")
    if hibou and not hibou.get("devant"):
        poser_hibou(toile, hibou, (x0, y0, x1, y1))

    elements = []
    titre = s.get("titre")
    if titre:
        max_h = reglage.get("max_h", 0.5 if genre in ("titre", "cta") else 0.26) * (y1 - y0)
        taille = round((76 if natif else 118) * reglage.get("taille", 1))
        while True:
            c = bloc_natif(titre, taille, larg, variante) if natif else bloc_serif(titre, taille, larg)
            if c.height <= max_h or taille <= (40 if natif else 60):
                break
            taille -= 4
        elements.append((c, (28 if variante == "contour" else 10) if natif else 34))
    if s.get("ligne"):
        t = round(50 * reglage.get("taille_ligne", 1))
        c = bloc_natif(s["ligne"], t, larg, variante, "natif-fin") if natif else \
            bloc_serif(s["ligne"], round(t * 1.25), larg - 60, couleur=(220, 228, 255), interligne=1.18)
        elements.append((c, 10))

    corps = None
    if genre == "liste":
        corps = []
        for it in s["liste"]:
            corps.append(bloc_natif(it, 54, larg, variante, "natif-fin") if natif else bloc_serif(it, 70, larg - 40, interligne=1.1))
    haut_txt = sum(c.height + e for c, e in elements)
    pos = reglage.get("position", "haut" if genre in ("app", "alerte", "liste", "cta") or hibou else "milieu")
    y = y0 if pos == "haut" else (y1 - haut_txt if pos == "bas" else y0 + (y1 - y0 - haut_txt) / 2)
    if "y" in reglage:
        y = y0 + (y1 - y0) * reglage["y"]
    cy = round(y)
    for c, e in elements:
        toile.alpha_composite(c, (x0 + (larg - c.width) // 2, cy))
        cy += c.height + e
    bas = cy

    if genre == "app":
        dispo = y1 - bas - 30
        cap = capture(s["capture"], dispo, larg - 120, s.get("rogne"))
        bx, by = x0 + (larg - cap.width) // 2, bas + 30 + (dispo - cap.height) // 2
        ombre(toile, (bx, by, bx + cap.width, by + cap.height), round(cap.width * 0.09))
        toile.alpha_composite(cap, (bx, by))
    elif genre == "alerte":
        a = alerte(s.get("alerte", {}), min(larg - 40, 860))
        dispo = y1 - bas
        if a.height > dispo - 20:
            k = (dispo - 20) / a.height
            a = a.resize((round(a.width * k), round(a.height * k)), Image.LANCZOS)
        bx, by = x0 + (larg - a.width) // 2, bas + max(20, (dispo - a.height) // 2)
        ombre(toile, (bx, by, bx + a.width, by + a.height), 56)
        toile.alpha_composite(a, (bx, by))
    elif genre == "liste":
        tot = sum(c.height for c in corps) + 30 * (len(corps) - 1)
        ly = bas + max(30, (y1 - bas - tot) // 2)
        for c in corps:
            toile.alpha_composite(c, (x0 + (larg - c.width) // 2, ly))
            ly += c.height + 30
    elif genre == "cta":
        ic = arrondi(image("icone:icon-1024.png").resize((250, 250), Image.LANCZOS), 56)
        nom = bloc_natif(post.get("nom", "Time Keeper"), 50, larg, "contour" if not natif or variante == "contour" else "bandeau-noir", "natif-fin")
        b = pilule(s.get("bouton", "Lien en bio"))
        bloc = ic.height + 28 + nom.height + 50 + b.height
        iy = bas + max(30, (y1 - bas - bloc) // 2)
        ix = x0 + (larg - ic.width) // 2
        ombre(toile, (ix, iy, ix + ic.width, iy + ic.height), 56, force=140)
        toile.alpha_composite(ic, (ix, iy))
        iy += ic.height + 28
        toile.alpha_composite(nom, (x0 + (larg - nom.width) // 2, iy))
        iy += nom.height + 50
        toile.alpha_composite(b, (x0 + (larg - b.width) // 2, iy))

    if hibou and hibou.get("devant"):
        poser_hibou(toile, hibou, (x0, y0, x1, y1))
    if s.get("numero"):
        n = bloc_natif(s["numero"], 40, larg, "bandeau-noir", "natif-fin")
        toile.alpha_composite(n, (x0 + (larg - n.width) // 2, y0 - 70 if fmt == "tiktok" else y0 - 40))
    return toile.convert("RGB")



def textes(post):
    for i, s in enumerate(post["slides"]):
        for cle in ("titre", "ligne", "bouton", "numero"):
            if s.get(cle):
                yield f"slide {i + 1} {cle}", s[cle]
        for it in s.get("liste", []):
            yield f"slide {i + 1} liste", it
    for cle, v in post.get("legende", {}).items():
        yield f"légende {cle}", v


def verifier(post, slug):
    alertes = []
    n = len(post["slides"])
    if not 4 <= n <= 8:
        alertes.append(f"{n} slides (4 à 8 attendues)")
    if post["slides"][-1].get("type") != "cta":
        alertes.append("la dernière slide n'est pas le CTA")
    if not any(s.get("type") == "app" for s in post["slides"]):
        alertes.append("aucune slide ne montre l'app")
    if not 3 <= len(post.get("hashtags", [])) <= 5:
        alertes.append("3 à 5 hashtags attendus")
    hook = (post["slides"][0].get("titre") or "").replace("*", "").split()
    if len(hook) > 8:
        alertes.append(f"hook de {len(hook)} mots (8 au plus)")
    for ou, t in textes(post):
        bas = t.lower()
        for mot in INTERDITS:
            if mot in bas:
                alertes.append(f"INTERDIT « {mot} » ({ou})")
        for mot in A_SURVEILLER:
            if mot in bas:
                alertes.append(f"à relire « {mot} » ({ou})")
    for leg in post.get("legende", {}).values():
        if "lien en bio" not in leg.lower():
            alertes.append("« lien en bio » manque dans une légende")
    for a in alertes:
        print(f"  ! {slug} : {a}")
    return alertes


def legende(post):
    tags = " ".join("#" + h.lstrip("#") for h in post.get("hashtags", []))
    leg = post.get("legende", {})
    return (f"TIKTOK\n{leg.get('tiktok', '')}\n{tags}\n\n"
            f"INSTAGRAM\n{leg.get('insta', leg.get('tiktok', ''))}\n{tags}\n\n"
            f"SON CONSEILLÉ (à ajouter à la main dans l'app)\n{post.get('son', '')}\n")


def planche(rangs, sortie, zones=False):
    marge, cellules, y = 16, [], 16
    for fmt, imgs in rangs:
        h = 560 if fmt == "tiktok" else 394
        x = marge
        for im in imgs:
            v = im.copy()
            if zones and fmt == "tiktok":
                d = ImageDraw.Draw(v, "RGBA")
                for z in ((0, 0, 1080, 220), (0, 1500, 1080, 1920), (920, 0, 1080, 1920)):
                    d.rectangle(z, fill=(220, 40, 40, 60))
            v = v.resize((round(v.width * h / v.height), h), Image.LANCZOS)
            cellules.append((v, x, y))
            x += v.width + marge
        y += h + marge
    L = max(x + v.width for v, x, _ in cellules) + marge
    p = Image.new("RGB", (L, y), (30, 32, 40))
    for v, x, yy in cellules:
        p.paste(v, (x, yy))
    p.save(sortie, quality=88)


def rendre_post(fichier, sortie, zones=False, style=None):
    post = json.load(open(fichier, encoding="utf-8"))
    slug = post.get("slug") or os.path.splitext(os.path.basename(fichier))[0]
    if style:
        post["style"] = style
        post.pop("fond", None)
        for sl in post["slides"]:
            sl.pop("style", None)
            sl.pop("fond", None)
        slug += "--" + style.replace(":", "-")
    verifier(post, slug)
    dossier = os.path.join(sortie, slug)
    os.makedirs(dossier, exist_ok=True)
    rangs = []
    for fmt in ("tiktok", "insta"):
        imgs = []
        for i, s in enumerate(post["slides"]):
            im = rendre_slide(s, fmt, post, i)
            im.save(os.path.join(dossier, f"{fmt}-{i + 1:02d}.png"), compress_level=6)
            imgs.append(im)
        rangs.append((fmt, imgs))
    open(os.path.join(dossier, "legende.txt"), "w", encoding="utf-8").write(legende(post))
    planche(rangs, os.path.join(dossier, "contact.jpg"), zones)
    print(f"{slug} : {len(post['slides'])} slides")
    return slug, rangs[0][1][0]


def main():
    ap = argparse.ArgumentParser(description="Rend les posts TikTok et Instagram de Time Keeper (voir social/README.md).")
    ap.add_argument("posts", nargs="+")
    ap.add_argument("--sortie", default=os.path.join(ICI, "out"))
    ap.add_argument("--zones", action="store_true", help="montre les zones TikTok à éviter sur les planches")
    ap.add_argument("--style", help="force un style : cadran, natif:contour, natif:bandeau, natif:bandeau-noir")
    a = ap.parse_args()
    unes = [rendre_post(f, a.sortie, a.zones, a.style) for f in sorted(a.posts)]
    if len(unes) > 1:
        cols, l, h = 6, 360, 640
        p = Image.new("RGB", (cols * (l + 16) + 16, ((len(unes) + cols - 1) // cols) * (h + 16) + 16), (30, 32, 40))
        for i, (_, im) in enumerate(unes):
            p.paste(im.resize((l, h), Image.LANCZOS), (16 + (i % cols) * (l + 16), 16 + (i // cols) * (h + 16)))
        p.save(os.path.join(a.sortie, "planche-lot.jpg"), quality=88)


if __name__ == "__main__":
    sys.exit(main())
