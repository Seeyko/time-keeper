# Contribuer

Merci ! Tout passe par une pull request depuis ton fork. Personne ne pousse sur `main`, et seul le mainteneur fusionne.

1. Lis `CLAUDE.md` : la règle produit (aucun déblocage sur le moment, tout assouplissement attend 24 h) ne se négocie pas.
2. `cd ios && xcodegen generate`, puis lance les tests dans Xcode. Une PR qui touche aux règles ajoute le test qui le prouve dans `RulesTests`.
3. Pas de commentaire dans le code, pas de code mort. Un écran touché = des captures avant / après dans la PR.
4. Les workflows d'une PR venant d'un fork ne tournent qu'après validation du mainteneur, et ne voient aucun secret.
