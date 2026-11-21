# Secrets

Aucun secret dans ce dépôt. L'app n'a ni serveur ni clé.

| Nom | Où il vit | Sert à |
|---|---|---|
| `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8_BASE64` | secrets de l'environnement GitHub `testflight` (réservé à `main`) | signer le développement et envoyer le build sur TestFlight (clé App Manager) |
| `DIST_CERT_P12_BASE64`, `DIST_CERT_PASSWORD` | secrets de l'environnement `testflight` | certificat Apple Distribution, valable un an |
| `PROFILES_TAR_BASE64` | secret de l'environnement `testflight` | archive `.tar.gz` des 4 profils App Store nommés dans `ios/ci/ExportOptions.plist` |
| `TESTFLIGHT_ENABLED` | variable du dépôt GitHub (`true` pour activer l'envoi) | couper l'envoi tant qu'Apple n'a pas accordé Family Controls (Distribution) |
| Team ID Apple `8564ATFAJQ` | `ios/project.yml`, `ios/ci/ExportOptions.plist` | identifiant public de l'équipe, pas un secret |

Les PR venant d'un fork tournent sur les runners GitHub, sans accès à ces secrets, et seulement après validation du mainteneur.
