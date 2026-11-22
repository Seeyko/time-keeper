# social : les posts TikTok et Instagram, rendus par code

Un post = un fichier JSON. `render.py` rend les slides TikTok (1080x1920), le carrousel Instagram (1080x1350), la légende et une planche contact. La voix et les hooks sont dans `VOIX-TIKTOK.md`, l'étude de la niche dans `etude/corpus.md`.

```
pip install pillow
python3 social/render.py social/posts/lot-01/*.json --sortie /mnt/project-files/time-keeper-tiktok/lot-01/
python3 social/render.py social/posts/styles/*.json --style natif:bandeau --zones
```

Sans `--sortie`, les rendus vont dans `social/out/` (ignoré par git). `--zones` montre les bords que TikTok recouvre. Le script signale un hook trop long, un mot interdit, un CTA ou une slide d'app qui manque.

## Un post

```json
{
  "slug": "01-ignorer-la-limite",
  "format": "le-bouton-ignorer",
  "style": "cadran",
  "slides": [
    {"type": "alerte", "titre": "« Ignorer la limite. »\n*Tous les soirs.*",
     "alerte": {"message": "Tu as atteint ta limite pour TikTok.", "boutons": ["OK", "Ignorer la limite"], "entoure": "Ignorer la limite"}},
    {"titre": "Ta limite tient *4 secondes*.", "ligne": "Le temps de trouver le bouton.", "hibou": {"pose": "patient", "y": 0.86, "h": 0.42}},
    {"type": "app", "titre": "Ici, il reste *un seul bouton*.", "capture": "brut:shield.png", "rogne": [0.27, 0.93]},
    {"type": "cta", "titre": "Ta limite va enfin *tenir*."}
  ],
  "legende": {"tiktok": "… Lien en bio. Envoie ça à …", "insta": "… Lien en bio."},
  "hashtags": ["tempsdecran", "screentime", "doomscrolling"],
  "son": "ambiance conseillée, ajoutée à la main dans l'app"
}
```

| Clé de slide | Rôle |
|---|---|
| `type` | `titre` (défaut), `liste` (avec `liste: [...]`), `app` (avec `capture`, `rogne: [haut, bas]`), `alerte` (l'écran « Limite de temps » d'iOS redessiné : `titre`, `message`, `boutons`, `entoure`, `barre`), `cta` |
| `fond` | `cadran` (nuit + cadran), `nuit`, `noir`, `blanc`, `flou:<image>` |
| `titre` | `*mots*` = accent (italique bleu clair en `cadran`), `\n` = saut de ligne |
| `ligne` | une ligne courte, seulement si elle sert |
| `hibou` | `pose` (`cadenas`, `garde`, `lit`, `montre`, `non`, `patient`), `x`, `y`, `h`, `miroir`, `devant` |
| `numero` | le repère d'une série, en haut |
| `position`, `y` | où poser le texte : `haut`, `milieu`, `bas`, ou une part de la zone sûre |
| `taille`, `taille_ligne`, `max_h` | réglages du texte |
| `tiktok`, `insta` | les mêmes clés, pour un seul format |

Préfixes d'images : `hibou:` = `store/make/owl/`, `ecran:` = `screenshots/`, `brut:` = `store/make/raw/`, `icone:` = l'icône de l'app.

## Styles

| Style | Rendu |
|---|---|
| `cadran` (défaut) | Instrument Serif blanc, accent en italique bleu clair, fond nuit avec le cadran : la marque |
| `natif:bandeau` | TikTok Sans sur bandeau blanc, fond nuit |
| `natif:contour` | TikTok Sans blanc à contour noir, fond noir |
| `natif:bandeau-noir` | blanc sur bandeau noir |

Polices sous licence OFL : Instrument Serif, TikTok Sans.
