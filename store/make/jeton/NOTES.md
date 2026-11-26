# Le jeton de la parenthèse, en 3D

## Les choix
- Un fond de boîtier, pas une pièce : carrure en laiton à 120 cannelures, lunette satinée entre chanfreins polis, verre bombé.
- Guillochage en rosace entrelacée : 84 spirales par sens, 2 184 clous de Paris en vraie géométrie.
- Verso : centre colimaçonné, piste brossée, 60 traits de laiton en relief, filet-jauge.
- Parenthèses satinées à chanfreins polis, lisibles de face.

## Hiérarchie, axes, échelle
- Diamètre 1,0, épaisseur 0,107 (0,111 avec le verre). Origine au centre. 46 176 triangles.
- Nœud `Jeton` : +Y vers midi, +Z sort du recto. Retournement autour de Y.
- `jeton.usdz` : `root` (−90° X) > `Axes` (+90° X) > `Jeton` (identité) > pièces. Les deux rotations s'annulent : n'animer que `Jeton`.
- `jeton.glb` : `Jeton` à la racine, même repère.
- Pièces : `Carrure`, `Lunette`, `Cuvette`, `Medaillon`, `MedaillonFond`, `ParenL`, `ParenR`, `Index1`, `Index2`, `Verre`, `Fond`, `Minuterie`, `Filet`, `Pivot`, `PivotCoeur`.

## Matières (couleur, métal, rugosité)
| Matière | Valeurs | Textures |
|---|---|---|
| `Laiton` | #D8A446, 1, 0,09 poli à 0,30 satiné | oui |
| `AcierGuilloche` | #2C4A9E, 1, 0,11 à 0,17 | oui |
| `AcierBrosse` | #2A479A, 1, 0,34 | oui |
| `AcierPoli` | #2C4A9E, 1, 0,10 | non |
| `LaitonPoli` | #D8A446, 1, 0,16 | non |
| `LaitonFilet` | #E2B45A, 1, 0,16 | non |
| `Email` | #F7EBDB, 0, 0,14, émission 1,0 | non |
| `Verre` | noir, 0, 0,02, opacité 0,06 | non |

Textures : `baseColor` et `roughness` 1024, `normal` 2048 (OpenGL), `metallic` uni.

## Animer
- Retourner : `Jeton.eulerAngles.y` de 0 (recto) à π (verso). Film : 2,5 tours accélérés, puis ressort amorti.
- Écarter : `ParenL.position.x` −0,036, `ParenR.position.x` +0,036.
- Stock : `Index1` et `Index2` partagent `Email`. Copier la matière, puis émission noire et diffus #2B2620.
- Jauge : l'UV `u` de `Filet` vaut 0 à midi et croît en sens horaire vu du verso. Un shader modifier écarte `u > progression`.
- Vide : désaturer les matières, éteindre les index.
- `Verre` est optionnel : le masquer si la transparence gêne.
- Reflets : `env.png` en `lightingEnvironment`, centre de l'image côté caméra, à tourner avec `contentsTransform` si besoin. `env.hdr` donne des reflets plus vifs.

## Cycles contre SceneKit
- Pas d'anisotropie : les éventails du colimaçon et du satiné deviennent des stries de normal map, plus discrètes.
- L'irisation violette et les reflets entre pièces disparaissent.
- Le verre n'est qu'une transparence.
- Flou de mouvement et éclat lumineux sont à refaire dans l'app.
- Activer l'anticrénelage 4x : le guillochage scintille sans lui.
- Non testé sur iPhone : seul un réimport Blender a été vérifié (`apercu-export.jpg`).
