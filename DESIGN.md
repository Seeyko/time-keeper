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
| `Theme.accent` | `#1F3A8A` | `#9DB7FF` | l'action, l'icône, le cadran (l'acier bleui des aiguilles) |
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
- `Dial` (`Theme.swift`) : la marque. La même forme sert à l'icône, à l'accueil et à l'écran de blocage.
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
Aucune. L'icône est le cadran blanc sur fond `#1F3A8A`, sans dégradé, en PNG 1024 opaque.

## Do's and Don'ts
- Ne jamais proposer de débloquer, rallonger ou ignorer.
- L'écran de blocage a un seul bouton : « Fermer ».
- Montre l'état dans la ligne (« Bloqué jusqu'à 04:00 ») au lieu de l'expliquer sous la liste.
- Pas de carte, pas de sablier, pas d'orange en couleur d'action.
- Pas de rouge ailleurs que sur « Bloqué », une erreur de saisie et une suppression.

## Vérifier ce fichier
Lancer avec `-demo`, en clair puis en sombre, regarder chaque écran en vraie taille, cacher chaque texte avec le doigt. Chercher `Color.orange`, `.red` et `hourglass` dans `ios/` : il ne doit rien rester.
