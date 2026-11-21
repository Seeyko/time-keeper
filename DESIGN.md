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
| nuit | `#0B1530` | `#0B1530` | l'écran de blocage, toujours sombre |

- Pourquoi le bleu et plus l'orange : l'orange sur blanc ne passe pas le contraste (4,5:1) et se lisait comme une alerte. L'ambre reste, mais seulement pour « en attente ».
- Un état ne tient jamais à la couleur seule : « Bloqué » a un cadenas et son texte.

## Typography
- Titres d'écran et de section : serif système (New York), `Theme.title` et `Theme.section`. Le serif fait le « classique ».
- Les durées (« 30 min ») : `Theme.value`, serif à chiffres de largeur fixe, pour qu'elles s'alignent comme dans un registre.
- Tout le reste : SF Pro, styles système.
- Dynamic Type partout. Une taille fixe passe par `@ScaledMetric`.

## Layout
- `List` en style `.plain` : le texte est posé sur le fond, séparé par des filets. Une section par sujet : limites, sites, réglages.
- Un écran = un titre et, seulement si c'est indispensable, une ligne courte. Pas d'eyebrow, pas de pied de section qui explique.
- Un seul bouton plein par écran. Sur l'accueil il est fixe en bas.
- Cibles de 44 pt au moins.

## Elevation & Depth
Aucune ombre, aucune bordure. Une seule surface teintée : la bannière « Assouplissement en attente ».

## Shapes
Rayon 14 pt, continu, pour le bouton plein, le champ et la bannière. Le cadran est un anneau avec un tiers rempli.

## Components
- `Dial` (`Theme.swift`) : la marque dans l'app. La même forme sert à l'accueil et à l'écran de blocage. L'icône la reprend sur la montre du hibou.
- `PrimaryButtonStyle` (`Theme.swift`) : le bouton plein.
- `SectionTitle` (`Theme.swift`) : le titre de section en serif, à la place de l'étiquette grise en capitales.
- `GroupRow` (`MainView.swift`) : le nom, une ligne d'état (« Bloqué jusqu'à 04:00 », « Modification dans 24 h » ou le nombre d'éléments), la durée à droite.
- `delayedAlert` (`MainView.swift`) : la seule explication du délai de 24 h, montrée au moment où il s'applique.
- L'écran de blocage (`ShieldConfigurationExtension.swift`) : fond nuit, cadran blanc, un bouton blanc « Fermer ».

## Motion
Animations système uniquement.

## Haptics
- Une règle change (enregistrer, ajouter un site, verrou, annuler un assouplissement) : `.success`.
- Stepper du temps, ouverture d'un écran ou du sélecteur, « Autoriser l'accès » : `.selection`.
- La confirmation de suppression s'ouvre : `.warning`.

## Illustrations
Aucune dans l'app. La seule illustration est l'icône.

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
- Pas de rouge ailleurs que sur « Bloqué », une erreur de saisie et une suppression.

## Vérifier ce fichier
Lancer avec `-demo`, en clair puis en sombre, regarder chaque écran en vraie taille, cacher chaque texte avec le doigt. Chercher `Color.orange`, `.red` et `hourglass` dans `ios/` : il ne doit rien rester.
