---
name: Time Keeper
colors:
  paper: "#FFFFFF"
  ink: "#111318"
  accent: "#1F3A8A"
typography:
  title: "New York (serif système), .largeTitle semibold"
  body: "SF Pro, .body"
---

# Time Keeper : le système de design

Ce fichier gagne sur tout skill de design. Une correction du propriétaire devient une règle ici, avec sa raison.

## Overview
Un cadran de montre : classique, moderne, épuré. Des titres en serif posés sur un fond nu, des filets fins, une seule couleur d'accent. Un outil, pas un coach : jamais de culpabilisation, de jeu ou de récompense. La règle est posée, elle s'applique.

## Colors
Tout est dans `ios/TimeKeeper/Theme.swift`. Une couleur porte un sens, jamais une décoration.

| Nom | Clair | Sombre | Rôle |
|---|---|---|---|
| fond | fond système | fond système | l'écran, sans carte |
| encre | `label` | `label` | le texte |
| `Theme.accent` | `#1F3A8A` | `#9DB7FF` | l'action, le cadran (l'acier bleui des aiguilles), le plumage du hibou de l'icône |
| `Theme.onAccent` | `#FFFFFF` | `#0B1530` | le texte posé sur l'accent |
| `Theme.blocked` | `#B3261E` | `#FF8A80` | seulement « Bloqué » |
| `Theme.pending` | `#8A5300` | `#FFB84D` | seulement un assouplissement en attente |
| `Theme.pendingGround` | `#FFF4DE` | `#2A1F0A` | le fond de la bannière en attente |
| `Theme.field` | `#F0F1F4` | `#1C1D22` | le fond d'un champ |
| `Theme.accentGround` | `#EEF2FC` | `#172447` | le fond d'un choix sélectionné (onboarding) |
| `Theme.hairline` | `#E4E6EB` | `#2C2E35` | les filets et contours de choix |
| nuit | `#0B1530` | `#0B1530` | l'écran de blocage, toujours sombre |
| `Theme.ground` | `#F6EFE5` | `#0E0F13` | le fond crème de toutes les listes, entre les groupes |
| `Theme.paper` | `#F7EBDB` | `#F7EBDB` | le crème de l'icône, derrière le hibou des Réglages |
| `Theme.bark`, `ochre`, `slate`, `blush` | brun, ocre, ardoise, rose | idem, plus clairs | les pastilles d'icône, prises au hibou |

- Pourquoi le bleu et plus l'orange : l'orange sur blanc ne passe pas le contraste (4,5:1) et se lisait comme une alerte. L'ambre reste, mais seulement pour « en attente ».
- Un état ne tient jamais à la couleur seule : « Bloqué » a un cadenas et son texte.

## Typography
- Titres d'écran et de section : serif système (New York), `Theme.title` et `Theme.section`. Le serif fait le « classique ».
- Les durées (« 30 min ») : `Theme.value`, serif à chiffres de largeur fixe, pour qu'elles s'alignent comme dans un registre.
- Tout le reste : SF Pro, styles système.
- Dynamic Type partout. Une taille fixe passe par `@ScaledMetric`.

## Layout
- Toutes les listes (accueil, limite, sites, Réglages) : le style des Réglages d'iPhone, `groupedScreen()` dans `Theme.swift`. Des groupes arrondis blancs sur un fond crème, une pastille d'icône (`Tile`, `TileLabel`) au début des lignes. Pourquoi : l'accueil ressemblait déjà à une page de réglages, autant qu'il ait l'air natif, aux couleurs du hibou (Tom, 2026-11-23).
- L'accueil : les limites, les sites, puis une ligne « Réglages » qui ouvre leur écran.
- Un écran = un titre et, seulement si c'est indispensable, une ligne courte. Pas d'eyebrow, pas de pied de section qui explique.
- Un seul bouton plein par écran. Sur l'accueil il est fixe en bas.
- Cibles de 44 pt au moins.

## Elevation & Depth
Aucune ombre, aucune bordure. Deux surfaces teintées : la bannière « Assouplissement en attente » et le fond crème des listes.

## Shapes
Rayon 14 pt, continu, pour le bouton plein, le champ et la bannière. Le cadran est un anneau avec un tiers rempli.

## Components
- `Dial` (`Theme.swift`) : la marque dans l'app. Elle sert à l'accueil. L'icône la reprend sur la montre du hibou.
- `PrimaryButtonStyle` (`Theme.swift`) : le bouton plein.
- `SectionTitle` (`Theme.swift`) : le titre de section en serif (title3), au-dessus d'un groupe, à la place de l'étiquette grise en capitales.
- Les pastilles de l'accueil : bleu pour une limite (cadenas rouge quand elle bloque), rose pour les sites, ardoise pour les Réglages.
- `GroupRow` (`MainView.swift`) : le nom, une ligne d'état (« Bloqué jusqu'à 04:00 », « Modification dans 24 h » ou le nombre d'éléments), la durée à droite.
- `delayedAlert` (`MainView.swift`) : l'explication du délai de 24 h au moment où il s'applique. L'onboarding le dit aussi une fois, avant le choix du temps et du verrou, parce que c'est là qu'il change la décision.
- L'écran de blocage (`ShieldConfigurationExtension.swift`) : fond nuit, le hibou au cadenas (`owl-cadenas`, copié dans l'extension), un bouton blanc « Fermer ». Ses coins sont dessinés par iOS : on ne les règle pas.
- Le rappel avant la fin : une notification à la moitié du temps (limite de 20 min et plus) et quand il reste 5 min (10 min et plus), une fois par jour chacune. Titre : le nom de la limite. Rien d'autre ne s'affiche : pas de compteur, pas de notification quand rien ne se passe. iOS déclenche les paliers lui-même, l'app ne tourne pas en fond. Deux réglages : « Me prévenir à la moitié » (oui par défaut) et « Me prévenir avant la fin » (Jamais, 5, 10, 15 ou 30 min, 5 par défaut). Les rappels sont « urgents » (Time Sensitive) : ils passent les modes Concentration. L'onboarding les demande sur un écran à lui, après le temps par jour : « Je te préviens avant la fin. », « Me prévenir » ou « Plus tard ». Si les notifications sont refusées, une ligne « Autoriser les notifications » ouvre les Réglages. Elle porte l'icône du hibou. Pas de Dynamic Island : iOS ne démarre une Live Activity que depuis l'app ouverte ou un push d'un serveur, et l'app n'a pas de serveur.
- Le paywall (`PaywallView.swift`) : après l'onboarding, sans croix. Le hibou de garde, le titre « Tes limites tiennent, pour de bon. », la frise de l'essai (Aujourd'hui, Jour 5, Jour 7) seulement sur l'annuel, deux offres (« 1 an » présélectionné avec la pastille « 7 jours offerts », « À vie »), le bouton plein, le prix facturé dessous, puis « Restaurer · J'ai un code · Conditions · Confidentialité ». Le prix facturé est toujours le plus visible (règle Apple 3.1.2). Haptique : impact léger au choix d'une offre, moyen sur le bouton, `.success` quand l'achat est confirmé. La frise se replie en 0,45 s quand on choisit « À vie ».
- L'onboarding (`OnboardingFlow.swift`) : un seul écran dont le contenu se remplace par un fondu flou, le bouton plein fixe en bas, une barre de progression fine. Le aha vient en deux écrans. D'abord le temps passé sur le téléphone par jour (4 choix), puis ce que ça fait en jours par an, un grand chiffre qui monte avec une vibration. Ensuite la maquette de l'écran de blocage, non interactive : « Quand ton temps est fini, l'app se ferme. » Pourquoi : chercher un bouton « Ignorer » ne parlait qu'à ceux qui ont déjà utilisé les limites d'Apple (Tom, 2026-11-21). Puis une question par écran : ce qui prend le plus de temps (un seul choix, une seule limite), Temps d'écran (une roue et « iOS ouvre sa fenêtre… » tant que la fenêtre d'Apple n'est pas là), les apps (une grande carte « Choisir les apps », puis leurs icônes et leurs noms, « Modifier »), le temps par jour, ou le site, puis les rappels et le verrou. Le début de journée vaut 04:00 et se règle sur l'accueil. La première installation s'applique tout de suite (rien n'existait à assouplir).
- Les Réglages (`SettingsView.swift`) : en tête, le hibou sur son crème, « Time Keeper » et la version. Puis trois groupes sans titre : la journée (remise à zéro, verrou), les rappels, puis « Statistiques anonymes » et « Ton avis ». `TileLabel` fait la pastille : 29 pt, rayon 25 %, symbole blanc. Le hibou y est permis : ce n'est pas un écran de tous les jours.
- Les réglages finissent par « Statistiques anonymes » (oui par défaut) et « Ton avis », une feuille : le sujet (Un souci, Une idée, Un mot doux, Autre chose), le message, l'e-mail facultatif, « Envoyer ». `.success` à l'envoi, `.error` si ça échoue.
- L'accueil n'a pas de titre : le nom de l'app n'apporte rien sur son propre écran (Tom, 2026-11-21).

## Motion
Animations système uniquement.

## Haptics
- Une règle change (enregistrer, ajouter un site, verrou, annuler un assouplissement) : `.success`.
- Stepper du temps, ouverture d'un écran ou du sélecteur, « Autoriser l'accès » : `.selection`.
- La confirmation de suppression s'ouvre : `.warning`.

## Illustrations
Le hibou de l'icône est la seule illustration. Dans l'app, il apparaît dans l'onboarding (bienvenue, rappels, verrou, fin) et sur l'écran de blocage, jamais sur les écrans de tous les jours : ils restent sobres. Les poses détourées sont dans `Assets.xcassets` (`owl-garde`, `owl-patient`, `owl-cadenas`, `owl-lit`) et viennent de `store/make/owl`.
- Pourquoi : l'onboarding doit faire sentir la valeur et donner de la chaleur, l'outil de tous les jours doit rester un cadran (Tom, 2026-11-21).

### L'icône
- Le sujet : un petit hibou rond, le gardien du temps, qui serre une montre à gousset contre lui. Un seul personnage, centré, sur un fond crème uni (`#F7EBDB`).
- Les couleurs : le plumage en `#1F3A8A`, le visage et le ventre crème, la montre et les pattes ocre, les joues roses.
- Le trait : dessin fait main, contour brun épais et un peu irrégulier, aplats au crayon de couleur avec le grain du papier. Pas de pictogramme plat, pas de dégradé, pas de texte, pas de chiffres sur le cadran.
- Le fichier : `ios/TimeKeeper/Assets.xcassets/AppIcon.appiconset/icon-1024.png`, PNG 1024, RGB opaque, sans coins arrondis.
- Pourquoi un personnage : le cadran blanc sur fond bleu se lisait comme un pictogramme froid, et l'app dit non sans jamais punir. Le hibou veille et garde le temps, il ne gronde pas. Il apporte la chaleur que l'interface, sobre, n'a pas.
- Pourquoi le hibou plutôt qu'un réveil ou un téléphone endormi : à 60 px il garde une silhouette nette en deux couleurs (un rond bleu, un cadran doré), le réveil perd son visage et le téléphone endormi devient une tache ocre qui évoque une app de sommeil.
- Vérifier : réduire l'icône à 60 px sur fond clair et sur fond sombre. On doit encore voir les yeux et le cadran.

## Do's and Don'ts
- Ne jamais proposer de débloquer, rallonger ou ignorer.
- L'écran de blocage a un seul bouton : « Fermer ».
- Montre l'état dans la ligne (« Bloqué jusqu'à 04:00 ») au lieu de l'expliquer sous la liste.
- Pas de carte, pas de sablier, pas d'orange en couleur d'action.
- Pas de rouge ailleurs que sur « Bloqué », une erreur de saisie, une suppression et le refus de Temps d'écran dans l'onboarding (sans cet accès, rien ne bloque).

## Vérifier ce fichier
Lancer avec `-demo` (et `-onboarding` pour le parcours d'accueil), en clair puis en sombre, regarder chaque écran en vraie taille, cacher chaque texte avec le doigt. Chercher `Color.orange`, `.red` et `hourglass` dans `ios/` : il ne doit rien rester.

## Les mots
Relus par deux relecteurs Fable (copy-cutter et story-reviewer, 2026-11-21). Les mêmes mots partout :
- « limite », jamais « règle ». « Changement prévu le … », jamais « assouplissement » ni « effectif ».
- Une date réelle, jamais « dans 24 h » sur un état qui dure : il devient faux une heure après.
- « Remise à zéro à » pour le début de journée. « Verrouiller la suppression d'apps » pour le verrou.
- « 2 apps · 1 site », jamais « éléments ».
- Une erreur dit quoi faire : « Écris-le comme ça : youtube.com ».
