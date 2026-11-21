---
name: Time Keeper
colors:
  paper: "system background"
  ink: "label"
  accent: "#FF9F0A"
typography:
  title: "SF Pro, .largeTitle"
  body: "SF Pro, .body"
---

# Time Keeper : le système de design

## Overview
Un outil, pas un coach. Des listes iOS natives, sobres. Jamais de culpabilisation, de jeu ou de récompense : la règle est posée, elle s'applique.

## Colors
- `accent` orange (sablier) : l'action principale et l'icône.
- Rouge : seulement l'étiquette « Bloqué ».
- Orange discret : un changement en attente.

## Typography
Polices système, Dynamic Type partout.

## Layout
`List` en style groupé. Une section par sujet : limites, sites, réglages.

## Components
- `GroupRow` : nom, temps par jour, nombre d'éléments, étiquette « Bloqué ».
- `delayedAlert` : la seule explication du délai de 24 h, montrée au moment où il s'applique.

## Motion
Animations système uniquement.

## Haptics
- Stepper du temps : `.selection`.
- Annuler un assouplissement : `.impact`.

## Do's and Don'ts
- Ne jamais proposer de débloquer, rallonger ou ignorer.
- L'écran de blocage a un seul bouton : « Fermer ».

## Vérifier ce fichier
Lancer avec `-demo`, regarder chaque écran en vraie taille, cacher chaque texte avec le doigt.
