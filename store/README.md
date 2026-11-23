# Captures App Store

Sept captures 1320 × 2868 (iPhone 6,9") et sept 2064 × 2752 (iPad 13"), plus une vidéo d'aperçu iPhone de 28 s.

Les captures brutes montrent les Central Icons, dont la licence interdit la publication : elles restent hors du dépôt, sur le Mac. `SCREENS` pointe vers le dossier qui contient `iphone/` et `ipad/` (simulateurs iPhone 17 Pro et iPad Pro 13 pouces, app lancée avec `-demo`), `OUT` vers le dossier de sortie, hors du dépôt lui aussi.

```sh
npm i -g playwright
export NODE_PATH=$(npm root -g) SCREENS=~/captures
OUT=~/store/iphone node store/make/render.cjs
OUT=~/store/ipad node store/make/render.cjs slides-ipad.json
CLIPS=~/captures/video OUT=~/store/preview.mp4 node store/make/preview.cjs
```

La vidéo assemble les enregistrements du simulateur iPhone (`v1-onboarding.mp4`, `v2-accueil.mp4`, `v3-assouplir.mp4`, `v4-sites.mp4`) avec ffmpeg, selon `make/preview.json`.

- `make/slides.json`, `make/slides-ipad.json` : le titre, l'écran et la loupe de chaque capture (`crop` = centre x, centre y, largeur, hauteur en pixels de la capture brute).
- `make/shield.html` : l'écran de blocage, que le simulateur ne sait pas afficher.
- `make/fonts` : Instrument Serif (licence OFL).
- `make/owl` : le hibou dans six poses, détouré.

Les images du README (`.github/readme/`) sortent de `make/readme.cjs`, à partir des captures de `store/` (ancienne version, sans Central Icons) et de `screenshots/onboarding/` :

```sh
NODE_PATH=$(npm root -g) node store/make/readme.cjs
```

Les légendes et le texte de la fiche sont dans `fiche/version-1.0.md`.
