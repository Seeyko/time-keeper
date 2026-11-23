# Time Keeper

App iOS open source (MIT) qui bloque des apps après un temps d'écran quotidien et des sites dans tous les navigateurs, sans aucun moyen de débloquer sur le moment. Payante sur l'App Store (19,99 €/an avec 7 jours offerts, ou 39,99 € à vie), sans compte, sans serveur. FR. Bundle `com.seeyko.timekeeper`. Dépôt `Seeyko/time-keeper`, destiné à être public.

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
- **Le paywall** (`PaywallView`, `Store`) : dur, sans croix, après l'onboarding. Sans achat valide, l'app suspend les blocages (`SharedStorage.suspended`) sans effacer les règles, qui reviennent dès l'achat. Un abonnement résilié reste actif jusqu'à la fin de la période payée : jamais de déblocage sur le moment. L'accès offert passe par des codes d'offre Apple, à usage unique, que Tom donne lui-même.

## Les règles
- **Mac de build partagé** : on code à l'aveugle. Un seul build et un seul simulateur à la fois, à la fin, avec `nice`.
- **Aucun secret dans le dépôt, il est public.** `SECRETS.md` dit où vit chaque clé. Jamais de runner auto-hébergé : une PR d'un fork pourrait exécuter du code sur la machine.
- **Déploiement** : chaque fusion sur `main` envoie un build sur TestFlight (`.github/workflows/ios.yml`, environnement `testflight`, actif quand la variable `TESTFLIGHT_ENABLED` vaut `true`).
- **Confidentialité** : les règles, les apps, les sites et les durées ne quittent jamais l'iPhone. Seule une analytique anonyme part vers PostHog (UE, IP jetée, identifiant aléatoire, interrupteur « Statistiques anonymes ») : écrans de l'onboarding, paywall, achats, et les messages « Ton avis ». Choix de Tom, 2026-11-21. Détail dans `docs/analytique.md`, à garder d'accord avec `PRIVACY.md`.
- **Une PR par étape**, merge quand la CI est verte. Le code d'un build envoyé au store est sur `main`.
- **Présente chaque travail fini** pour un non-technique : un titre humain, une description courte, des captures, puis le lien (skill `present-work` de tom-playbook).
- **Pas de commentaire dans le code, pas de code mort.**
- **Captures** : lancer l'app avec l'argument `-demo` affiche des données d'exemple sans demander Temps d'écran (le simulateur n'a pas de vraies apps à choisir). `-onboarding` rejoue l'onboarding avec les mêmes données fictives. `-demo -settings` ouvre les Réglages. `-demo -paywall` montre le paywall, avec les prix du fichier `ios/TimeKeeper.storekit` (France).
- **Outils** : le CLI `asc` pour App Store Connect.

## Charte de design
Voir `DESIGN.md`. Un écran = un titre et, seulement si c'est indispensable, une ligne courte. Tutoiement, phrases de 20 mots au plus. Chaque contrôle a son haptique.
