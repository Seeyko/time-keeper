# Time Keeper

App iOS perso qui bloque des apps après un temps d'écran quotidien et des sites dans tous les navigateurs, sans aucun moyen de débloquer sur le moment. Gratuite, sans compte, sans serveur. FR. Bundle `com.seeyko.timekeeper`. Dépôt privé `Seeyko/time-keeper`.

## Le dépôt

| Dossier | Contenu |
|---|---|
| `ios/` | l'app (SwiftUI, Swift 6, XcodeGen : `cd ios && xcodegen generate -q`). Tests dans `ios/TimeKeeperTests`. |
| `ios/Shared` | règles, moteur et stockage App Group, partagés par l'app et l'extension Monitor |
| `ios/TimeKeeperMonitor` | extension DeviceActivityMonitor : bloque au seuil, débloque au début de la journée |
| `ios/TimeKeeperShieldConfig`, `ios/TimeKeeperShieldAction` | l'écran de blocage, un seul bouton « Fermer » |
| `DESIGN.md` | le système de design |

## La règle produit
- **Jamais de déblocage sur le moment.** Pas de bouton « ignorer », pas de « +15 min », pas de code. Toute évolution garde ça.
- Ce qui rend plus strict s'applique tout de suite. Ce qui assouplit (temps plus long, app retirée, limite supprimée, site débloqué, verrou coupé, heure de début de journée changée) s'applique `Policy.loosenDelay` plus tard (24 h). Le test `RulesTests` le prouve pour chaque cas.
- Modifier une limite ne remet pas le compteur à zéro (`includesPastActivity`).

## Les règles
- **Mac de build partagé** : on code à l'aveugle. Un seul build et un seul simulateur à la fois, à la fin, avec `nice`.
- **Aucun secret dans le dépôt.** `SECRETS.md` dit où vit chaque clé.
- **Confidentialité** : aucune donnée ne quitte l'iPhone. Pas d'analytique.
- **Une PR par étape**, merge quand la CI est verte. Le code d'un build envoyé au store est sur `main`.
- **Présente chaque travail fini** pour un non-technique : un titre humain, une description courte, des captures, puis le lien (skill `present-work` de tom-playbook).
- **Pas de commentaire dans le code, pas de code mort.**
- **Captures** : lancer l'app avec l'argument `-demo` affiche des données d'exemple sans demander Temps d'écran (le simulateur n'a pas de vraies apps à choisir).
- **Outils** : le CLI `asc` pour App Store Connect.

## Charte de design
Voir `DESIGN.md`. Un écran = un titre et, seulement si c'est indispensable, une ligne courte. Tutoiement, phrases de 20 mots au plus. Chaque contrôle a son haptique.
