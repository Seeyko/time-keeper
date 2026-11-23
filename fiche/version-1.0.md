# Fiche App Store : version 1.0

Chaque valeur envoyée à App Store Connect est écrite ici. Les captures sortent de `store/make` (voir `store/README.md`).

## Pour qui on écrit

Jeunes actifs couche-tard (choix de Tom, 23/11) : 25 à 32 ans, un travail de bureau, au lit à 23 h, sur TikTok ou YouTube jusqu'à 1 h, debout à 7 h. Ils arrivent le soir, téléphone en main, après une heure de scroll qu'ils n'ont pas choisie. Elle a déjà essayé Temps d'écran d'Apple et d'autres bloqueurs : elle a appuyé sur « Ignorer », elle a payé un abonnement, elle a dû bloquer tout Safari pour couper un seul site.

| Sa douleur, dite par Tom | Ce que l'app fait vraiment |
|---|---|
| « On peut juste ignorer "limite atteinte". » | Pas de bouton. L'écran de blocage n'a que « Fermer ». |
| « Les autres apps demandent un abonnement. » | Sans compte, open source. L'app est payante, mais sans bouton pour tricher. |
| « On ne peut pas bloquer juste youtube.com sans bloquer le navigateur. » | Un domaine bloqué dans tous les navigateurs. |
| On défait la règle dans un moment de faiblesse. | Assouplir prend 24 h. La suppression d'apps peut être verrouillée. |

Une vraie étude d'audience (avis des concurrents, forums) reste à faire pour ajuster les mots.

**Qui elle veut devenir** : quelqu'un qui pose son téléphone et retrouve ses soirées, sans compter sur sa volonté du moment.

**Le déclic** : la première fois que la limite tombe et qu'il n'y a rien d'autre à faire que « Fermer ».

## Français (France), lu aussi en Belgique, Suisse, Canada

| Champ | Valeur | Taille |
|---|---|---|
| Nom | Time Keeper – Temps d'écran | 27 car. |
| Sous-titre | Bloqueur d'apps sans Ignorer | 28 car. |
| Mots-clés | limite,bloquer,site,réseaux,sociaux,sommeil,scroll,soir,nuit,coucher,détox,addiction,navigateur | 97 octets |
| Texte promotionnel | 23 h, au lit. Ta limite tombe et il n'y a pas de bouton « Ignorer » : l'app reste fermée jusqu'au matin. Essaie 7 jours. | 123 car. |

### Description

Time Keeper limite ton temps d'écran et bloque des sites, sans aucun moyen de tricher sur le moment.

Au lit à 23 h, encore sur ton téléphone à 1 h ? Tu connais le message « Limite atteinte ». Tu appuies sur « Ignorer », et tu continues. Ici, ce bouton n'existe pas.

LIMITE ATTEINTE, C'EST FINI POUR AUJOURD'HUI
• Une limite par jour pour un groupe d'apps : par exemple 30 min de réseaux sociaux, toutes apps confondues.
• Quand le temps est écoulé, l'app est bloquée jusqu'au lendemain. L'écran de blocage a un seul bouton : « Fermer ».
• Tu choisis l'heure où commence ta journée, 4 h par exemple : ton compteur ne repart pas à minuit pile.
• Modifier une limite ne remet pas le compteur à zéro.

UN SITE, PAS TOUT LE NAVIGATEUR
Bloque un site précis dans tous les navigateurs. Le reste du web reste ouvert.

DURCIR, C'EST TOUT DE SUITE. ASSOUPLIR, C'EST DANS 24 H.
Réduire un temps ou bloquer un site s'applique tout de suite. Allonger une limite, retirer une app ou débloquer un site s'applique 24 h plus tard. Tu peux aussi empêcher la suppression d'apps, pour ne pas contourner la règle en désinstallant.

SANS COMPTE, SANS PUB
Time Keeper s'appuie sur Temps d'écran d'Apple. Le code est ouvert, sous licence MIT.

Abonnement annuel avec 7 jours d'essai, ou achat à vie.
Conditions d'utilisation : https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Confidentialité : https://github.com/Seeyko/time-keeper/blob/main/PRIVACY.md

Time Keeper demande l'accès à Temps d'écran pour pouvoir bloquer. iOS 17.4 ou plus récent.

### Légendes des captures

Chaque capture part d'une phrase que la personne s'est déjà dite, puis montre la réponse de l'app. Le hibou change de pose à chaque fois.

| # | Fichier | Ce qu'il se dit | La réponse | Hibou |
|---|---|---|---|---|
| 1 | `01-encore-5-minutes` | « Au lit à 23 h. » Le téléphone posé à 1 h. | Une limite de temps d'écran qui tient vraiment. | bras croisés |
| 2 | `02-juste-fermer` | « À minuit, j'appuie sur Ignorer sans réfléchir. » | Ici, il n'y a qu'un bouton : Fermer. | montre le bouton |
| 3 | `03-un-site-pas-le-navigateur` | « Encore une vidéo YouTube avant de dormir. » | Un site bloqué dans tous les navigateurs. | cadenas |
| 4 | `04-assouplir-24h` | « Le soir, je rallonge ma limite dès que ça m'arrange. » | Assouplir une règle prend 24 h. | patient sur sa montre |
| 5 | `05-impossible-a-supprimer` | « Je supprime l'app et c'est réglé. » | Pas cette fois : la suppression est verrouillée. | fait non |
| 6 | `06-nouvelle-journee` | « À 1 h du matin, mon compteur est déjà à zéro. » | Ta journée commence à l'heure que tu choisis. | bras croisés |
| 7 | `07-ton-temps-te-revient` | « Ce soir, j'ai éteint à 23 h. » | Tes soirées te reviennent. | lit un livre |

### Vidéo d'aperçu (iPhone 6,9")

28 s, 886 × 1920, sortie de `store/make/preview.cjs`. L'onboarding jusqu'à l'écran de blocage, l'accueil, un site bloqué, l'assouplissement en 24 h, puis « Tes soirées te reviennent ».

Les trois premières portent les mots cherchés : limite, temps d'écran, bloquer, site, navigateur.

## Anglais (Royaume-Uni), lu aussi en France

En France, Apple lit aussi la fiche anglaise du Royaume-Uni : ses mots-clés sont en français pour gagner 100 octets.

| Champ | Valeur | Taille |
|---|---|---|
| Nom | Time Keeper: Screen Time | 24 car. |
| Sous-titre | Strict app & website blocker | 28 car. |
| Mots-clés | procrastination,dopamine,scroll,minuteur,productivité,sommeil,distraction,discipline,habitude,pause | 100 octets |

## Anglais (États-Unis, Australie)

| Champ | Valeur | Taille |
|---|---|---|
| Nom | Time Keeper: Screen Time | 24 car. |
| Sous-titre | Strict app & website blocker | 28 car. |
| Mots-clés | limit,block,social,media,sleep,bedtime,night,scroll,detox,addiction,phone,browser,lock,dopamine | 95 octets |
| Texte promotionnel | 11 pm, in bed. Your limit hits and there's no "Ignore" button: the app stays closed until morning. Try it free for 7 days. | 122 car. |

### Description (en)

Time Keeper limits your screen time and blocks websites, with no way to cheat in the moment. The app is in French for now.

In bed at 11 pm, still on your phone at 1 am? You know the "Time limit" screen. You tap "Ignore" and keep scrolling. Here, that button doesn't exist.

LIMIT REACHED MEANS DONE FOR TODAY
• One daily limit for a group of apps: for example 30 min of social media, across all of them.
• When time is up, the app stays blocked until tomorrow. The block screen has a single button: "Close".
• Pick when your day starts, 4 am for example, so your counter doesn't reset at midnight.
• Changing a limit doesn't reset the counter.

ONE WEBSITE, NOT THE WHOLE BROWSER
Block a specific website in every browser. The rest of the web stays open.

STRICTER NOW, LOOSER IN 24 HOURS
Lowering a limit or blocking a site applies at once. Raising a limit, removing an app or unblocking a site applies 24 hours later. You can also prevent app deletion, so uninstalling isn't a way out.

NO ACCOUNT, NO ADS
Time Keeper runs on Apple's Screen Time. The code is open source, MIT licence.

Yearly subscription with a 7-day free trial, or a lifetime purchase.
Terms of use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy: https://github.com/Seeyko/time-keeper/blob/main/PRIVACY.md

Time Keeper asks for Screen Time access to block apps. Requires iOS 17.4 or later.

## Liens (toutes les langues)

| Champ | URL |
|---|---|
| Confidentialité | https://github.com/Seeyko/time-keeper/blob/main/PRIVACY.md |
| Assistance | https://github.com/Seeyko/time-keeper/issues |
| Conditions d'utilisation (fin de la description) | https://www.apple.com/legal/internet-services/itunes/dev/stdeula/ |

## Ce qui reste à faire après la sortie
- En-tête 21:9 et image des résultats de recherche (bibliothèque d'éléments), une fois la 1.0 validée.
- Pages produit personnalisées : « bloquer un site », « réseaux sociaux », « sans abonnement ».
- Relevé de la fiche deux fois par semaine.

## Journal
- 2026-11-23 : fiche, légendes et vidéo réécrites pour les jeunes actifs couche-tard, captures refaites sur l'app au style des Réglages.
- 2026-11-21 : première fiche complète, 7 captures sur fond cadran.
- 2026-11-22 : l'app devient payante : capture 6 remplacée (heure de début de journée), « gratuit » et les promesses de confidentialité retirés en attendant la décision sur l'analytique.
- 2026-11-21 : légendes réécrites en phrases que la personne se dit, hibou dans six poses.
