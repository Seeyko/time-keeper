# Analytique (PostHog)

Organisation PostHog « Time Keeper », projet « Time Keeper iOS » (id 362254), hébergé en UE : https://eu.posthog.com/project/362254

Code : `ios/TimeKeeper/Analytics.swift`. La clé `phc_…` est publique par nature. Pas de SDK : l'app envoie elle-même chaque événement, rien n'est capturé automatiquement.

## Ce qui ne part jamais
Les apps, catégories et sites choisis, les durées, l'heure de début de journée, le verrou, le temps passé. Les jetons d'Apple sont de toute façon illisibles pour l'app.

## Les règles
- IP jetée (« Discard client IP data »), pas d'enregistrement de session.
- L'identifiant est un UUID tiré au hasard. Couper « Statistiques anonymes » arrête tout envoi et efface l'identifiant.
- `-demo`, `-onboarding` et `-paywall` n'envoient rien.
- Propriété `canal` sur chaque événement : `debug`, `testflight` ou `app_store`.

## Événements

| Événement | Quand | Propriétés |
|---|---|---|
| `app_opened` | l'app passe au premier plan | |
| `onboarding_step_viewed` | chaque écran de l'onboarding | `step` (jamais la réponse) |
| `onboarding_completed` | fin de l'onboarding | personne : `onboarding_termine` |
| `paywall_viewed` | le paywall s'affiche | `trial_eligible` |
| `paywall_plan_selected` | une offre est touchée | `product_id` |
| `offer_code_opened` | « J'ai un code » | |
| `purchase_started` | le bouton du paywall | `product_id` |
| `trial_started` / `purchase_completed` | achat confirmé | `product_id`, `revenue`, `currency` ; personne : `plan` |
| `purchase_cancelled` / `purchase_pending` / `purchase_failed` / `purchase_unverified` | retour de StoreKit | `product_id`, `error` |
| `purchase_restored` | « Restaurer » | `found` |
| `access_changed` | droit gagné ou perdu (achat, code, expiration) | `access` ; personne : `acces` |
| `survey sent` | « Ton avis » envoyé, même statistiques coupées (identifiant neuf alors) | enquête « Ton avis » |
