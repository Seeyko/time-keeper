# Captures App Store

Sept captures 1320 × 2868 (iPhone 6,9"), générées depuis les captures brutes de `screenshots/` (l'app lancée avec `-demo`).

```sh
npm i -g playwright
NODE_PATH=$(npm root -g) node store/make/render.cjs
```

- `make/slides.json` : le titre, l'écran et la loupe de chaque capture (`crop` = centre x, centre y, largeur, hauteur en pixels de la capture brute).
- `make/shield.html` : l'écran de blocage, que le simulateur ne sait pas afficher.
- `make/fonts` : Instrument Serif (licence OFL).
- `make/owl` : le hibou dans six poses, détouré.

Les images du README (`.github/readme/`) sortent de `make/readme.cjs`, à partir de ces captures et de `screenshots/onboarding/` :

```sh
NODE_PATH=$(npm root -g) node store/make/readme.cjs
```

Les légendes et le texte de la fiche sont dans `fiche/version-1.0.md`.
